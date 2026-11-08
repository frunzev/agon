use std::collections::BTreeSet;

use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};

use crate::agent_desk::{
    AGENT_KINDS, PLAN_AGENT_ID, REQUEST_PATTERN, STEP_TASK_PATTERN,
    change_command, check_on_desk, create_two_step_workflow,
    draft_command_for, fill_command, queue_and_claim,
};
use crate::handler_desk::{
    POST_METHOD, count_requests_to, read_problem, uuid_text_strategy,
};
use crate::support::drafting_desk::DraftingDesk;
use crate::support::test_device::{describe, fail, read_text};

const BLANK_PATTERN: &str = "[ \t\n]{0,6}";
const TASKS_PATH: &str = "/tasks";
const DRAFTING_AGENT: &str = "claude_code";
const MOST_DRAFTS: usize = 3;

fn count_task_posts(desk: &DraftingDesk) -> usize {
    count_requests_to(&desk.prepared.server, POST_METHOD, TASKS_PATH)
}

fn task_json(
    assignment_task: &impl serde::Serialize,
) -> Result<Value, String> {
    serde_json::to_value(assignment_task).map_err(describe)
}

#[test]
fn test_require_text_property_a_blank_description_queues_nothing() {
    check_on_desk(&BLANK_PATTERN, |desk, blank_text| {
        let posts_before = count_task_posts(desk);

        let problem = read_problem(
            desk.prepared
                .device
                .run(&draft_command_for(desk, &blank_text)),
        );

        prop_assert_eq!(problem, "the workflow description cannot be empty");
        prop_assert_eq!(count_task_posts(desk), posts_before);
        Ok(())
    });
}

#[test]
fn test_require_text_property_a_blank_change_request_queues_nothing() {
    let cases = (BLANK_PATTERN, select(AGENT_KINDS.to_vec()));
    check_on_desk(&cases, |desk, (blank_text, agent)| {
        let workflow = create_two_step_workflow(desk, "Plan it", "Build it")
            .map_err(fail)?;
        let posts_before = count_task_posts(desk);

        let command =
            change_command(desk, &workflow["id"], &blank_text, agent);
        let problem = read_problem(desk.prepared.device.run(&command));

        prop_assert_eq!(problem, "the change request cannot be empty");
        prop_assert_eq!(count_task_posts(desk), posts_before);
        Ok(())
    });
}

#[test]
fn test_require_text_property_padded_text_reaches_the_prompt_unchanged() {
    let cases = (BLANK_PATTERN, REQUEST_PATTERN, BLANK_PATTERN);
    check_on_desk(&cases, |desk, (before, words, after)| {
        let padded = format!("{before}{words}{after}");

        let (_, assignment) =
            queue_and_claim(desk, &draft_command_for(desk, &padded))
                .map_err(fail)?;

        let details = &assignment.task.details;
        prop_assert!(details.contains(&padded), "{}", details);
        Ok(())
    });
}

#[test]
fn test_build_agent_task_property_a_draft_task_lives_in_the_workspace() {
    check_on_desk(&REQUEST_PATTERN, |desk, description| {
        let (reply, assignment) =
            queue_and_claim(desk, &draft_command_for(desk, &description))
                .map_err(fail)?;

        let task = task_json(&assignment.task).map_err(fail)?;
        prop_assert_eq!(&task["id"], &reply["task_id"]);
        prop_assert_eq!(
            &task["workspace_id"],
            &json!(desk.prepared.workspace_id)
        );
        prop_assert_eq!(&task["project_id"], &Value::Null);
        prop_assert_eq!(&task["title"], "Draft new workflow");
        prop_assert_eq!(
            &task["doer"],
            &json!({
                "kind": "one_agent",
                "agent": DRAFTING_AGENT,
            })
        );
        prop_assert_eq!(
            &task["runs_on"],
            &json!({ "kind": "any_free_runner" })
        );
        prop_assert_eq!(&task["agent_place"], &Value::Null);
        prop_assert_eq!(&task["skills"], &json!([]));
        prop_assert_eq!(&task["uses_automatic_skills"], false);
        prop_assert_eq!(&task["approval_policy"], "never_ask");
        prop_assert_eq!(&task["schedule"], &Value::Null);
        Ok(())
    });
}

#[test]
fn test_build_agent_task_property_a_change_runs_the_chosen_agent() {
    let cases = (REQUEST_PATTERN, select(AGENT_KINDS.to_vec()));
    check_on_desk(&cases, |desk, (request, agent)| {
        let workflow = create_two_step_workflow(desk, "Plan it", "Build it")
            .map_err(fail)?;

        let command = change_command(desk, &workflow["id"], &request, agent);
        let (reply, assignment) =
            queue_and_claim(desk, &command).map_err(fail)?;

        let task = task_json(&assignment.task).map_err(fail)?;
        prop_assert_eq!(&reply["drafter"], agent);
        prop_assert_eq!(&reply["workflow_id"], &workflow["id"]);
        prop_assert_eq!(&task["doer"]["agent"], agent);
        let expected_title = format!(
            "Change workflow {}",
            workflow["name"].as_str().unwrap_or_default()
        );
        prop_assert_eq!(&task["title"], &json!(expected_title));
        prop_assert_eq!(
            &task["workspace_id"],
            &json!(desk.prepared.workspace_id)
        );
        Ok(())
    });
}

#[test]
fn test_build_agent_task_property_every_agent_task_gets_a_fresh_id() {
    check_on_desk(&(2..=MOST_DRAFTS), |desk, draft_count| {
        let mut task_ids = BTreeSet::new();
        let mut workflow_ids = BTreeSet::new();

        for _ in 0..draft_count {
            let (reply, _) = queue_and_claim(
                desk,
                &draft_command_for(desk, "Plan, then build"),
            )
            .map_err(fail)?;
            task_ids.insert(read_text(&reply, "/task_id").map_err(fail)?);
            workflow_ids
                .insert(read_text(&reply, "/workflow_id").map_err(fail)?);
        }

        prop_assert_eq!(task_ids.len(), draft_count);
        prop_assert_eq!(workflow_ids.len(), draft_count);
        Ok(())
    });
}

#[test]
fn test_handle_workflow_agent_command_property_fill_names_its_drafter() {
    check_on_desk(&STEP_TASK_PATTERN, |desk, plan_task| {
        let workflow = create_two_step_workflow(desk, &plan_task, "Build")
            .map_err(fail)?;

        let command = fill_command(desk, &workflow["id"], PLAN_AGENT_ID);
        let (reply, assignment) =
            queue_and_claim(desk, &command).map_err(fail)?;

        prop_assert_eq!(&reply["drafter"], DRAFTING_AGENT);
        prop_assert_eq!(&reply["workflow_id"], &workflow["id"]);
        prop_assert_eq!(
            &json!(assignment.task.id.0.to_string()),
            &reply["task_id"]
        );
        let expected_title = format!(
            "Fill in agent plan of {}",
            workflow["name"].as_str().unwrap_or_default()
        );
        prop_assert_eq!(&assignment.task.title, &expected_title);
        Ok(())
    });
}

#[test]
fn test_handle_workflow_agent_command_property_an_unknown_agent_is_refused() {
    check_on_desk(&uuid_text_strategy(), |desk, unknown_agent| {
        let workflow = create_two_step_workflow(desk, "Plan it", "Build it")
            .map_err(fail)?;
        let posts_before = count_task_posts(desk);

        let command = fill_command(desk, &workflow["id"], &unknown_agent);
        let problem = read_problem(desk.prepared.device.run(&command));

        let expected = format!("workflow agent {unknown_agent} was not found");
        prop_assert_eq!(problem, expected);
        prop_assert_eq!(count_task_posts(desk), posts_before);
        Ok(())
    });
}

#[test]
fn test_handle_workflow_agent_command_property_an_unknown_workflow_is_refused()
{
    let cases = (uuid_text_strategy(), select(AGENT_KINDS.to_vec()));
    check_on_desk(&cases, |desk, (unknown_workflow, agent)| {
        let posts_before = count_task_posts(desk);
        let workflow_id = json!(unknown_workflow);

        let change = change_command(desk, &workflow_id, "Add a step", agent);
        let change_problem = read_problem(desk.prepared.device.run(&change));
        let fill = fill_command(desk, &workflow_id, PLAN_AGENT_ID);
        let fill_problem = read_problem(desk.prepared.device.run(&fill));

        let expected = format!("workflow {unknown_workflow} was not found");
        prop_assert_eq!(&change_problem, &expected);
        prop_assert_eq!(&fill_problem, &expected);
        prop_assert_eq!(count_task_posts(desk), posts_before);
        Ok(())
    });
}
