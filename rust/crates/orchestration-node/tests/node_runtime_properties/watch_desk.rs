use orchestration_api::work::{RunAssignment, RunEvent, RunEventsRequest};
use orchestration_core::run::StepStatus;
use orchestration_node::runner_bridge::NodeRunnerServer;
use orchestration_runner::runner_server::RunnerServer;
use serde_json::{Value, json};
use tokio::runtime::Runtime;

use crate::fake_runner::{FakeRunner, RunnerAnswer};
use crate::peer_publishing::{publish_address_for, wait_for_announcement};
use crate::support::command_builders::{PreparedWorkspace, prepare_workspace};
use crate::support::runner_access::{
    ClaimedRun, claim_started_task, started_task_command,
};
use crate::support::test_device::{TestDevice, describe, read_text};

pub const NO_ACTIVE_RUNNER: &str =
    "no runner is working on this run right now";
pub const UNREACHABLE_LINK: &str = "unreachable";
const WATCHED_DETAILS: &str = "Watch the fake runner";

#[derive(Debug)]
pub struct WatchDesk {
    pub claimed: ClaimedRun,
    pub fake_runner: FakeRunner,
}

#[derive(Debug)]
pub struct UnclaimedDesk {
    pub prepared: PreparedWorkspace,
    pub fake_runner: FakeRunner,
    pub run_id: String,
}

fn prepare_with_fake_runner(
    answer: RunnerAnswer,
) -> Result<(PreparedWorkspace, FakeRunner), String> {
    let prepared = prepare_workspace()?;
    wait_for_announcement(&prepared.device)?;
    let fake_runner = FakeRunner::start(answer)?;
    let identity = prepared.device.load_identity()?;
    let server_address = &prepared.server.address;
    publish_address_for(server_address, &identity, &fake_runner.address)?;
    Ok((prepared, fake_runner))
}

pub fn open_watch_desk(answer: RunnerAnswer) -> Result<WatchDesk, String> {
    let (prepared, fake_runner) = prepare_with_fake_runner(answer)?;
    let task_command = started_task_command(&prepared, WATCHED_DETAILS);
    let claimed = claim_started_task(prepared, &task_command)?;
    let desk = WatchDesk {
        claimed,
        fake_runner,
    };
    change_claimed_step(&desk, StepStatus::Running)?;
    Ok(desk)
}

pub fn open_unclaimed_desk(
    answer: RunnerAnswer,
) -> Result<UnclaimedDesk, String> {
    let (prepared, fake_runner) = prepare_with_fake_runner(answer)?;
    let task_command = started_task_command(&prepared, WATCHED_DETAILS);
    let task = prepared.device.run(&task_command)?;
    let task_id = read_text(&task, "/id")?;
    let runs = prepared
        .device
        .run(&json!({ "command": "list_runs", "task_id": task_id }))?;
    let run_id = read_text(&runs, "/0/id")?;
    Ok(UnclaimedDesk {
        prepared,
        fake_runner,
        run_id,
    })
}

pub fn watch_run(device: &TestDevice, run_id: &str) -> Result<Value, String> {
    device.run(&json!({ "command": "watch_run", "run_id": run_id }))
}

pub fn watch_claimed_run(desk: &WatchDesk) -> Result<Value, String> {
    let run_id = desk.claimed.assignment.run.id.0.to_string();
    watch_run(&desk.claimed.prepared.device, &run_id)
}

pub fn post_step_status(
    runner: &NodeRunnerServer,
    runtime: &Runtime,
    assignment: &RunAssignment,
    status: StepStatus,
) -> Result<(), String> {
    let request = RunEventsRequest {
        events: vec![RunEvent::StepStatusChanged {
            step_name: assignment.step_name.clone(),
            status,
        }],
    };
    let posting = runner.post_run_events(assignment.run.id, &request);
    runtime.block_on(posting).map_err(describe)
}

pub fn change_claimed_step(
    desk: &WatchDesk,
    status: StepStatus,
) -> Result<(), String> {
    let claimed = &desk.claimed;
    post_step_status(
        &claimed.runner,
        &claimed.runtime,
        &claimed.assignment,
        status,
    )
}

pub fn read_watch_problem(view: &Value) -> String {
    view["problem"].as_str().unwrap_or_default().to_owned()
}
