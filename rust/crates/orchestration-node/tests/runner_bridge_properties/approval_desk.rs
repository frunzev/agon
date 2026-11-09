use std::sync::Arc;
use std::time::Duration;

use orchestration_api::work::{CreateApprovalRequest, RunAssignment};
use orchestration_core::approval::{ApprovalAction, ApprovalDecision};
use orchestration_node::runner_bridge::NodeRunnerServer;
use orchestration_runner::runner_server::{RunnerServer, ServerError};
use serde_json::{Value, json};
use tokio::runtime::Runtime;
use tokio::task::JoinHandle;

use crate::approval_forging_server::ApprovalForgingServer;
use crate::support::command_builders::{
    create_project_command, create_task_command,
};
use crate::support::runner_access::{claim_next_assignment, test_runtime};
use crate::support::test_device::{TestDevice, read_text};
use crate::support::waiting::wait_for;

pub const APPROVAL_LIMIT: Duration = Duration::from_secs(20);
const WATCHED_DETAILS: &str = "Wait for a decision";
const REPOSITORY: &str = "github.com/acme/app";

pub type DecisionWait = JoinHandle<Result<ApprovalDecision, ServerError>>;

#[derive(Debug)]
pub struct ApprovalDesk {
    pub server: ApprovalForgingServer,
    pub device: TestDevice,
    pub runner: Arc<NodeRunnerServer>,
    pub runtime: Runtime,
    pub assignment: RunAssignment,
}

impl ApprovalDesk {
    pub fn push_request(&self, branch: &str) -> CreateApprovalRequest {
        CreateApprovalRequest {
            run_id: Some(self.assignment.run.id),
            action: ApprovalAction::PushCommits {
                repository: REPOSITORY.to_owned(),
                branch: branch.to_owned(),
                commits: vec![format!("Ship {branch}")],
            },
        }
    }

    pub fn start_waiting(
        &self,
        request: CreateApprovalRequest,
    ) -> DecisionWait {
        let runner = Arc::clone(&self.runner);
        self.runtime.spawn(async move {
            runner.request_approval_decision(&request).await
        })
    }

    pub fn finish_waiting(
        &self,
        waiting: DecisionWait,
    ) -> Result<Result<ApprovalDecision, ServerError>, String> {
        let bounded =
            async move { tokio::time::timeout(APPROVAL_LIMIT, waiting).await };
        let finished = self.runtime.block_on(bounded);
        let joined =
            finished.map_err(|_| "the wait never ended".to_owned())?;
        joined.map_err(|problem| problem.to_string())
    }

    pub fn wait_for_branch_approval(
        &self,
        branch: &str,
    ) -> Result<String, String> {
        wait_for(APPROVAL_LIMIT, "the approval", || {
            let listed =
                self.device.run(&json!({ "command": "list_approvals" }))?;
            let approvals = listed["approvals"].as_array().cloned();
            let found =
                approvals.unwrap_or_default().into_iter().find(|entry| {
                    entry["approval"]["action"]["branch"] == json!(branch)
                });
            let Some(entry) = found else {
                return Ok(None);
            };
            Ok(Some(read_text(&entry, "/approval/id")?))
        })
    }

    pub fn decide(
        &self,
        approval_id: &str,
        decision: &str,
    ) -> Result<Value, String> {
        self.device.run(&json!({
            "command": "decide_approval",
            "approval_id": approval_id,
            "decision": decision,
        }))
    }
}

pub fn open_approval_desk() -> Result<ApprovalDesk, String> {
    let server = ApprovalForgingServer::start()?;
    let device = TestDevice::start()?;
    let account = device.run(&json!({
        "command": "create_account",
        "server_address": server.address,
        "setup_code": server.read_setup_code()?,
        "device_name": "air-laptop",
        "role": "client_and_runner",
        "workspace_name": "acme",
    }))?;
    let workspace_id = read_text(&account, "/workspaces/0/id")?;
    let project = device.run(&create_project_command(&workspace_id))?;
    let project_id = read_text(&project, "/id")?;
    let mut task_command =
        create_task_command(&workspace_id, &project_id, WATCHED_DETAILS);
    task_command["start"] = json!("now");
    device.run(&task_command)?;
    let runtime = test_runtime()?;
    let runner = Arc::new(device.open_runner_server()?);
    let assignment = claim_next_assignment(&runner, &runtime)?;
    Ok(ApprovalDesk {
        server,
        device,
        runner,
        runtime,
        assignment,
    })
}
