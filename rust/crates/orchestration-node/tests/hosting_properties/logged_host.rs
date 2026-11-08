use std::io::{BufRead, BufReader, Write};
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::mpsc::{self, Receiver, RecvTimeoutError, Sender};
use std::sync::{Arc, Mutex, PoisonError};
use std::thread::{self, JoinHandle};
use std::time::Duration;

use serde_json::Value;

use crate::support::test_device::{describe, read_success};
use crate::support::waiting::wait_for;

const HOST_PROGRAM: &str = env!("CARGO_BIN_EXE_orchestration_node_host");
const STOP_LIMIT: Duration = Duration::from_secs(30);
const REPLY_LIMIT: Duration = Duration::from_secs(120);
const LOG_READER_PANICKED: &str = "the log reader panicked";
const LOG_SEPARATOR: &str = " | ";

type LoggedLines = Arc<Mutex<Vec<String>>>;

#[derive(Debug)]
pub struct LoggedHost {
    child: Child,
    commands: Option<ChildStdin>,
    replies: Receiver<String>,
    logged_lines: LoggedLines,
    log_reader: Option<JoinHandle<()>>,
}

fn collect_lines(source: impl BufRead, logged_lines: &LoggedLines) {
    for line in source.lines().map_while(Result::ok) {
        let mut kept =
            logged_lines.lock().unwrap_or_else(PoisonError::into_inner);
        kept.push(line);
    }
}

fn forward_replies(source: impl BufRead, replies: &Sender<String>) {
    for line in source.lines().map_while(Result::ok) {
        if replies.send(line).is_err() {
            return;
        }
    }
}

impl LoggedHost {
    pub fn start(configuration: &Value) -> Result<Self, String> {
        let mut host = Command::new(HOST_PROGRAM);
        host.stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        let mut child = host.spawn().map_err(describe)?;
        let commands = child.stdin.take().ok_or("the host has no input")?;
        let output = child.stdout.take().ok_or("the host has no output")?;
        let errors = child.stderr.take().ok_or("the host has no log")?;

        let logged_lines = LoggedLines::default();
        let reader_lines = Arc::clone(&logged_lines);
        let log_reader = thread::spawn(move || {
            collect_lines(BufReader::new(errors), &reader_lines);
        });
        let (reply_sender, replies) = mpsc::channel();
        thread::spawn(move || {
            forward_replies(BufReader::new(output), &reply_sender);
        });
        let mut host = Self {
            child,
            commands: Some(commands),
            replies,
            logged_lines,
            log_reader: Some(log_reader),
        };
        let started = host.send(configuration)?;
        read_success(&started)?;
        Ok(host)
    }

    pub fn run(&mut self, command: &Value) -> Result<Value, String> {
        let reply = self.send(command)?;
        read_success(&reply)
    }

    pub fn read_logged_lines(&self) -> Vec<String> {
        let kept = self
            .logged_lines
            .lock()
            .unwrap_or_else(PoisonError::into_inner);
        kept.clone()
    }

    pub fn stop(mut self) -> Result<Vec<String>, String> {
        drop(self.commands.take());
        let exit = wait_for(STOP_LIMIT, "the host to stop", || {
            self.child.try_wait().map_err(describe)
        })?;
        if !exit.success() {
            return Err(format!("the host ended with {exit}"));
        }
        if let Some(log_reader) = self.log_reader.take() {
            wait_for(STOP_LIMIT, "the host log to close", || {
                Ok(log_reader.is_finished().then_some(()))
            })?;
            log_reader
                .join()
                .map_err(|_| LOG_READER_PANICKED.to_owned())?;
        }
        Ok(self.read_logged_lines())
    }

    fn send(&mut self, message: &Value) -> Result<Value, String> {
        let commands =
            self.commands.as_mut().ok_or("the host input is closed")?;
        writeln!(commands, "{message}").map_err(describe)?;
        commands.flush().map_err(describe)?;
        let reply_line = match self.replies.recv_timeout(REPLY_LIMIT) {
            Ok(reply_line) => reply_line,
            Err(RecvTimeoutError::Timeout) => {
                return Err(self.describe_problem("the host did not answer"));
            }
            Err(RecvTimeoutError::Disconnected) => {
                return Err(self.describe_problem("the host process ended"));
            }
        };
        serde_json::from_str(&reply_line).map_err(describe)
    }

    fn describe_problem(&self, problem: &str) -> String {
        let logged_lines = self.read_logged_lines();
        format!("{problem}; its log: {}", logged_lines.join(LOG_SEPARATOR))
    }
}

impl Drop for LoggedHost {
    fn drop(&mut self) {
        let is_running = matches!(self.child.try_wait(), Ok(None));
        if is_running {
            let _kill_outcome = self.child.kill();
            let _exit = self.child.wait();
        }
    }
}

pub fn count_lines_starting(lines: &[String], line_start: &str) -> usize {
    let mut count = 0;
    for line in lines {
        if line.starts_with(line_start) {
            count += 1;
        }
    }
    count
}
