use std::sync::Arc;

use orchestration_api::work::HeartbeatRequest;
use orchestration_node::runner_bridge::NodeRunnerServer;
use orchestration_runner::runner_server::RunnerServer;
use proptest::test_runner::TestCaseError;
use serde_json::{Value, json};
use tokio::runtime::Runtime;

use crate::support::command_builders::{
    create_skill_command, create_workflow_command,
};
use crate::support::runner_access::{
    claim_next_assignment, sample_heartbeat, test_runtime,
};
use crate::support::test_device::{TestDevice, describe, fail, read_text};
use crate::support::test_server::TestServer;

pub const DRAFTING_CASES: u32 = 3;
pub const DRAFT_DESCRIPTION: &str = "Plan, then build";
pub const SECTION_HEADINGS: [&str; 4] =
    ["Projects:", "Workflows:", "Skills:", "Runners:"];
pub const EMPTY_SECTION_LINE: &str = "- none";
pub const DRAFTING_DEVICE_NAME: &str = "air-laptop";
pub const FIRST_WORKSPACE_NAME: &str = "acme";

#[derive(Debug)]
pub struct DraftingTable {
    pub server: TestServer,
    pub device: TestDevice,
    pub workspace_id: String,
    runtime: Runtime,
    runner: Arc<NodeRunnerServer>,
}

pub fn open_drafting_table(
    device_name: &str,
) -> Result<DraftingTable, String> {
    let server = TestServer::start()?;
    let device = TestDevice::start()?;
    let account = device.run(&json!({
        "command": "create_account",
        "server_address": server.address,
        "setup_code": server.read_setup_code()?,
        "device_name": device_name,
        "role": "client_and_runner",
        "workspace_name": FIRST_WORKSPACE_NAME,
    }))?;
    let workspace_id = read_text(&account, "/workspaces/0/id")?;
    let runtime = test_runtime()?;
    let runner = Arc::new(device.open_runner_server()?);
    Ok(DraftingTable {
        server,
        device,
        workspace_id,
        runtime,
        runner,
    })
}

pub fn open_table_or_fail() -> Result<DraftingTable, TestCaseError> {
    open_drafting_table(DRAFTING_DEVICE_NAME).map_err(fail)
}

pub fn read_section<'prompt>(
    prompt: &'prompt str,
    heading: &str,
) -> Vec<&'prompt str> {
    let mut section_lines = Vec::new();
    let mut is_inside = false;
    for line in prompt.lines() {
        if is_inside && !line.starts_with("- ") {
            break;
        }
        if is_inside {
            section_lines.push(line);
        }
        if line == heading {
            is_inside = true;
        }
    }
    section_lines
}

pub fn names_identifier(lines: &[&str], identifier: &str) -> bool {
    let marker = format!("(id {identifier})");
    lines.iter().any(|line| line.contains(&marker))
}

pub fn draft_command(workspace_id: &str) -> Value {
    json!({
        "command": "draft_workflow",
        "workspace_id": workspace_id,
        "description": DRAFT_DESCRIPTION,
    })
}

pub fn only_workspace_scope(workspace_id: &str) -> Value {
    json!({ "kind": "only_workspaces", "workspaces": [workspace_id] })
}

impl DraftingTable {
    pub fn run(&self, command: &Value) -> Result<Value, String> {
        self.device.run(command)
    }

    pub fn read_drafting_prompt(
        &self,
        workspace_id: &str,
    ) -> Result<String, String> {
        self.run(&draft_command(workspace_id))?;
        let assignment = claim_next_assignment(&self.runner, &self.runtime)?;
        Ok(assignment.task.details)
    }

    pub fn read_first_prompt(&self) -> Result<String, String> {
        self.read_drafting_prompt(&self.workspace_id)
    }

    pub fn send_heartbeat(&self, labels: &[String]) -> Result<(), String> {
        let heartbeat = HeartbeatRequest {
            labels: labels.to_vec(),
            ..sample_heartbeat()
        };
        let sending = self.runner.send_heartbeat(&heartbeat);
        self.runtime.block_on(sending).map_err(describe)?;
        Ok(())
    }

    pub fn create_workflow(
        &self,
        workspace_id: &str,
        availability: &Value,
    ) -> Result<String, String> {
        let mut command = create_workflow_command(workspace_id, "plan it");
        command["availability"] = availability.clone();
        let created = self.run(&command)?;
        read_text(&created, "/workflow/id")
    }

    pub fn create_skill(
        &self,
        workspace_id: &str,
        workspaces_scope: &Value,
        summary: &str,
    ) -> Result<String, String> {
        let mut command = create_skill_command(workspace_id, "Write notes");
        command["scope"]["workspaces"] = workspaces_scope.clone();
        command["summary"] = json!(summary);
        let created = self.run(&command)?;
        read_text(&created, "/id")
    }
}
