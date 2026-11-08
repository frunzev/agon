use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};

use crate::handler_desk::{
    POST_METHOD, count_requests_to, read_problem, uuid_text_strategy,
};
use crate::support::command_builders::two_step_workflow_command;
use crate::support::test_device::fail;
use crate::work_desk::check_on_workspace;
use crate::workflow_desk::{
    BUILD_AGENT_ID, PLAN_AGENT_ID, PUT_METHOD, WORKFLOWS_PATH,
    create_workflow, find_workflow_view, list_workflow_views, save_workflow,
};

const STEP_TASK_PATTERN: &str = "[A-Z][a-z]{3,10} [a-z]{3,10}";
const NAME_PROBLEM_START: &str = "a name ";
const SELF_CONNECTION_END: &str = "is connected to itself";
const CYCLE_PROBLEM: &str = "the connections form a cycle";
const MISSING_KEY_START: &str = "this device holds no key for workspace";
const BAD_WORKFLOW_NAMES: [&str; 5] = [
    "Release",
    "my flow",
    "",
    "ship_it",
    "release-and-deploy-everything-to-every-place",
];

fn connection(from: &str, to: &str) -> Value {
    json!({ "from": from, "to": to, "condition": null, "round_limit": null })
}

fn count_workflow_writes(
    server: &crate::support::test_server::TestServer,
) -> usize {
    count_requests_to(server, POST_METHOD, WORKFLOWS_PATH)
        + count_requests_to(server, PUT_METHOD, WORKFLOWS_PATH)
}

#[test]
fn test_check_workflow_upload_property_a_bad_workflow_name_is_refused() {
    let cases = (select(BAD_WORKFLOW_NAMES.to_vec()), STEP_TASK_PATTERN);
    check_on_workspace(&cases, |prepared, (bad_name, plan_task)| {
        let writes_before = count_workflow_writes(&prepared.server);
        let mut command = two_step_workflow_command(
            &prepared.workspace_id,
            &plan_task,
            "Build",
        );
        command["name"] = json!(bad_name);

        let problem = read_problem(prepared.device.run(&command));

        prop_assert!(problem.starts_with(NAME_PROBLEM_START), "{}", problem);
        prop_assert_eq!(
            count_workflow_writes(&prepared.server),
            writes_before
        );
        let views =
            list_workflow_views(&prepared.device, &prepared.workspace_id)
                .map_err(fail)?;
        prop_assert!(views.is_empty(), "{:?}", views);
        Ok(())
    });
}

#[test]
fn test_check_workflow_upload_property_a_self_connection_is_refused() {
    let cases = (
        select(vec![PLAN_AGENT_ID, BUILD_AGENT_ID]),
        STEP_TASK_PATTERN,
    );
    check_on_workspace(&cases, |prepared, (looped_agent, plan_task)| {
        let created =
            create_workflow(prepared, &plan_task, "Build").map_err(fail)?;
        let stored_workflow = created["workflow"].clone();
        let writes_before = count_workflow_writes(&prepared.server);
        let mut looped = stored_workflow.clone();
        looped["connections"] =
            json!([connection(looped_agent, looped_agent)]);

        let saved = save_workflow(prepared, &prepared.workspace_id, &looped);

        let problem = read_problem(saved);
        prop_assert!(problem.ends_with(SELF_CONNECTION_END), "{}", problem);
        prop_assert_eq!(
            count_workflow_writes(&prepared.server),
            writes_before
        );
        let listed = find_workflow_view(prepared, &stored_workflow["id"])
            .map_err(fail)?
            .ok_or_else(|| fail("the workflow is still listed"))?;
        prop_assert_eq!(&listed["workflow"], &stored_workflow);
        Ok(())
    });
}

#[test]
fn test_check_workflow_upload_property_a_plain_cycle_is_refused() {
    check_on_workspace(&STEP_TASK_PATTERN, |prepared, plan_task| {
        let writes_before = count_workflow_writes(&prepared.server);
        let mut command = two_step_workflow_command(
            &prepared.workspace_id,
            &plan_task,
            "Build",
        );
        command["connections"] = json!([
            connection(PLAN_AGENT_ID, BUILD_AGENT_ID),
            connection(BUILD_AGENT_ID, PLAN_AGENT_ID),
        ]);

        let problem = read_problem(prepared.device.run(&command));

        prop_assert_eq!(problem, CYCLE_PROBLEM);
        prop_assert_eq!(
            count_workflow_writes(&prepared.server),
            writes_before
        );
        Ok(())
    });
}

#[test]
fn test_prepare_workflow_upload_property_the_server_sees_sealed_tasks() {
    let cases = ("[a-z]{18,24}", "[a-z]{18,24}");
    check_on_workspace(&cases, |prepared, (plan_secret, build_secret)| {
        let created = create_workflow(prepared, &plan_secret, &build_secret)
            .map_err(fail)?;

        let stored = prepared.server.read_stored_state().map_err(fail)?;
        prop_assert!(!stored.contains(&plan_secret));
        prop_assert!(!stored.contains(&build_secret));
        let listed = find_workflow_view(prepared, &created["workflow"]["id"])
            .map_err(fail)?
            .ok_or_else(|| fail("the workflow is listed"))?;
        let agents = &listed["workflow"]["agents"];
        prop_assert_eq!(&agents[0]["task"], &json!(plan_secret));
        prop_assert_eq!(&agents[1]["task"], &json!(build_secret));
        Ok(())
    });
}

#[test]
fn test_prepare_workflow_upload_property_a_keyless_workspace_is_refused() {
    let cases = (uuid_text_strategy(), STEP_TASK_PATTERN);
    check_on_workspace(&cases, |prepared, (foreign_workspace, plan_task)| {
        let writes_before = count_workflow_writes(&prepared.server);
        let command =
            two_step_workflow_command(&foreign_workspace, &plan_task, "Build");

        let problem = read_problem(prepared.device.run(&command));

        let expected = format!("{MISSING_KEY_START} {foreign_workspace}");
        prop_assert_eq!(problem, expected);
        prop_assert_eq!(
            count_workflow_writes(&prepared.server),
            writes_before
        );
        Ok(())
    });
}

#[test]
fn test_prepare_workflow_upload_property_the_reply_shows_what_was_created() {
    let cases = (STEP_TASK_PATTERN, STEP_TASK_PATTERN);
    check_on_workspace(&cases, |prepared, (plan_task, build_task)| {
        let created = create_workflow(prepared, &plan_task, &build_task)
            .map_err(fail)?;

        let workflow = &created["workflow"];
        prop_assert_eq!(&workflow["name"], "release");
        prop_assert_eq!(&workflow["signature"], &Value::Null);
        prop_assert_eq!(&workflow["agents"][0]["task"], &json!(plan_task));
        prop_assert_eq!(&workflow["agents"][1]["task"], &json!(build_task));
        prop_assert_eq!(&created["signature_state"], "not_signed_yet");
        prop_assert_eq!(&created["agent_names"], &json!(["plan", "build"]));
        let listed =
            find_workflow_view(prepared, &workflow["id"]).map_err(fail)?;
        prop_assert_eq!(listed, Some(created));
        Ok(())
    });
}
