use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::thread;

use nix::sys::wait::{WaitPidFlag, waitpid};
use nix::unistd::Pid;
use orchestration_node::reaper_safe_program::{ProgramOutcome, run_program};
use proptest::test_runner::TestCaseError;

pub const SHELL_PROGRAM: &str = "/bin/sh";
const OUTCOME_FOLDER_PREFIX: &str = "agon-program-";
const SCRIPT_OPTION: &str = "-c";
const SCRIPT_NAME: &str = "probe";
const ANY_CHILD: i32 = -1;

static PROGRAM_RUNS: Mutex<()> = Mutex::new(());

pub fn hold_program_runs() -> MutexGuard<'static, ()> {
    PROGRAM_RUNS.lock().unwrap_or_else(PoisonError::into_inner)
}

pub fn fail(problem: impl std::fmt::Display) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

pub fn run_script(
    script: &str,
    script_arguments: &[String],
    working_folder: &Path,
) -> std::io::Result<ProgramOutcome> {
    let mut arguments = vec![
        SCRIPT_OPTION.to_owned(),
        script.to_owned(),
        SCRIPT_NAME.to_owned(),
    ];
    arguments.extend_from_slice(script_arguments);
    run_program(SHELL_PROGRAM, &arguments, working_folder)
}

pub fn list_outcome_folders() -> Result<Vec<PathBuf>, TestCaseError> {
    let mut folders = Vec::new();
    for entry in fs::read_dir(std::env::temp_dir()).map_err(fail)? {
        let path = entry.map_err(fail)?.path();
        let name = path.file_name().and_then(|name| name.to_str());
        if name.is_some_and(|name| name.starts_with(OUTCOME_FOLDER_PREFIX)) {
            folders.push(path);
        }
    }
    folders.sort();
    Ok(folders)
}

pub fn run_beside_a_foreign_reaper(
    script: &str,
    script_arguments: &[String],
) -> Result<ProgramOutcome, TestCaseError> {
    let is_running = Arc::new(AtomicBool::new(true));
    let reaping_flag = Arc::clone(&is_running);
    let reaper = thread::spawn(move || reap_every_child(&reaping_flag));

    let outcome = run_script(script, script_arguments, Path::new("/"));
    is_running.store(false, Ordering::Relaxed);
    reaper
        .join()
        .map_err(|_| fail("the foreign reaper panicked"))?;
    outcome.map_err(fail)
}

fn reap_every_child(is_running: &AtomicBool) {
    while is_running.load(Ordering::Relaxed) {
        let reaped =
            waitpid(Pid::from_raw(ANY_CHILD), Some(WaitPidFlag::WNOHANG));
        if reaped.is_err() {
            thread::yield_now();
        }
    }
}
