use proptest::prelude::*;
use serde_json::{Value, json};

use crate::handler_desk::{read_problem, uuid_text_strategy};
use crate::support::command_builders::two_step_workflow_command;
use crate::support::test_device::{fail, read_text};
use crate::work_desk::{check_on_workspace, open_work_place};
use crate::workflow_desk::{
    create_workflow, find_workflow_view, list_workflow_views, run_on_workflow,
    save_workflow,
};

const STEP_TASK_PATTERN: &str = "[A-Z][a-z]{3,10} [a-z]{3,10}";
const DEVICE_NAME: &str = "air-laptop";
const NO_SIGNED_VERSION: &str = "the workflow has no signed version";

fn list_ids(views: &[Value]) -> Vec<Value> {
    let mut workflow_ids = Vec::new();
    for view in views {
        workflow_ids.push(view["workflow"]["id"].clone());
    }
    workflow_ids
}

#[test]
fn test_show_workflow_property_every_reply_equals_the_listing() {
    let cases = (STEP_TASK_PATTERN, STEP_TASK_PATTERN);
    check_on_workspace(&cases, |prepared, (plan_task, changed_task)| {
        let device = &prepared.device;
        let created =
            create_workflow(prepared, &plan_task, "Build").map_err(fail)?;
        let workflow_id = created["workflow"]["id"].clone();
        let signed = run_on_workflow(device, "sign_workflow", &workflow_id)
            .map_err(fail)?;
        let mut changed_workflow = signed["workflow"].clone();
        changed_workflow["agents"][0]["task"] = json!(changed_task);
        let saved =
            save_workflow(prepared, &prepared.workspace_id, &changed_workflow)
                .map_err(fail)?;
        let saved_listing =
            find_workflow_view(prepared, &workflow_id).map_err(fail)?;
        let discarded =
            run_on_workflow(device, "discard_workflow_change", &workflow_id)
                .map_err(fail)?;

        prop_assert_eq!(saved_listing, Some(saved));
        let discarded_listing =
            find_workflow_view(prepared, &workflow_id).map_err(fail)?;
        prop_assert_eq!(discarded_listing, Some(discarded));
        Ok(())
    });
}

#[test]
fn test_show_workflow_property_names_who_changed_it() {
    check_on_workspace(&STEP_TASK_PATTERN, |prepared, plan_task| {
        let status = prepared
            .device
            .run(&json!({ "command": "status" }))
            .map_err(fail)?;
        let own_device_id = read_text(&status, "/device_id").map_err(fail)?;

        let created =
            create_workflow(prepared, &plan_task, "Build").map_err(fail)?;

        prop_assert_eq!(&created["changed_by"], &json!(own_device_id));
        prop_assert_eq!(&created["changed_by_name"], DEVICE_NAME);
        prop_assert!(created["changed_at"].is_string());
        prop_assert_eq!(&created["signed_at"], &Value::Null);
        Ok(())
    });
}

#[test]
fn test_show_workflow_property_discard_restores_the_signed_version() {
    let cases = (STEP_TASK_PATTERN, STEP_TASK_PATTERN);
    check_on_workspace(&cases, |prepared, (plan_task, changed_task)| {
        let device = &prepared.device;
        let created =
            create_workflow(prepared, &plan_task, "Build").map_err(fail)?;
        let workflow_id = created["workflow"]["id"].clone();
        let signed = run_on_workflow(device, "sign_workflow", &workflow_id)
            .map_err(fail)?;
        let mut changed_workflow = signed["workflow"].clone();
        changed_workflow["agents"][0]["task"] = json!(changed_task);
        save_workflow(prepared, &prepared.workspace_id, &changed_workflow)
            .map_err(fail)?;

        let discarded =
            run_on_workflow(device, "discard_workflow_change", &workflow_id)
                .map_err(fail)?;

        prop_assert_eq!(&discarded["workflow"], &signed["workflow"]);
        prop_assert_eq!(&discarded["signature_state"], "signed");
        prop_assert_eq!(&discarded["changes"], &json!([]));
        Ok(())
    });
}

#[test]
fn test_handle_workflow_command_property_lists_only_available_workflows() {
    check_on_workspace(&STEP_TASK_PATTERN, |prepared, plan_task| {
        let device = &prepared.device;
        let elsewhere = open_work_place(device).map_err(fail)?;
        let everywhere =
            create_workflow(prepared, &plan_task, "Build").map_err(fail)?;
        let mut only_there_command = two_step_workflow_command(
            &elsewhere.workspace_id,
            &plan_task,
            "Build",
        );
        only_there_command["availability"] = json!({
            "kind": "only_workspaces",
            "workspaces": [elsewhere.workspace_id],
        });
        let only_there = device.run(&only_there_command).map_err(fail)?;

        let here_views = list_workflow_views(device, &prepared.workspace_id)
            .map_err(fail)?;
        let there_views = list_workflow_views(device, &elsewhere.workspace_id)
            .map_err(fail)?;

        let here_ids = list_ids(&here_views);
        let there_ids = list_ids(&there_views);
        let everywhere_id = &everywhere["workflow"]["id"];
        let only_there_id = &only_there["workflow"]["id"];
        prop_assert!(here_ids.contains(everywhere_id));
        prop_assert!(!here_ids.contains(only_there_id));
        prop_assert!(there_ids.contains(everywhere_id));
        prop_assert!(there_ids.contains(only_there_id));
        Ok(())
    });
}

#[test]
fn test_handle_workflow_command_property_discard_needs_a_signed_version() {
    check_on_workspace(&STEP_TASK_PATTERN, |prepared, plan_task| {
        let created =
            create_workflow(prepared, &plan_task, "Build").map_err(fail)?;
        let workflow_id = created["workflow"]["id"].clone();

        let problem = read_problem(run_on_workflow(
            &prepared.device,
            "discard_workflow_change",
            &workflow_id,
        ));

        prop_assert!(problem.contains(NO_SIGNED_VERSION), "{}", problem);
        prop_assert!(problem.contains("409"), "{}", problem);
        let listed =
            find_workflow_view(prepared, &workflow_id).map_err(fail)?;
        prop_assert_eq!(listed, Some(created));
        Ok(())
    });
}

#[test]
fn test_handle_workflow_command_property_saving_an_unknown_workflow_fails() {
    let cases = (uuid_text_strategy(), STEP_TASK_PATTERN);
    check_on_workspace(&cases, |prepared, (unknown_workflow, plan_task)| {
        let created =
            create_workflow(prepared, &plan_task, "Build").map_err(fail)?;
        let mut stranger = created["workflow"].clone();
        stranger["id"] = json!(unknown_workflow);

        let problem = read_problem(save_workflow(
            prepared,
            &prepared.workspace_id,
            &stranger,
        ));

        let expected = format!("workflow {unknown_workflow} was not found");
        prop_assert_eq!(problem, expected);
        let listed = find_workflow_view(prepared, &json!(unknown_workflow))
            .map_err(fail)?;
        prop_assert_eq!(listed, None);
        Ok(())
    });
}
