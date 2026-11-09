use orchestration_core::run::StepStatus;
use serde_json::{Value, json};

use crate::fake_runner::{FakeRunner, RunnerAnswer};
use crate::forging_server::{Forgery, ForgingServer};
use crate::peer_publishing::{publish_address_for, wait_for_announcement};
use crate::support::command_builders::{
    create_project_command, create_task_command,
};
use crate::support::pairing_steps::join_at_address;
use crate::support::runner_access::{claim_next_assignment, test_runtime};
use crate::support::test_device::{TestDevice, read_text};
use crate::watch_desk::post_step_status;

pub const UNTRUSTED_ADDRESS_END: &str =
    "has published no trusted peer address";
const RUNNING_TASK_DETAILS: &str = "Run on the fake runner";
pub const TAMPERINGS: [Forgery; 5] = [
    Forgery::RemovedAddress,
    Forgery::ForeignDeviceId,
    Forgery::ChangedSignature,
    Forgery::MovedEndpoint,
    Forgery::LaterPublishing,
];

#[derive(Debug)]
pub struct ForgedWorkspace {
    pub server: ForgingServer,
    pub device: TestDevice,
    pub device_id: String,
    pub workspace_id: String,
    pub project_id: String,
}

#[derive(Debug)]
pub struct HolderDesk {
    pub workspace: ForgedWorkspace,
    pub holder_id: String,
    pub fake_runner: FakeRunner,
}

pub fn prepare_forged_workspace() -> Result<ForgedWorkspace, String> {
    let server = ForgingServer::start()?;
    let device = TestDevice::start()?;
    let account = device.run(&server.build_create_account_command()?)?;
    let workspace_id = read_text(&account, "/workspaces/0/id")?;
    let device_id = read_text(&account, "/device/id")?;
    let project = device.run(&create_project_command(&workspace_id))?;
    let project_id = read_text(&project, "/id")?;
    Ok(ForgedWorkspace {
        server,
        device,
        device_id,
        workspace_id,
        project_id,
    })
}

fn pair_holder(
    workspace: &ForgedWorkspace,
    holder: &TestDevice,
) -> Result<String, String> {
    let session = workspace
        .device
        .run(&json!({ "command": "start_pairing" }))?;
    let display_code = read_text(&session, "/display_code")?;
    join_at_address(holder, &workspace.server.address, &display_code)?;
    workspace.device.run(&json!({
        "command": "approve_pairing",
        "code": session["code"],
        "workspace_ids": [workspace.workspace_id],
    }))?;
    let joined = holder.run(&json!({ "command": "join_status" }))?;
    read_text(&joined, "/device/id")
}

pub fn open_holder_desk(answer: RunnerAnswer) -> Result<HolderDesk, String> {
    let workspace = prepare_forged_workspace()?;
    let holder = TestDevice::start()?;
    let holder_id = pair_holder(&workspace, &holder)?;
    let holder_identity = holder.load_identity()?;
    drop(holder);
    let fake_runner = FakeRunner::start(answer)?;
    let server_address = &workspace.server.address;
    publish_address_for(
        server_address,
        &holder_identity,
        &fake_runner.address,
    )?;
    Ok(HolderDesk {
        workspace,
        holder_id,
        fake_runner,
    })
}

pub fn publish_own_fake_runner(
    workspace: &ForgedWorkspace,
    answer: RunnerAnswer,
) -> Result<FakeRunner, String> {
    wait_for_announcement(&workspace.device)?;
    let fake_runner = FakeRunner::start(answer)?;
    let identity = workspace.device.load_identity()?;
    let server_address = &workspace.server.address;
    publish_address_for(server_address, &identity, &fake_runner.address)?;
    Ok(fake_runner)
}

pub fn list_device_views(device: &TestDevice) -> Result<Vec<Value>, String> {
    let listed = device.run(&json!({ "command": "list_devices" }))?;
    Ok(listed.as_array().cloned().unwrap_or_default())
}

pub fn read_verified_flag(views: &[Value], device_id: &str) -> Option<Value> {
    let wanted = json!(device_id);
    let view = views.iter().find(|view| view["device"]["id"] == wanted)?;
    Some(view["peer_address_verified"].clone())
}

pub fn start_running_run(
    workspace: &ForgedWorkspace,
) -> Result<String, String> {
    let mut task_command = create_task_command(
        &workspace.workspace_id,
        &workspace.project_id,
        RUNNING_TASK_DETAILS,
    );
    task_command["start"] = json!("now");
    workspace.device.run(&task_command)?;
    let runtime = test_runtime()?;
    let runner = workspace.device.open_runner_server()?;
    let assignment = claim_next_assignment(&runner, &runtime)?;
    post_step_status(&runner, &runtime, &assignment, StepStatus::Running)?;
    Ok(assignment.run.id.0.to_string())
}
