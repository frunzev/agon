use std::future::Future;
use std::sync::{LazyLock, Mutex, MutexGuard, PoisonError};

use orchestration_api::work::{RunAssignment, RunEvent, RunEventsRequest};
use orchestration_core::identifiers::{RunId, SkillId};
use orchestration_core::run::{ChatAuthor, ChatMessage};
use orchestration_node::runner_bridge::NodeRunnerServer;
use orchestration_runner::runner_server::{RunnerServer, ServerError};
use serde_json::{Value, json};
use tokio::runtime::Runtime;
use uuid::Uuid;

use crate::support::command_builders::{
    PreparedWorkspace, create_skill_command, prepare_workspace,
};
use crate::support::runner_access::{
    claim_next_assignment, started_task_command, test_runtime,
};
use crate::support::test_device::{TestDevice, describe, read_text};

pub const SERVER_CASES: u32 = 2;
pub const DETAILS_PATTERN: &str = "[A-Za-z0-9]{1,10}( [A-Za-z0-9]{1,10}){0,3}";
pub const NO_ACCOUNT: &str = "this device has no account yet";
const SKILL_NAME_PREFIX: &str = "release-notes-";

#[derive(Debug)]
pub struct ServerDesk {
    pub prepared: PreparedWorkspace,
    pub runtime: Runtime,
    claim_turn: Mutex<()>,
}

static SERVER_DESK: LazyLock<Result<ServerDesk, String>> =
    LazyLock::new(open_server_desk);

fn open_server_desk() -> Result<ServerDesk, String> {
    Ok(ServerDesk {
        prepared: prepare_workspace()?,
        runtime: test_runtime()?,
        claim_turn: Mutex::new(()),
    })
}

pub fn server_desk() -> Result<&'static ServerDesk, String> {
    SERVER_DESK.as_ref().map_err(Clone::clone)
}

pub fn unknown_run(number: u128) -> RunId {
    RunId(Uuid::from_u128(number))
}

pub fn missing_claim_reason(run_id: RunId) -> String {
    format!("claimed run {} was not found", run_id.0)
}

pub fn chat_event(author: ChatAuthor, text: &str) -> RunEvent {
    RunEvent::ChatAppended {
        message: ChatMessage {
            at: chrono::Utc::now(),
            author,
            text: text.to_owned(),
            is_error: false,
            waiting_to_send: false,
        },
    }
}

pub type AccountlessRunner = (TestDevice, NodeRunnerServer);

pub fn open_accountless_runner() -> Result<AccountlessRunner, String> {
    let device = TestDevice::start()?;
    let runner = device.open_runner_server()?;
    Ok((device, runner))
}

impl ServerDesk {
    pub fn device(&self) -> &TestDevice {
        &self.prepared.device
    }

    pub fn open_runner(&self) -> Result<NodeRunnerServer, String> {
        self.prepared.device.open_runner_server()
    }

    pub fn wait<Answer>(&self, work: impl Future<Output = Answer>) -> Answer {
        self.runtime.block_on(work)
    }

    pub fn take_claim_turn(&self) -> MutexGuard<'_, ()> {
        self.claim_turn
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
    }

    pub fn start_task(&self, details: &str) -> Result<String, String> {
        let command = started_task_command(&self.prepared, details);
        let task = self.prepared.device.run(&command)?;
        read_text(&task, "/id")
    }

    pub fn claim_fresh_run(
        &self,
        runner: &NodeRunnerServer,
        details: &str,
    ) -> Result<RunAssignment, String> {
        let _turn = self.take_claim_turn();
        self.start_task(details)?;
        claim_next_assignment(runner, &self.runtime)
    }

    pub fn post(
        &self,
        runner: &NodeRunnerServer,
        run_id: RunId,
        events: Vec<RunEvent>,
    ) -> Result<(), ServerError> {
        let request = RunEventsRequest { events };
        self.wait(runner.post_run_events(run_id, &request))
    }

    pub fn show_run(&self, run_id: RunId) -> Result<Value, String> {
        let shown = self.prepared.device.run(&json!({
            "command": "show_run",
            "run_id": run_id.0.to_string(),
        }))?;
        Ok(shown["run"].clone())
    }

    pub fn send_chat(&self, run_id: RunId, text: &str) -> Result<(), String> {
        self.prepared.device.run(&json!({
            "command": "send_chat_message",
            "workspace_id": self.prepared.workspace_id,
            "run_id": run_id.0.to_string(),
            "text": text,
        }))?;
        Ok(())
    }

    pub fn create_skill(
        &self,
        name_tail: &str,
        improvement: &str,
    ) -> Result<SkillId, String> {
        let workspace_id = &self.prepared.workspace_id;
        let mut command = create_skill_command(workspace_id, "first words");
        command["name"] = json!(format!("{SKILL_NAME_PREFIX}{name_tail}"));
        command["improvement"] = json!(improvement);
        let skill = self.prepared.device.run(&command)?;
        let skill_text = read_text(&skill, "/id")?;
        let skill_uuid = Uuid::parse_str(&skill_text).map_err(describe)?;
        Ok(SkillId(skill_uuid))
    }

    pub fn find_skill(&self, skill_id: SkillId) -> Result<Value, String> {
        let skills = self.prepared.device.run(&json!({
            "command": "list_skills",
            "workspace_id": self.prepared.workspace_id,
        }))?;
        let listed = skills.as_array().cloned().unwrap_or_default();
        let skill_text = skill_id.0.to_string();
        let found = listed
            .into_iter()
            .find(|skill| skill["id"] == json!(skill_text));
        found.ok_or_else(|| format!("skill {skill_text} is not listed"))
    }
}

pub fn read_chat_texts(run: &Value) -> Vec<String> {
    let messages = run["chat"].as_array().cloned().unwrap_or_default();
    let mut texts = Vec::new();
    for message in messages {
        if let Some(text) = message["text"].as_str() {
            texts.push(text.to_owned());
        }
    }
    texts
}
