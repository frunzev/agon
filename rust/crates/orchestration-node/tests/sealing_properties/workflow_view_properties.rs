use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::command_builders::{
    PreparedWorkspace, two_step_workflow_command,
};
use crate::support::test_device::fail;
use crate::work_desk::check_on_workspace;
use crate::workflow_desk::{
    create_workflow, find_workflow_view, run_on_workflow, save_workflow,
};

const UNCHANGED_SIDE: &str = "unchanged";
const ADDED_SIDE: &str = "added";
const REMOVED_SIDE: &str = "removed";
const SEALED_MARK: &str = "sealed-v1:";
const STEP_NAME_START: &str = "  - name: ";
const SEALED_LOOKING_LABEL_PATTERN: &str = "sealed-v1:[0-9a-f]{0,16}";
const OPENED_VIEW_PARTS: [&str; 4] =
    ["/document", "/changes", "/workflow/agents", "/agent_names"];

pub fn step_task_strategy() -> impl Strategy<Value = String> {
    prop_oneof![
        "[a-z]{3,10}",
        "[a-z]{2,6}[\u{202E}\u{200B}\u{7F}\r][a-z]{2,6}",
        "[A-Z][a-z]{3,8} [a-z]{3,8}",
    ]
}

pub fn collect_diff_lines(changes: &Value, sides: &[&str]) -> Vec<String> {
    let mut lines = Vec::new();
    for change in changes.as_array().cloned().unwrap_or_default() {
        for side in sides {
            if let Some(line) = change.get(*side).and_then(Value::as_str) {
                lines.push(line.to_owned());
            }
        }
    }
    lines
}

pub fn read_document_lines(view: &Value) -> Vec<String> {
    let document = view["document"].as_str().unwrap_or_default();
    document.lines().map(str::to_owned).collect()
}

pub fn sign_then_change(
    prepared: &PreparedWorkspace,
    plan_task: &str,
    changed_task: &str,
) -> Result<(Value, Value), String> {
    let created = create_workflow(prepared, plan_task, "build")?;
    let workflow_id = created["workflow"]["id"].clone();
    let signed =
        run_on_workflow(&prepared.device, "sign_workflow", &workflow_id)?;
    let mut changed_workflow = signed["workflow"].clone();
    changed_workflow["agents"][0]["task"] = json!(changed_task);
    let saved =
        save_workflow(prepared, &prepared.workspace_id, &changed_workflow)?;
    Ok((signed, saved))
}

#[test]
fn test_build_workflow_view_property_changes_end_in_the_current_document() {
    let cases = (step_task_strategy(), step_task_strategy());
    check_on_workspace(&cases, |prepared, (plan_task, changed_task)| {
        prop_assume!(plan_task != changed_task);
        let (_, saved) = sign_then_change(prepared, &plan_task, &changed_task)
            .map_err(fail)?;

        let current_side = collect_diff_lines(
            &saved["changes"],
            &[UNCHANGED_SIDE, ADDED_SIDE],
        );

        prop_assert_eq!(&saved["signature_state"], "changed_not_signed");
        prop_assert_eq!(current_side, read_document_lines(&saved));
        Ok(())
    });
}

#[test]
fn test_build_workflow_view_property_changes_start_at_the_signed_document() {
    let cases = (step_task_strategy(), step_task_strategy());
    check_on_workspace(&cases, |prepared, (plan_task, changed_task)| {
        prop_assume!(plan_task != changed_task);
        let (signed, saved) =
            sign_then_change(prepared, &plan_task, &changed_task)
                .map_err(fail)?;

        let signed_side = collect_diff_lines(
            &saved["changes"],
            &[UNCHANGED_SIDE, REMOVED_SIDE],
        );

        prop_assert_eq!(signed_side, read_document_lines(&signed));
        Ok(())
    });
}

#[test]
fn test_build_workflow_view_property_shows_no_sealed_text_anywhere() {
    let cases = (step_task_strategy(), step_task_strategy());
    check_on_workspace(&cases, |prepared, (plan_task, changed_task)| {
        prop_assume!(plan_task != changed_task);
        let (signed, saved) =
            sign_then_change(prepared, &plan_task, &changed_task)
                .map_err(fail)?;
        let workflow_id = &saved["workflow"]["id"];
        let listed =
            find_workflow_view(prepared, workflow_id).map_err(fail)?;

        for view in [Some(signed), Some(saved), listed] {
            let view = view.unwrap_or_default();
            for shown_part in OPENED_VIEW_PARTS {
                let shown_text =
                    view.pointer(shown_part).map(Value::to_string);
                let shown_text = shown_text.unwrap_or_default();
                prop_assert!(!shown_text.is_empty(), "{}", shown_part);
                prop_assert!(
                    !shown_text.contains(SEALED_MARK),
                    "{}",
                    shown_text
                );
            }
        }
        Ok(())
    });
}

#[test]
fn test_build_workflow_view_property_agent_names_follow_the_document() {
    check_on_workspace(&step_task_strategy(), |prepared, plan_task| {
        let created =
            create_workflow(prepared, &plan_task, "build").map_err(fail)?;

        let mut document_names = Vec::new();
        for line in read_document_lines(&created) {
            if let Some(name) = line.strip_prefix(STEP_NAME_START) {
                document_names.push(json!(name));
            }
        }

        prop_assert_eq!(&created["agent_names"], &json!(document_names));
        prop_assert_eq!(&created["agent_names"], &json!(["plan", "build"]));
        Ok(())
    });
}

#[test]
fn test_build_workflow_view_property_runner_labels_never_pose_as_sealed() {
    let cases = (step_task_strategy(), SEALED_LOOKING_LABEL_PATTERN);
    check_on_workspace(&cases, |prepared, (plan_task, label)| {
        let mut command = two_step_workflow_command(
            &prepared.workspace_id,
            &plan_task,
            "build",
        );
        command["agents"][1]["runs_on"] =
            json!({ "kind": "runner_with_labels", "labels": [label] });
        let created = prepared.device.run(&command).map_err(fail)?;
        let workflow_id = created["workflow"]["id"].clone();
        let signed =
            run_on_workflow(&prepared.device, "sign_workflow", &workflow_id)
                .map_err(fail)?;
        let mut changed_workflow = signed["workflow"].clone();
        changed_workflow["agents"][0]["task"] = json!(format!("{plan_task}2"));

        let saved =
            save_workflow(prepared, &prepared.workspace_id, &changed_workflow)
                .map_err(fail)?;

        let label_line = format!("    requires: [\"{label}\"]");
        let unchanged_lines =
            collect_diff_lines(&saved["changes"], &[UNCHANGED_SIDE]);
        prop_assert!(unchanged_lines.contains(&label_line), "{}", label_line);
        let listed =
            find_workflow_view(prepared, &workflow_id).map_err(fail)?;
        prop_assert_eq!(listed, Some(saved));
        Ok(())
    });
}
