use orchestration_core::identifiers::WorkspaceId;
use orchestration_core::naming::MAXIMUM_NAME_LENGTH;
use orchestration_core::scope::WorkspaceScope;
use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};
use uuid::Uuid;

use crate::agent_desk::{
    AGENT_KINDS, PLAN_AGENT_ID, REQUEST_PATTERN, STEP_TASK_PATTERN,
    change_command, check_on_desk, create_two_step_workflow,
    draft_command_for, fill_command, queue_and_claim, read_embedded_workflow,
};
use crate::support::command_builders::two_step_workflow_command;
use crate::support::drafting_desk::DraftingDesk;
use crate::support::test_device::{describe, fail, read_text};

const WORKFLOW_NAME_PATTERN: &str = "[a-z]{4,8}-[a-z]{4,8}";
const CHANGE_END_MARK: &str = "\nRequested change:";
const FILL_END_MARK: &str = "\n\nReply with one JSON object";
const KEEP_ID_RULE: &str = "Keep the workflow id and set signature to null.";
const NOTHING_ELSE: &str = "Change nothing else.";

fn find_listed_workflow(
    desk: &DraftingDesk,
    workflow_id: &Value,
) -> Result<Value, String> {
    let listings = desk.list_workflows()?;
    let listing = listings
        .as_array()
        .and_then(|listed| {
            listed
                .iter()
                .find(|listing| &listing["workflow"]["id"] == workflow_id)
        })
        .ok_or("the workflow is listed")?;
    Ok(listing["workflow"].clone())
}

fn render_scope(scope: &WorkspaceScope) -> Result<String, String> {
    serde_json::to_string(scope).map_err(describe)
}

#[test]
fn test_workflow_render_drafting_prompt_property_names_the_id_and_words() {
    check_on_desk(&REQUEST_PATTERN, |desk, description| {
        let command = draft_command_for(desk, &description);

        let (reply, assignment) =
            queue_and_claim(desk, &command).map_err(fail)?;

        let details = &assignment.task.details;
        let workflow_id = read_text(&reply, "/workflow_id").map_err(fail)?;
        prop_assert!(details.starts_with("Draft a new workflow.\n"));
        let id_line = format!("Workflow id: {workflow_id}\n");
        prop_assert!(details.contains(&id_line), "{}", details);
        let words = format!("What it should do:\n{description}\n");
        prop_assert!(details.contains(&words), "{}", details);
        Ok(())
    });
}

#[test]
fn test_workflow_render_drafting_prompt_property_offers_both_availabilities() {
    check_on_desk(&REQUEST_PATTERN, |desk, description| {
        let workspace_uuid =
            Uuid::parse_str(&desk.prepared.workspace_id).map_err(fail)?;
        let here_only = WorkspaceScope::OnlyWorkspaces {
            workspaces: vec![WorkspaceId(workspace_uuid)],
        };

        let (_, assignment) =
            queue_and_claim(desk, &draft_command_for(desk, &description))
                .map_err(fail)?;

        let details = &assignment.task.details;
        let here_only_json = render_scope(&here_only).map_err(fail)?;
        let everywhere_json =
            render_scope(&WorkspaceScope::AllWorkspaces).map_err(fail)?;
        prop_assert!(details.contains(&here_only_json), "{}", details);
        prop_assert!(details.contains(&everywhere_json), "{}", details);
        Ok(())
    });
}

#[test]
fn test_workflow_render_drafting_prompt_property_names_taken_names_and_rule() {
    check_on_desk(&WORKFLOW_NAME_PATTERN, |desk, taken_name| {
        let mut create_command = two_step_workflow_command(
            &desk.prepared.workspace_id,
            "Plan",
            "Build",
        );
        create_command["name"] = json!(taken_name);
        desk.prepared.device.run(&create_command).map_err(fail)?;

        let (_, assignment) = queue_and_claim(
            desk,
            &draft_command_for(desk, "Plan, then build"),
        )
        .map_err(fail)?;

        let details = &assignment.task.details;
        let name_rule = format!(
            "Choose its name: lowercase letters, digits and dashes, at most \
             {MAXIMUM_NAME_LENGTH} characters, and no workflow above has it."
        );
        prop_assert!(details.contains(&name_rule), "{}", details);
        prop_assert!(details.contains(&taken_name), "{}", details);
        Ok(())
    });
}

#[test]
fn test_render_change_prompt_property_quotes_the_request_before_the_rules() {
    let cases = (REQUEST_PATTERN, select(AGENT_KINDS.to_vec()));
    check_on_desk(&cases, |desk, (request, agent)| {
        let workflow = create_two_step_workflow(desk, "Plan it", "Build it")
            .map_err(fail)?;
        let command = change_command(desk, &workflow["id"], &request, agent);

        let (_, assignment) = queue_and_claim(desk, &command).map_err(fail)?;

        let details = &assignment.task.details;
        prop_assert!(details.starts_with("Change this workflow.\n"));
        let quoted = format!("Requested change:\n{request}\n\n");
        let quoted_at = details.find(&quoted);
        let rule_at = details.find(KEEP_ID_RULE);
        prop_assert!(quoted_at.is_some(), "{}", details);
        prop_assert!(rule_at > quoted_at, "{}", details);
        Ok(())
    });
}

#[test]
fn test_render_change_prompt_property_embeds_the_opened_workflow() {
    let cases = (STEP_TASK_PATTERN, STEP_TASK_PATTERN);
    check_on_desk(&cases, |desk, (plan_task, build_task)| {
        let workflow = create_two_step_workflow(desk, &plan_task, &build_task)
            .map_err(fail)?;
        let command =
            change_command(desk, &workflow["id"], "Add a review", "codex");

        let (_, assignment) = queue_and_claim(desk, &command).map_err(fail)?;

        let embedded =
            read_embedded_workflow(&assignment.task.details, CHANGE_END_MARK)
                .map_err(fail)?;
        let listed =
            find_listed_workflow(desk, &workflow["id"]).map_err(fail)?;
        prop_assert_eq!(&embedded, &listed);
        prop_assert_eq!(&embedded["agents"][0]["task"], &json!(plan_task));
        prop_assert_eq!(&embedded["agents"][1]["task"], &json!(build_task));
        Ok(())
    });
}

#[test]
fn test_render_change_prompt_property_a_signed_workflow_is_embedded_opened() {
    check_on_desk(&STEP_TASK_PATTERN, |desk, plan_task| {
        let workflow = create_two_step_workflow(desk, &plan_task, "Build")
            .map_err(fail)?;
        let workflow_id = read_text(&workflow, "/id").map_err(fail)?;
        desk.sign(&workflow_id).map_err(fail)?;
        let command =
            change_command(desk, &workflow["id"], "Rename a step", "codex");

        let (_, assignment) = queue_and_claim(desk, &command).map_err(fail)?;

        let embedded =
            read_embedded_workflow(&assignment.task.details, CHANGE_END_MARK)
                .map_err(fail)?;
        let listed =
            find_listed_workflow(desk, &workflow["id"]).map_err(fail)?;
        prop_assert_eq!(&embedded["agents"], &listed["agents"]);
        prop_assert_eq!(&embedded["agents"][0]["task"], &json!(plan_task));
        Ok(())
    });
}

#[test]
fn test_render_fill_prompt_property_names_the_agent_to_fill() {
    check_on_desk(&STEP_TASK_PATTERN, |desk, plan_task| {
        let workflow = create_two_step_workflow(desk, &plan_task, "Build")
            .map_err(fail)?;
        let command = fill_command(desk, &workflow["id"], PLAN_AGENT_ID);

        let (_, assignment) = queue_and_claim(desk, &command).map_err(fail)?;

        let details = &assignment.task.details;
        let opening = format!(
            "Fill in every setting of the agent plan (id {PLAN_AGENT_ID}) in \
             this workflow:"
        );
        prop_assert!(details.starts_with(&opening), "{}", details);
        Ok(())
    });
}

#[test]
fn test_render_fill_prompt_property_embeds_the_opened_workflow() {
    let cases = (STEP_TASK_PATTERN, STEP_TASK_PATTERN);
    check_on_desk(&cases, |desk, (plan_task, build_task)| {
        let workflow = create_two_step_workflow(desk, &plan_task, &build_task)
            .map_err(fail)?;
        let command = fill_command(desk, &workflow["id"], PLAN_AGENT_ID);

        let (_, assignment) = queue_and_claim(desk, &command).map_err(fail)?;

        let embedded =
            read_embedded_workflow(&assignment.task.details, FILL_END_MARK)
                .map_err(fail)?;
        let listed =
            find_listed_workflow(desk, &workflow["id"]).map_err(fail)?;
        prop_assert_eq!(embedded, listed);
        Ok(())
    });
}

#[test]
fn test_render_fill_prompt_property_keeps_the_rest_before_the_rules() {
    check_on_desk(&STEP_TASK_PATTERN, |desk, build_task| {
        let workflow = create_two_step_workflow(desk, "Plan", &build_task)
            .map_err(fail)?;
        let command = fill_command(desk, &workflow["id"], PLAN_AGENT_ID);

        let (_, assignment) = queue_and_claim(desk, &command).map_err(fail)?;

        let details = &assignment.task.details;
        let nothing_else_at = details.find(NOTHING_ELSE);
        let rule_at = details.find(KEEP_ID_RULE);
        prop_assert!(nothing_else_at.is_some(), "{}", details);
        prop_assert!(rule_at > nothing_else_at, "{}", details);
        Ok(())
    });
}
