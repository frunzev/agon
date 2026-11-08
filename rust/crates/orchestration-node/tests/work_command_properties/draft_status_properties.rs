use proptest::prelude::*;
use serde_json::{Value, json};

use crate::agent_desk::check_on_desk;
use crate::draft_desk::{
    DRAFTED_NAME_PATTERN, PLANNING_TASK, drafted_answer, everywhere,
    fail_draft, start_draft,
};
use crate::handler_desk::{
    list_object_keys, read_reply_problem, uuid_text_strategy,
};
use crate::support::command_builders::{
    create_task_command, two_step_workflow_command,
};
use crate::support::drafting_desk::{DraftingDesk, drafted_workflow_with};
use crate::support::test_device::{fail, read_text};
use crate::work_desk::open_work_place;

const NAME_TAKEN_START: &str = "the drafting agent did not answer with a \
                                workflow: another workflow is already named";

fn status_for(desk: &DraftingDesk, task_id: &str, workflow_id: &str) -> Value {
    desk.prepared.device.send(&json!({
        "command": "workflow_draft_status",
        "workspace_id": desk.prepared.workspace_id,
        "task_id": task_id,
        "workflow_id": workflow_id,
    }))
}

fn find_listing(desk: &DraftingDesk, workflow_id: &str) -> Option<Value> {
    let listings = desk.list_workflows().ok()?;
    let wanted = json!(workflow_id);
    listings
        .as_array()?
        .iter()
        .find(|listing| listing["workflow"]["id"] == wanted)
        .cloned()
}

fn create_named_workflow(
    desk: &DraftingDesk,
    workspace_id: &str,
    name: &str,
    availability: &Value,
) -> Result<Value, String> {
    let mut command =
        two_step_workflow_command(workspace_id, PLANNING_TASK, "Build");
    command["name"] = json!(name);
    command["availability"] = availability.clone();
    desk.prepared.device.run(&command)
}

#[test]
fn test_list_workflow_names_property_a_name_taken_here_is_refused() {
    check_on_desk(&DRAFTED_NAME_PATTERN, |desk, name| {
        let workspace_id = desk.prepared.workspace_id.clone();
        create_named_workflow(desk, &workspace_id, &name, &everywhere())
            .map_err(fail)?;
        let draft = start_draft(desk).map_err(fail)?;
        desk.finish(&draft, &drafted_answer(&draft, &name))
            .map_err(fail)?;

        let status = desk.status_reply(&draft);

        let problem = read_reply_problem(&status);
        prop_assert!(problem.starts_with(NAME_TAKEN_START), "{}", problem);
        prop_assert!(problem.ends_with(&name), "{}", problem);
        prop_assert_eq!(find_listing(desk, &draft.workflow_id), None);
        Ok(())
    });
}

#[test]
fn test_list_workflow_names_property_a_name_taken_elsewhere_is_free() {
    check_on_desk(&DRAFTED_NAME_PATTERN, |desk, name| {
        let elsewhere =
            open_work_place(&desk.prepared.device).map_err(fail)?;
        let only_there = json!({
            "kind": "only_workspaces",
            "workspaces": [elsewhere.workspace_id],
        });
        create_named_workflow(
            desk,
            &elsewhere.workspace_id,
            &name,
            &only_there,
        )
        .map_err(fail)?;
        let draft = start_draft(desk).map_err(fail)?;
        desk.finish(&draft, &drafted_answer(&draft, &name))
            .map_err(fail)?;

        let status = desk.status_reply(&draft);

        prop_assert_eq!(&status["ok"]["state"], "done");
        let listing = find_listing(desk, &draft.workflow_id)
            .ok_or_else(|| fail("the draft is listed"))?;
        prop_assert_eq!(&listing["workflow"]["name"], &json!(name));
        Ok(())
    });
}

#[test]
fn test_list_workflow_names_property_a_free_name_is_saved_once() {
    check_on_desk(&DRAFTED_NAME_PATTERN, |desk, name| {
        let draft = start_draft(desk).map_err(fail)?;
        desk.finish(&draft, &drafted_answer(&draft, &name))
            .map_err(fail)?;

        let status = desk.status_reply(&draft);

        prop_assert_eq!(&status["ok"]["state"], "done");
        let listings = desk.list_workflows().map_err(fail)?;
        let mut named_count = 0;
        for listing in listings.as_array().cloned().unwrap_or_default() {
            if listing["workflow"]["name"] == json!(name) {
                named_count += 1;
            }
        }
        prop_assert_eq!(named_count, 1);
        Ok(())
    });
}

#[test]
fn test_handle_workflow_draft_command_property_done_shows_the_listing() {
    check_on_desk(&DRAFTED_NAME_PATTERN, |desk, name| {
        let draft = start_draft(desk).map_err(fail)?;
        desk.finish(&draft, &drafted_answer(&draft, &name))
            .map_err(fail)?;

        let status = desk.status_reply(&draft);

        let listing = find_listing(desk, &draft.workflow_id);
        prop_assert_eq!(Some(status["ok"]["workflow"].clone()), listing);
        prop_assert_eq!(
            list_object_keys(&status["ok"]),
            ["state", "workflow"]
        );
        Ok(())
    });
}

#[test]
fn test_handle_workflow_draft_command_property_another_id_is_refused() {
    let cases = (DRAFTED_NAME_PATTERN, uuid_text_strategy());
    check_on_desk(&cases, |desk, (name, stray_id)| {
        let draft = start_draft(desk).map_err(fail)?;
        let stray_answer = drafted_workflow_with(
            &stray_id,
            &name,
            &everywhere(),
            PLANNING_TASK,
        );
        desk.finish(&draft, &stray_answer).map_err(fail)?;

        let status = desk.status_reply(&draft);

        let expected = format!(
            "the drafting agent wrote workflow {stray_id}, not {}",
            draft.workflow_id
        );
        prop_assert_eq!(read_reply_problem(&status), expected.as_str());
        prop_assert_eq!(find_listing(desk, &stray_id), None);
        prop_assert_eq!(find_listing(desk, &draft.workflow_id), None);
        Ok(())
    });
}

#[test]
fn test_handle_workflow_draft_command_property_working_names_only_state() {
    check_on_desk(&(1..=2_usize), |desk, poll_count| {
        let draft = start_draft(desk).map_err(fail)?;

        for _ in 0..poll_count {
            let status = desk.status_reply(&draft);
            prop_assert_eq!(list_object_keys(&status), ["ok"]);
            prop_assert_eq!(list_object_keys(&status["ok"]), ["state"]);
        }
        Ok(())
    });
}

#[test]
fn test_require_draft_task_property_an_unknown_task_is_not_found() {
    let cases = (uuid_text_strategy(), uuid_text_strategy());
    check_on_desk(&cases, |desk, (unknown_task, workflow_id)| {
        let status = status_for(desk, &unknown_task, &workflow_id);

        let expected = format!("draft task {unknown_task} was not found");
        prop_assert_eq!(read_reply_problem(&status), expected.as_str());
        Ok(())
    });
}

#[test]
fn test_require_draft_task_property_a_task_without_runs_is_working() {
    check_on_desk(&uuid_text_strategy(), |desk, workflow_id| {
        let prepared = &desk.prepared;
        let created = prepared
            .device
            .run(&create_task_command(
                &prepared.workspace_id,
                &prepared.project_id,
                "Waiting work",
            ))
            .map_err(fail)?;
        let task_id = read_text(&created, "/id").map_err(fail)?;

        let status = status_for(desk, &task_id, &workflow_id);

        prop_assert_eq!(&status["ok"], &json!({ "state": "working" }));
        Ok(())
    });
}

#[test]
fn test_require_draft_task_property_a_failed_draft_is_gone_afterwards() {
    check_on_desk(&"[a-z]{3,12}", |desk, reason| {
        let draft = start_draft(desk).map_err(fail)?;
        fail_draft(desk, &draft, &reason).map_err(fail)?;
        desk.status_reply(&draft);

        let again = desk.status_reply(&draft);

        let gone = format!("draft task {} was not found", draft.task_id);
        prop_assert_eq!(read_reply_problem(&again), gone.as_str());
        Ok(())
    });
}
