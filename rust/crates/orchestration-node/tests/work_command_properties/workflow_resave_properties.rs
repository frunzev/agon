use proptest::prelude::*;
use serde_json::{Value, json};

use crate::handler_desk::{
    POST_METHOD, count_requests_to, read_problem, uuid_text_strategy,
};
use crate::support::test_device::{fail, read_text};
use crate::work_desk::check_on_workspace;
use crate::workflow_desk::{
    PUT_METHOD, WORKFLOWS_PATH, create_workflow, find_workflow_view,
    run_on_workflow, save_workflow,
};

const STEP_TASK_PATTERN: &str = "[A-Z][a-z]{3,10} [a-z]{3,10}";
const MOST_SAVES: usize = 3;
const MOST_SIGNINGS: usize = 3;
const MISSING_KEY_START: &str = "this device holds no key for workspace";
const SIGN_PATH_END: &str = "/sign";

fn create_and_sign(
    prepared: &crate::support::command_builders::PreparedWorkspace,
    plan_task: &str,
) -> Result<Value, String> {
    let created = create_workflow(prepared, plan_task, "Build")?;
    let workflow_id = created["workflow"]["id"].clone();
    run_on_workflow(&prepared.device, "sign_workflow", &workflow_id)
}

fn count_sign_requests(
    server: &crate::support::test_server::TestServer,
) -> usize {
    let mut count = 0;
    for request in server.recorded_requests() {
        if request.method == POST_METHOD
            && request.path.ends_with(SIGN_PATH_END)
        {
            count += 1;
        }
    }
    count
}

#[test]
fn test_prepare_workflow_resave_property_unchanged_saves_stay_signed() {
    let cases = (STEP_TASK_PATTERN, 1..=MOST_SAVES);
    check_on_workspace(&cases, |prepared, (plan_task, save_count)| {
        let signed = create_and_sign(prepared, &plan_task).map_err(fail)?;
        let opened_workflow = signed["workflow"].clone();

        let mut last_save = Value::Null;
        for _ in 0..save_count {
            last_save = save_workflow(
                prepared,
                &prepared.workspace_id,
                &opened_workflow,
            )
            .map_err(fail)?;
        }

        prop_assert_eq!(&last_save["signature_state"], "signed");
        prop_assert_eq!(&last_save["workflow"], &opened_workflow);
        prop_assert_eq!(&last_save["changes"], &json!([]));
        Ok(())
    });
}

#[test]
fn test_prepare_workflow_resave_property_a_changed_task_needs_signing() {
    let cases = (STEP_TASK_PATTERN, STEP_TASK_PATTERN);
    check_on_workspace(&cases, |prepared, (plan_task, changed_task)| {
        prop_assume!(plan_task != changed_task);
        let signed = create_and_sign(prepared, &plan_task).map_err(fail)?;
        let mut changed_workflow = signed["workflow"].clone();
        changed_workflow["agents"][0]["task"] = json!(changed_task);

        let saved =
            save_workflow(prepared, &prepared.workspace_id, &changed_workflow)
                .map_err(fail)?;

        prop_assert_eq!(&saved["signature_state"], "changed_not_signed");
        let changes = saved["changes"].as_array().cloned().unwrap_or_default();
        prop_assert!(!changes.is_empty());
        prop_assert_eq!(
            &saved["workflow"]["agents"][0]["task"],
            &json!(changed_task)
        );
        let resigned = run_on_workflow(
            &prepared.device,
            "sign_workflow",
            &saved["workflow"]["id"],
        )
        .map_err(fail)?;
        prop_assert_eq!(&resigned["signature_state"], "signed");
        Ok(())
    });
}

#[test]
fn test_prepare_workflow_resave_property_a_keyless_workspace_is_refused() {
    let cases = (STEP_TASK_PATTERN, uuid_text_strategy());
    check_on_workspace(&cases, |prepared, (plan_task, foreign_workspace)| {
        let signed = create_and_sign(prepared, &plan_task).map_err(fail)?;
        let puts_before =
            count_requests_to(&prepared.server, PUT_METHOD, WORKFLOWS_PATH);

        let problem = read_problem(save_workflow(
            prepared,
            &foreign_workspace,
            &signed["workflow"],
        ));

        let expected = format!("{MISSING_KEY_START} {foreign_workspace}");
        prop_assert_eq!(problem, expected);
        let puts_after =
            count_requests_to(&prepared.server, PUT_METHOD, WORKFLOWS_PATH);
        prop_assert_eq!(puts_after, puts_before);
        let listed = find_workflow_view(prepared, &signed["workflow"]["id"])
            .map_err(fail)?;
        prop_assert_eq!(listed, Some(signed));
        Ok(())
    });
}

#[test]
fn test_sign_workflow_property_signing_again_stays_signed() {
    let cases = (STEP_TASK_PATTERN, 1..=MOST_SIGNINGS);
    check_on_workspace(&cases, |prepared, (plan_task, signing_count)| {
        let created =
            create_workflow(prepared, &plan_task, "Build").map_err(fail)?;
        let workflow_id = created["workflow"]["id"].clone();

        for _ in 0..signing_count {
            let signed = run_on_workflow(
                &prepared.device,
                "sign_workflow",
                &workflow_id,
            )
            .map_err(fail)?;
            prop_assert_eq!(&signed["signature_state"], "signed");
            prop_assert_eq!(
                &signed["workflow"]["agents"],
                &created["workflow"]["agents"]
            );
        }

        let listed = find_workflow_view(prepared, &workflow_id)
            .map_err(fail)?
            .ok_or_else(|| fail("the workflow is listed"))?;
        prop_assert_eq!(&listed["signature_state"], "signed");
        Ok(())
    });
}

#[test]
fn test_sign_workflow_property_an_unknown_workflow_is_not_found() {
    check_on_workspace(&uuid_text_strategy(), |prepared, unknown_workflow| {
        let signings_before = count_sign_requests(&prepared.server);

        let problem = read_problem(run_on_workflow(
            &prepared.device,
            "sign_workflow",
            &json!(unknown_workflow),
        ));

        let expected = format!("workflow {unknown_workflow} was not found");
        prop_assert_eq!(problem, expected);
        prop_assert_eq!(
            count_sign_requests(&prepared.server),
            signings_before
        );
        Ok(())
    });
}

#[test]
fn test_sign_workflow_property_the_signature_names_this_device() {
    check_on_workspace(&STEP_TASK_PATTERN, |prepared, plan_task| {
        let status = prepared
            .device
            .run(&json!({ "command": "status" }))
            .map_err(fail)?;
        let own_device_id = read_text(&status, "/device_id").map_err(fail)?;

        let signed = create_and_sign(prepared, &plan_task).map_err(fail)?;

        let signature = &signed["workflow"]["signature"];
        prop_assert_eq!(&signature["signed_by"], &json!(own_device_id));
        prop_assert!(signed["signed_at"].is_string());
        prop_assert_eq!(&signed["changes"], &json!([]));
        Ok(())
    });
}
