use std::time::Duration;

use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, create_task_command,
};
use crate::support::test_device::read_text;
use crate::support::waiting::wait_for;

pub const ASK_STEP_NAME: &str = "ask";
const ASK_ID: &str = "00000000-0000-0000-0000-000000000041";
const SHIP_ID: &str = "00000000-0000-0000-0000-000000000042";
const REDO_ID: &str = "00000000-0000-0000-0000-000000000043";
const QUESTION_LIMIT: Duration = Duration::from_secs(30);

fn step(agent_id: &str, name: &str, step_kind: &str, task: &str) -> Value {
    json!({
        "id": agent_id,
        "name": name,
        "step_kind": step_kind,
        "kind": "claude_code",
        "task": task,
        "runs_on": { "kind": "any_free_runner" },
        "skills": [],
        "uses_automatic_skills": false,
        "approval_policy": "never_ask",
        "position": { "horizontal": 0.0, "vertical": 0.0 },
    })
}

fn build_connections(choices: &[String]) -> Vec<Value> {
    let mut connections = Vec::new();
    let targets = [SHIP_ID, REDO_ID];
    for (choice, target) in choices.iter().zip(targets) {
        connections.push(json!({
            "from": ASK_ID,
            "to": target,
            "condition": choice,
        }));
    }
    if choices.is_empty() {
        connections.push(json!({ "from": ASK_ID, "to": SHIP_ID }));
    }
    connections
}

pub fn start_question_run(
    prepared: &PreparedWorkspace,
    question: &str,
    choices: &[String],
) -> Result<String, String> {
    let created = prepared.device.run(&json!({
        "command": "create_workflow",
        "workspace_id": prepared.workspace_id,
        "name": "ask-first",
        "availability": { "kind": "all_workspaces" },
        "agents": [
            step(ASK_ID, ASK_STEP_NAME, "person", question),
            step(SHIP_ID, "ship", "agent", "Ship the change"),
            step(REDO_ID, "redo", "agent", "Redo the change"),
        ],
        "connections": build_connections(choices),
    }))?;
    let workflow_id = read_text(&created, "/workflow/id")?;
    prepared.device.run(&json!({
        "command": "sign_workflow",
        "workflow_id": workflow_id,
    }))?;
    let mut task = create_task_command(
        &prepared.workspace_id,
        &prepared.project_id,
        "Ask before shipping",
    );
    task["task"]["doer"] =
        json!({ "kind": "workflow", "workflow_id": workflow_id });
    let created_task = prepared.device.run(&task)?;
    let run = prepared.device.run(&json!({
        "command": "start_task",
        "task_id": read_text(&created_task, "/id")?,
    }))?;
    read_text(&run, "/id")
}

pub fn list_open_steps(
    prepared: &PreparedWorkspace,
) -> Result<Vec<Value>, String> {
    let listed = prepared
        .device
        .run(&json!({ "command": "list_person_steps" }))?;
    Ok(listed.as_array().cloned().unwrap_or_default())
}

pub fn find_open_step(steps: &[Value], run_id: &str) -> Option<Value> {
    steps
        .iter()
        .find(|step| step["run_id"] == json!(run_id))
        .cloned()
}

pub fn wait_for_open_step(
    prepared: &PreparedWorkspace,
    run_id: &str,
) -> Result<Value, String> {
    wait_for(QUESTION_LIMIT, "the person step to open", || {
        let steps = list_open_steps(prepared)?;
        Ok(find_open_step(&steps, run_id))
    })
}

pub fn answer_step(
    prepared: &PreparedWorkspace,
    run_id: &str,
    step_name: &str,
    answer: &str,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "answer_person_step",
        "run_id": run_id,
        "step_name": step_name,
        "answer": answer,
    }))
}
