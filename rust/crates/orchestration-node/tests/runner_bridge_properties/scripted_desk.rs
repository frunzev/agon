use std::time::{Duration, Instant};

use orchestration_api::work::RunEvent;
use orchestration_core::run::StepStatus;
use serde_json::{Value, json};

use crate::peer_publishing::{publish_address_for, wait_for_announcement};
use crate::scripted_runner::{Opening, ScriptedRunner};
use crate::support::command_builders::prepare_workspace;
use crate::support::runner_access::{
    ClaimedRun, claim_started_task, started_task_command,
};
use crate::support::test_device::describe;
use crate::support::waiting::wait_for;
use crate::watch_desk::{UNREACHABLE_LINK, post_step_status, watch_run};

pub const LINK_LIMIT: Duration = Duration::from_secs(20);
pub const QUIET_PAUSE: Duration = Duration::from_millis(600);
const WATCHED_DETAILS: &str = "Watch the scripted runner";
const EVENTS_FIELD: &str = "events";
const POLL_PAUSE: Duration = Duration::from_millis(100);

#[derive(Debug)]
pub struct ScriptedDesk {
    pub claimed: ClaimedRun,
    pub runner: ScriptedRunner,
}

impl ScriptedDesk {
    pub fn run_id(&self) -> String {
        self.claimed.assignment.run.id.0.to_string()
    }

    pub fn watch(&self) -> Result<Value, String> {
        watch_run(&self.claimed.prepared.device, &self.run_id())
    }

    pub fn stop_watching(&self) -> Result<Value, String> {
        self.claimed.prepared.device.run(&json!({
            "command": "stop_watching_run",
            "run_id": self.run_id(),
        }))
    }

    pub fn show_run(&self) -> Result<Value, String> {
        self.claimed.prepared.device.run(&json!({
            "command": "show_run",
            "run_id": self.run_id(),
        }))
    }

    pub fn send_chat(&self, text: &str) -> Result<Value, String> {
        self.claimed.prepared.device.run(&json!({
            "command": "send_chat_message",
            "workspace_id": self.claimed.prepared.workspace_id,
            "run_id": self.run_id(),
            "text": text,
        }))
    }

    pub fn change_step(&self, status: StepStatus) -> Result<(), String> {
        post_step_status(
            &self.claimed.runner,
            &self.claimed.runtime,
            &self.claimed.assignment,
            status,
        )
    }

    pub fn collect_events(
        &self,
        expected_count: usize,
    ) -> Result<Vec<RunEvent>, String> {
        let deadline = Instant::now() + LINK_LIMIT;
        let mut collected = Vec::new();
        while collected.len() < expected_count && Instant::now() < deadline {
            collected.extend(read_events(&self.watch()?)?);
            std::thread::sleep(POLL_PAUSE);
        }
        std::thread::sleep(QUIET_PAUSE);
        collected.extend(read_events(&self.watch()?)?);
        Ok(collected)
    }

    pub fn wait_until_lost(&self) -> Result<Value, String> {
        wait_for(LINK_LIMIT, "the watch to lose its link", || {
            let shown = self.show_run()?;
            let is_lost = shown["link"] == json!(UNREACHABLE_LINK);
            Ok(is_lost.then_some(shown))
        })
    }
}

pub fn open_scripted_desk(opening: Opening) -> Result<ScriptedDesk, String> {
    let prepared = prepare_workspace()?;
    wait_for_announcement(&prepared.device)?;
    let runner = ScriptedRunner::start(opening)?;
    let identity = prepared.device.load_identity()?;
    let server_address = &prepared.server.address;
    publish_address_for(server_address, &identity, &runner.address)?;
    let task_command = started_task_command(&prepared, WATCHED_DETAILS);
    let claimed = claim_started_task(prepared, &task_command)?;
    let desk = ScriptedDesk { claimed, runner };
    desk.change_step(StepStatus::Running)?;
    Ok(desk)
}

pub fn read_events(view: &Value) -> Result<Vec<RunEvent>, String> {
    let events = view[EVENTS_FIELD].clone();
    serde_json::from_value(events).map_err(describe)
}

pub fn session_events(prefix: &str, event_count: usize) -> Vec<RunEvent> {
    let mut events = Vec::new();
    for position in 0..event_count {
        events.push(RunEvent::SessionStarted {
            session: format!("{prefix}-{position}"),
        });
    }
    events
}

pub fn is_linked_view(view: &Value) -> bool {
    view["link"] != json!(UNREACHABLE_LINK) && view["problem"].is_null()
}
