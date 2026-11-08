use orchestration_api::work::RunEvent;
use orchestration_core::run::RunFailure;
use serde_json::{Value, json};

use crate::support::drafting_desk::{
    DraftingDesk, StartedDraft, draft_command, drafted_workflow_with,
};

pub const DRAFTED_NAME_PATTERN: &str = "[a-z]{4,8}-[a-z]{4,8}";
pub const PLANNING_TASK: &str = "Plan the feature";

pub fn start_draft(desk: &DraftingDesk) -> Result<StartedDraft, String> {
    desk.start(&draft_command(&desk.prepared))
}

pub fn everywhere() -> Value {
    json!({ "kind": "all_workspaces" })
}

pub fn drafted_answer(draft: &StartedDraft, name: &str) -> String {
    drafted_workflow_with(
        &draft.workflow_id,
        name,
        &everywhere(),
        PLANNING_TASK,
    )
}

pub fn fail_draft(
    desk: &DraftingDesk,
    draft: &StartedDraft,
    reason: &str,
) -> Result<(), String> {
    let failed = RunEvent::Failed {
        failure: RunFailure {
            step_name: draft.step_name.clone(),
            runner: None,
            reason: reason.to_owned(),
            retry_runs_on_same_runner: true,
        },
    };
    desk.post(draft, vec![failed])
}

pub fn cancel_draft(
    desk: &DraftingDesk,
    draft: &StartedDraft,
) -> Result<Value, String> {
    desk.prepared.device.run(&json!({
        "command": "cancel_run",
        "run_id": draft.run_id.0.to_string(),
    }))
}
