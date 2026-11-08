use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, two_step_workflow_command,
};
use crate::support::test_device::TestDevice;

pub const PLAN_AGENT_ID: &str = "00000000-0000-0000-0000-000000000021";
pub const BUILD_AGENT_ID: &str = "00000000-0000-0000-0000-000000000022";
pub const WORKFLOWS_PATH: &str = "/workflows";
pub const PUT_METHOD: &str = "PUT";

pub fn create_workflow_in(
    device: &TestDevice,
    workspace_id: &str,
    plan_task: &str,
    build_task: &str,
) -> Result<Value, String> {
    let command =
        two_step_workflow_command(workspace_id, plan_task, build_task);
    device.run(&command)
}

pub fn create_workflow(
    prepared: &PreparedWorkspace,
    plan_task: &str,
    build_task: &str,
) -> Result<Value, String> {
    create_workflow_in(
        &prepared.device,
        &prepared.workspace_id,
        plan_task,
        build_task,
    )
}

pub fn list_workflow_views(
    device: &TestDevice,
    workspace_id: &str,
) -> Result<Vec<Value>, String> {
    let listed = device.run(&json!({
        "command": "list_workflows",
        "workspace_id": workspace_id,
    }))?;
    Ok(listed.as_array().cloned().unwrap_or_default())
}

pub fn find_workflow_view(
    prepared: &PreparedWorkspace,
    workflow_id: &Value,
) -> Result<Option<Value>, String> {
    let views = list_workflow_views(&prepared.device, &prepared.workspace_id)?;
    let found = views
        .into_iter()
        .find(|view| &view["workflow"]["id"] == workflow_id);
    Ok(found)
}

pub fn run_on_workflow(
    device: &TestDevice,
    command_name: &str,
    workflow_id: &Value,
) -> Result<Value, String> {
    device.run(&json!({
        "command": command_name,
        "workflow_id": workflow_id,
    }))
}

pub fn save_workflow(
    prepared: &PreparedWorkspace,
    workspace_id: &str,
    workflow: &Value,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "save_workflow",
        "workspace_id": workspace_id,
        "workflow": workflow,
    }))
}
