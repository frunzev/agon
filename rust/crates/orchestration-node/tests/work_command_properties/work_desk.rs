use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, create_project_command, create_task_command,
    prepare_workspace,
};
use crate::support::test_device::{TestDevice, read_text};

pub const WORK_CASES: u32 = 4;
pub const TITLE_PATTERN: &str = "[A-Za-z][A-Za-z0-9 ]{0,20}";
pub const DETAILS_PATTERN: &str = "[a-z]{12,20}";
pub const START_LATER: &str = "later";
pub const START_NOW: &str = "now";
const WORK_PLACE_NAME: &str = "work";

#[derive(Debug)]
pub struct WorkPlace {
    pub workspace_id: String,
    pub project_id: String,
}

pub type CheckOutcome = Result<(), TestCaseError>;

pub fn check_on_workspace<Cases, Check>(cases: &Cases, check: Check)
where
    Cases: Strategy,
    Check: Fn(&PreparedWorkspace, Cases::Value) -> CheckOutcome,
{
    let prepared = match prepare_workspace() {
        Ok(prepared) => prepared,
        Err(message) => panic!("the workspace is prepared: {message}"),
    };
    let mut runner = TestRunner::new(Config::with_cases(WORK_CASES));
    let outcome = runner.run(cases, |value| check(&prepared, value));
    assert!(outcome.is_ok(), "{outcome:?}");
}

pub fn open_work_place(device: &TestDevice) -> Result<WorkPlace, String> {
    let created = device.run(&json!({
        "command": "create_workspace",
        "name": WORK_PLACE_NAME,
    }))?;
    let workspace_id = read_text(&created, "/id")?;
    let project = device.run(&create_project_command(&workspace_id))?;
    let project_id = read_text(&project, "/id")?;
    Ok(WorkPlace {
        workspace_id,
        project_id,
    })
}

pub fn task_command(
    place: &WorkPlace,
    title: &str,
    details: &str,
    start: &str,
) -> Value {
    let mut command =
        create_task_command(&place.workspace_id, &place.project_id, details);
    command["task"]["title"] = json!(title);
    command["start"] = json!(start);
    command
}

pub fn create_task(
    device: &TestDevice,
    place: &WorkPlace,
    details: &str,
    start: &str,
) -> Result<String, String> {
    let command = task_command(place, "Ship it", details, start);
    let created = device.run(&command)?;
    read_text(&created, "/id")
}

pub fn read_list(listed: &Value) -> Vec<Value> {
    listed.as_array().cloned().unwrap_or_default()
}

pub fn list_task_runs(
    device: &TestDevice,
    task_id: &str,
) -> Result<Vec<Value>, String> {
    let listed = device.run(&json!({
        "command": "list_runs",
        "task_id": task_id,
    }))?;
    Ok(read_list(&listed))
}

pub fn run_on_run(
    device: &TestDevice,
    command_name: &str,
    run_id: &str,
) -> Result<Value, String> {
    device.run(&json!({ "command": command_name, "run_id": run_id }))
}

pub fn start_one_run(
    device: &TestDevice,
    place: &WorkPlace,
    details: &str,
) -> Result<(String, String), String> {
    let task_id = create_task(device, place, details, START_NOW)?;
    let runs = list_task_runs(device, &task_id)?;
    let first_run = runs.first().ok_or("the started task has no run")?;
    let run_id = read_text(first_run, "/id")?;
    Ok((task_id, run_id))
}
