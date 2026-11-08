use proptest::prelude::*;
use serde_json::{Value, json};

use crate::handler_desk::{read_problem, uuid_text_strategy};
use crate::support::command_builders::PreparedWorkspace;
use crate::support::pairing_steps::pair_into_workspace;
use crate::support::test_device::{TestDevice, fail};
use crate::work_desk::check_on_workspace;
use crate::workflow_desk::{
    create_workflow, find_workflow_view, run_on_workflow, save_workflow,
};
use crate::workflow_view_properties::{sign_then_change, step_task_strategy};

const NOT_SIGNED_YET: &str = "not_signed_yet";
const SIGNED: &str = "signed";
const CHANGED_NOT_SIGNED: &str = "changed_not_signed";

#[test]
fn test_read_signature_state_property_follows_the_signing_lifecycle() {
    let cases = (step_task_strategy(), step_task_strategy());
    check_on_workspace(&cases, |prepared, (plan_task, changed_task)| {
        prop_assume!(plan_task != changed_task);
        let created =
            create_workflow(prepared, &plan_task, "build").map_err(fail)?;
        let workflow_id = created["workflow"]["id"].clone();
        let signed =
            run_on_workflow(&prepared.device, "sign_workflow", &workflow_id)
                .map_err(fail)?;
        let resaved = save_workflow(
            prepared,
            &prepared.workspace_id,
            &signed["workflow"],
        )
        .map_err(fail)?;
        let mut changed_workflow = signed["workflow"].clone();
        changed_workflow["agents"][0]["task"] = json!(changed_task);
        let changed =
            save_workflow(prepared, &prepared.workspace_id, &changed_workflow)
                .map_err(fail)?;

        prop_assert_eq!(&created["signature_state"], NOT_SIGNED_YET);
        prop_assert_eq!(&signed["signature_state"], SIGNED);
        prop_assert_eq!(&resaved["signature_state"], SIGNED);
        prop_assert_eq!(&changed["signature_state"], CHANGED_NOT_SIGNED);
        Ok(())
    });
}

#[test]
fn test_read_signature_state_property_unchanged_states_list_no_changes() {
    check_on_workspace(&step_task_strategy(), |prepared, plan_task| {
        let created =
            create_workflow(prepared, &plan_task, "build").map_err(fail)?;
        let workflow_id = created["workflow"]["id"].clone();
        let signed =
            run_on_workflow(&prepared.device, "sign_workflow", &workflow_id)
                .map_err(fail)?;
        let signed_again =
            run_on_workflow(&prepared.device, "sign_workflow", &workflow_id)
                .map_err(fail)?;

        prop_assert_eq!(&created["changes"], &json!([]));
        prop_assert_eq!(&signed["changes"], &json!([]));
        prop_assert_eq!(&signed_again["workflow"], &signed["workflow"]);
        prop_assert_eq!(&signed_again["document"], &signed["document"]);
        prop_assert_eq!(&signed_again["signature_state"], SIGNED);
        prop_assert_eq!(&signed_again["changes"], &json!([]));
        Ok(())
    });
}

#[test]
fn test_read_signature_state_property_a_changed_state_lists_changes() {
    let cases = (step_task_strategy(), step_task_strategy());
    check_on_workspace(&cases, |prepared, (plan_task, changed_task)| {
        prop_assume!(plan_task != changed_task);
        let (_, saved) = sign_then_change(prepared, &plan_task, &changed_task)
            .map_err(fail)?;
        let listed = find_workflow_view(prepared, &saved["workflow"]["id"])
            .map_err(fail)?;

        let changes = saved["changes"].as_array().cloned().unwrap_or_default();
        prop_assert_eq!(&saved["signature_state"], CHANGED_NOT_SIGNED);
        prop_assert!(!changes.is_empty());
        prop_assert_eq!(listed, Some(saved));
        Ok(())
    });
}

#[test]
fn test_read_stored_workflow_property_unknown_workflows_are_not_found() {
    let cases = uuid_text_strategy();
    check_on_workspace(&cases, |prepared, unknown_workflow| {
        let problem = read_problem(run_on_workflow(
            &prepared.device,
            "sign_workflow",
            &json!(unknown_workflow),
        ));

        let expected = format!("workflow {unknown_workflow} was not found");
        prop_assert_eq!(problem, expected);
        Ok(())
    });
}

#[test]
fn test_read_stored_workflow_property_finds_the_asked_workflow_among_many() {
    let cases = proptest::collection::vec(step_task_strategy(), 2..4);
    check_on_workspace(&cases, |prepared, plan_tasks| {
        let mut workflow_ids = Vec::new();
        for plan_task in &plan_tasks {
            let created =
                create_workflow(prepared, plan_task, "build").map_err(fail)?;
            workflow_ids.push(created["workflow"]["id"].clone());
        }

        for (workflow_id, plan_task) in workflow_ids.iter().zip(&plan_tasks) {
            let signed = run_on_workflow(
                &prepared.device,
                "sign_workflow",
                workflow_id,
            )
            .map_err(fail)?;
            prop_assert_eq!(&signed["workflow"]["id"], workflow_id);
            prop_assert_eq!(
                &signed["workflow"]["agents"][0]["task"],
                plan_task
            );
        }
        Ok(())
    });
}

#[test]
fn test_read_stored_workflow_property_discarding_restores_the_signed_text() {
    let cases = (step_task_strategy(), step_task_strategy());
    check_on_workspace(&cases, |prepared, (plan_task, changed_task)| {
        prop_assume!(plan_task != changed_task);
        let (signed, saved) =
            sign_then_change(prepared, &plan_task, &changed_task)
                .map_err(fail)?;

        let discarded = run_on_workflow(
            &prepared.device,
            "discard_workflow_change",
            &saved["workflow"]["id"],
        )
        .map_err(fail)?;

        prop_assert_eq!(&discarded["workflow"], &signed["workflow"]);
        prop_assert_eq!(&discarded["document"], &signed["document"]);
        prop_assert_eq!(&discarded["signature_state"], SIGNED);
        Ok(())
    });
}

fn revoke(device: &TestDevice, device_id: &str) -> Result<(), String> {
    device
        .run(&json!({ "command": "revoke_device", "device_id": device_id }))?;
    Ok(())
}

fn sign_on_joined_device(
    prepared: &PreparedWorkspace,
    plan_task: &str,
) -> Result<(TestDevice, String, Value), String> {
    let joining_device = TestDevice::start()?;
    let joined_id = pair_into_workspace(prepared, &joining_device)?;
    let created = create_workflow(prepared, plan_task, "build")?;
    let workflow_id = created["workflow"]["id"].clone();
    run_on_workflow(&joining_device, "sign_workflow", &workflow_id)?;
    Ok((joining_device, joined_id, workflow_id))
}

fn read_listed_state(
    prepared: &PreparedWorkspace,
    workflow_id: &Value,
) -> Result<Value, String> {
    let listed = find_workflow_view(prepared, workflow_id)?;
    let view = listed.ok_or("the workflow is not listed")?;
    Ok(view["signature_state"].clone())
}

#[test]
fn test_find_signer_property_another_live_device_vouches_for_it() {
    check_on_workspace(&step_task_strategy(), |prepared, plan_task| {
        let (_joining_device, _, workflow_id) =
            sign_on_joined_device(prepared, &plan_task).map_err(fail)?;

        let state = read_listed_state(prepared, &workflow_id).map_err(fail)?;

        prop_assert_eq!(state, json!(SIGNED));
        Ok(())
    });
}

#[test]
fn test_find_signer_property_a_revoked_signer_no_longer_vouches() {
    check_on_workspace(&step_task_strategy(), |prepared, plan_task| {
        let (_joining_device, joined_id, workflow_id) =
            sign_on_joined_device(prepared, &plan_task).map_err(fail)?;

        revoke(&prepared.device, &joined_id).map_err(fail)?;

        let state = read_listed_state(prepared, &workflow_id).map_err(fail)?;
        prop_assert_eq!(state, json!(CHANGED_NOT_SIGNED));
        Ok(())
    });
}

#[test]
fn test_find_signer_property_a_live_device_can_sign_again_after_revoking() {
    check_on_workspace(&step_task_strategy(), |prepared, plan_task| {
        let (_joining_device, joined_id, workflow_id) =
            sign_on_joined_device(prepared, &plan_task).map_err(fail)?;
        revoke(&prepared.device, &joined_id).map_err(fail)?;

        let signed_again =
            run_on_workflow(&prepared.device, "sign_workflow", &workflow_id)
                .map_err(fail)?;

        prop_assert_eq!(&signed_again["signature_state"], SIGNED);
        let state = read_listed_state(prepared, &workflow_id).map_err(fail)?;
        prop_assert_eq!(state, json!(SIGNED));
        Ok(())
    });
}
