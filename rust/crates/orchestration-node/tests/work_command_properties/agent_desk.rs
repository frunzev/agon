use orchestration_api::work::RunAssignment;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::two_step_workflow_command;
use crate::support::drafting_desk::{DraftingDesk, open_desk_or_panic};
use crate::work_desk::CheckOutcome;

pub const AGENT_CASES: u32 = 3;
pub const REQUEST_PATTERN: &str = "[A-Z][a-z]{2,8}( [a-z0-9]{1,8}){1,4}";
pub const STEP_TASK_PATTERN: &str = "[A-Z][a-z]{3,10} [a-z]{3,10}";
pub const PLAN_AGENT_ID: &str = "00000000-0000-0000-0000-000000000021";
pub const AGENT_KINDS: [&str; 3] = ["claude_code", "codex", "gemini_cli"];
const CURRENT_WORKFLOW_MARK: &str = "Current workflow:\n";

pub fn check_on_desk<Cases, Check>(cases: &Cases, check: Check)
where
    Cases: Strategy,
    Check: Fn(&DraftingDesk, Cases::Value) -> CheckOutcome,
{
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(AGENT_CASES));
    let outcome = runner.run(cases, |value| check(&desk, value));
    assert!(outcome.is_ok(), "{outcome:?}");
}

pub fn create_two_step_workflow(
    desk: &DraftingDesk,
    plan_task: &str,
    build_task: &str,
) -> Result<Value, String> {
    let command = two_step_workflow_command(
        &desk.prepared.workspace_id,
        plan_task,
        build_task,
    );
    let created = desk.prepared.device.run(&command)?;
    Ok(created["workflow"].clone())
}

pub fn queue_and_claim(
    desk: &DraftingDesk,
    command: &Value,
) -> Result<(Value, RunAssignment), String> {
    let reply = desk.prepared.device.run(command)?;
    let assignment = desk.claim_drafting_run()?;
    Ok((reply, assignment))
}

pub fn change_command(
    desk: &DraftingDesk,
    workflow_id: &Value,
    request: &str,
    agent: &str,
) -> Value {
    json!({
        "command": "change_workflow",
        "workspace_id": desk.prepared.workspace_id,
        "workflow_id": workflow_id,
        "request": request,
        "agent": agent,
    })
}

pub fn fill_command(
    desk: &DraftingDesk,
    workflow_id: &Value,
    agent_id: &str,
) -> Value {
    json!({
        "command": "fill_agent_settings",
        "workspace_id": desk.prepared.workspace_id,
        "workflow_id": workflow_id,
        "agent_id": agent_id,
    })
}

pub fn draft_command_for(desk: &DraftingDesk, description: &str) -> Value {
    json!({
        "command": "draft_workflow",
        "workspace_id": desk.prepared.workspace_id,
        "description": description,
    })
}

pub fn read_embedded_workflow(
    details: &str,
    end_mark: &str,
) -> Result<Value, String> {
    let start = details
        .find(CURRENT_WORKFLOW_MARK)
        .ok_or("the prompt holds no current workflow")?;
    let after_mark = &details[start + CURRENT_WORKFLOW_MARK.len()..];
    let end = after_mark
        .find(end_mark)
        .ok_or("the current workflow has no end")?;
    serde_json::from_str(&after_mark[..end]).map_err(|error| error.to_string())
}
