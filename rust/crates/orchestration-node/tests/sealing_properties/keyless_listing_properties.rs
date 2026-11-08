use proptest::prelude::*;
use serde_json::{Value, json};

use crate::handler_desk::{create_workspace, read_problem};
use crate::support::command_builders::{
    PreparedWorkspace, two_step_workflow_command,
};
use crate::support::pairing_steps::pair_into_workspace;
use crate::support::test_device::{TestDevice, fail, is_defined_reply};
use crate::work_desk::check_on_workspace;
use crate::workflow_desk::{
    create_workflow, list_workflow_views, run_on_workflow,
};
use crate::workflow_view_properties::step_task_strategy;

const UNREADABLE_PROBLEM: &str =
    "the sealed text cannot be opened with any workspace key";

#[derive(Debug)]
struct KeylessDevice {
    device: TestDevice,
    readable_id: Value,
    hidden_id: Value,
}

fn join_without_the_other_key(
    prepared: &PreparedWorkspace,
    readable_task: &str,
    hidden_task: &str,
) -> Result<KeylessDevice, String> {
    let other_workspace = create_workspace(&prepared.device, "other")?;
    let device = TestDevice::start()?;
    pair_into_workspace(prepared, &device)?;
    let readable = create_workflow(prepared, readable_task, "build")?;
    let hidden_command =
        two_step_workflow_command(&other_workspace, hidden_task, "build");
    let hidden = prepared.device.run(&hidden_command)?;
    Ok(KeylessDevice {
        device,
        readable_id: readable["workflow"]["id"].clone(),
        hidden_id: hidden["workflow"]["id"].clone(),
    })
}

fn list_workflow_ids(
    device: &TestDevice,
    workspace_id: &str,
) -> Result<Vec<Value>, String> {
    let views = list_workflow_views(device, workspace_id)?;
    let mut workflow_ids = Vec::new();
    for view in views {
        workflow_ids.push(view["workflow"]["id"].clone());
    }
    Ok(workflow_ids)
}

#[test]
fn test_handle_workflow_command_property_lists_around_unreadable_workflows() {
    let cases = (step_task_strategy(), step_task_strategy());
    check_on_workspace(&cases, |prepared, (readable_task, hidden_task)| {
        let keyless =
            join_without_the_other_key(prepared, &readable_task, &hidden_task)
                .map_err(fail)?;

        let joined_ids =
            list_workflow_ids(&keyless.device, &prepared.workspace_id)
                .map_err(fail)?;

        prop_assert!(joined_ids.contains(&keyless.readable_id));
        prop_assert!(!joined_ids.contains(&keyless.hidden_id));
        Ok(())
    });
}

#[test]
fn test_log_left_out_workflow_property_the_listing_keeps_its_shape() {
    let cases = (step_task_strategy(), step_task_strategy());
    check_on_workspace(&cases, |prepared, (readable_task, hidden_task)| {
        let keyless =
            join_without_the_other_key(prepared, &readable_task, &hidden_task)
                .map_err(fail)?;

        let reply = keyless.device.send(&json!({
            "command": "list_workflows",
            "workspace_id": prepared.workspace_id,
        }));

        prop_assert!(is_defined_reply(&reply), "{}", reply);
        let listed = reply["ok"].as_array().cloned().unwrap_or_default();
        let readable_view = listed
            .iter()
            .find(|view| view["workflow"]["id"] == keyless.readable_id);
        let readable_step_task =
            readable_view.map(|view| &view["workflow"]["agents"][0]["task"]);
        prop_assert_eq!(readable_step_task, Some(&json!(readable_task)));
        Ok(())
    });
}

#[test]
fn test_log_left_out_workflow_property_the_owner_still_lists_it() {
    let cases = (step_task_strategy(), step_task_strategy());
    check_on_workspace(&cases, |prepared, (readable_task, hidden_task)| {
        let keyless =
            join_without_the_other_key(prepared, &readable_task, &hidden_task)
                .map_err(fail)?;
        list_workflow_ids(&keyless.device, &prepared.workspace_id)
            .map_err(fail)?;

        let owner_ids =
            list_workflow_ids(&prepared.device, &prepared.workspace_id)
                .map_err(fail)?;

        prop_assert!(owner_ids.contains(&keyless.readable_id));
        prop_assert!(owner_ids.contains(&keyless.hidden_id));
        Ok(())
    });
}

#[test]
fn test_log_left_out_workflow_property_direct_use_is_still_refused() {
    let cases = (step_task_strategy(), step_task_strategy());
    check_on_workspace(&cases, |prepared, (readable_task, hidden_task)| {
        let keyless =
            join_without_the_other_key(prepared, &readable_task, &hidden_task)
                .map_err(fail)?;

        let problem = read_problem(run_on_workflow(
            &keyless.device,
            "sign_workflow",
            &keyless.hidden_id,
        ));

        prop_assert_eq!(problem, UNREADABLE_PROBLEM);
        Ok(())
    });
}
