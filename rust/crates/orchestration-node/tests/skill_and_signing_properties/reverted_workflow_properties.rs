use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, create_task_command,
};
use crate::support::test_device::fail;
use crate::work_desk::check_on_workspace;
use crate::workflow_desk::{create_workflow, run_on_workflow, save_workflow};

const STEP_TASK_PATTERN: &str = "[A-Za-z][a-z ]{2,16}";
const BUILD_TASK: &str = "Build it";
const SIGNED_STATE: &str = "signed";
const CHANGED_STATE: &str = "changed_not_signed";

#[derive(Debug)]
struct RevertedWorkflow {
    changed: Value,
    reverted: Value,
}

fn sign_change_and_revert(
    prepared: &PreparedWorkspace,
    plan_task: &str,
    changed_task: &str,
) -> Result<RevertedWorkflow, String> {
    let created = create_workflow(prepared, plan_task, BUILD_TASK)?;
    let workflow_id = created["workflow"]["id"].clone();
    let signed =
        run_on_workflow(&prepared.device, "sign_workflow", &workflow_id)?;
    let mut workflow = signed["workflow"].clone();
    workflow["agents"][0]["task"] = json!(changed_task);
    let changed = save_workflow(prepared, &prepared.workspace_id, &workflow)?;
    workflow["agents"][0]["task"] = json!(plan_task);
    let reverted = save_workflow(prepared, &prepared.workspace_id, &workflow)?;
    Ok(RevertedWorkflow { changed, reverted })
}

fn start_workflow_task(
    prepared: &PreparedWorkspace,
    workflow_id: &Value,
) -> Result<Value, String> {
    let mut command = create_task_command(
        &prepared.workspace_id,
        &prepared.project_id,
        BUILD_TASK,
    );
    command["start"] = json!("now");
    command["task"]["doer"] = json!({
        "kind": "workflow",
        "workflow_id": workflow_id,
    });
    prepared.device.run(&command)
}

fn step_task_pair() -> impl Strategy<Value = (String, String)> {
    (STEP_TASK_PATTERN, STEP_TASK_PATTERN)
        .prop_filter("the change differs", |(plan, changed)| plan != changed)
}

#[test]
fn test_build_workflow_view_property_a_reverted_step_reads_as_signed() {
    check_on_workspace(&step_task_pair(), |prepared, (plan, changed)| {
        let reverted =
            sign_change_and_revert(prepared, &plan, &changed).map_err(fail)?;

        prop_assert_eq!(&reverted.changed["signature_state"], CHANGED_STATE);
        prop_assert_eq!(&reverted.reverted["signature_state"], SIGNED_STATE);
        Ok(())
    });
}

#[test]
fn test_build_workflow_view_property_a_reverted_step_lists_no_changes() {
    check_on_workspace(&step_task_pair(), |prepared, (plan, changed)| {
        let reverted =
            sign_change_and_revert(prepared, &plan, &changed).map_err(fail)?;

        let changes = reverted.reverted["changes"].as_array().cloned();
        prop_assert_eq!(changes, Some(Vec::new()));
        let first_changes = reverted.changed["changes"].as_array().cloned();
        prop_assert!(!first_changes.unwrap_or_default().is_empty());
        Ok(())
    });
}

#[test]
fn test_prepare_workflow_resave_property_the_server_starts_a_revert() {
    check_on_workspace(&step_task_pair(), |prepared, (plan, changed)| {
        let reverted =
            sign_change_and_revert(prepared, &plan, &changed).map_err(fail)?;
        let workflow_id = reverted.reverted["workflow"]["id"].clone();

        let started = start_workflow_task(prepared, &workflow_id);

        prop_assert!(started.is_ok(), "{:?}", started);
        Ok(())
    });
}
