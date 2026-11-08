use orchestration_api::catalog::ImproveSkillRequest;
use orchestration_core::identifiers::SkillId;
use orchestration_runner::runner_server::RunnerServer;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};
use uuid::Uuid;

use crate::support::command_builders::{
    create_skill_command, prepare_workspace,
};
use crate::support::runner_access::{
    ClaimedRun, claim_started_task, started_task_command,
};
use crate::support::test_device::{describe, fail, read_text};
use crate::work_desk::CheckOutcome;

const PROPOSAL_CASES: u32 = 3;
const LINE_PATTERN: &str = "[a-z][a-z ]{0,12}";
const MOST_LINES: usize = 5;
const SUMMARY_PATTERN: &str = "[0-9] lines? (added|removed)";

fn check_proposals<Cases, Check>(cases: &Cases, check: Check)
where
    Cases: Strategy,
    Check: Fn(&ClaimedRun, Cases::Value) -> CheckOutcome,
{
    let claimed = prepare_workspace().and_then(|prepared| {
        let command = started_task_command(&prepared, "Improve the notes");
        claim_started_task(prepared, &command)
    });
    let claimed = match claimed {
        Ok(claimed) => claimed,
        Err(message) => panic!("a run is claimed: {message}"),
    };
    let mut runner = TestRunner::new(Config::with_cases(PROPOSAL_CASES));
    let outcome = runner.run(cases, |value| check(&claimed, value));
    assert!(outcome.is_ok(), "{outcome:?}");
}

fn lines_text() -> impl Strategy<Value = Vec<String>> {
    vec(LINE_PATTERN, 1..=MOST_LINES)
}

fn create_asking_skill(
    claimed: &ClaimedRun,
    instructions: &str,
) -> Result<(String, String), String> {
    let prepared = &claimed.prepared;
    let mut command =
        create_skill_command(&prepared.workspace_id, instructions);
    let name = format!("skill-{}", Uuid::new_v4().simple());
    command["name"] = json!(name);
    command["improvement"] = json!("ask_me");
    let skill = prepared.device.run(&command)?;
    Ok((read_text(&skill, "/id")?, name))
}

fn propose(
    claimed: &ClaimedRun,
    skill_id: &str,
    summary: &str,
    instructions: &str,
) -> Result<(), String> {
    let skill_uuid = Uuid::parse_str(skill_id).map_err(describe)?;
    let request = ImproveSkillRequest {
        run_id: claimed.assignment.run.id,
        summary: summary.to_owned(),
        instructions: instructions.to_owned(),
    };
    let proposing = claimed
        .runner
        .propose_skill_improvement(SkillId(skill_uuid), &request);
    claimed.runtime.block_on(proposing).map_err(describe)
}

fn find_approval_view(
    claimed: &ClaimedRun,
    skill_id: &str,
) -> Result<Value, String> {
    let listed = claimed
        .prepared
        .device
        .run(&json!({ "command": "list_approvals" }))?;
    let views = listed["approvals"].as_array().cloned().unwrap_or_default();
    let wanted = json!(skill_id);
    views
        .into_iter()
        .find(|view| view["approval"]["action"]["skill_id"] == wanted)
        .ok_or_else(|| "the proposal is listed".to_owned())
}

fn collect_side(changes: &Value, kept_kind: &str) -> Vec<String> {
    let mut side = Vec::new();
    for change in changes.as_array().cloned().unwrap_or_default() {
        for kind in ["unchanged", kept_kind] {
            if let Some(text) = change[kind].as_str() {
                side.push(text.to_owned());
            }
        }
    }
    side
}

#[test]
fn test_open_improvement_proposal_property_the_proposal_opens_to_plaintext() {
    let cases = (lines_text(), "[a-z]{18,24}");
    check_proposals(&cases, |claimed, (proposed_lines, secret_word)| {
        let proposed = format!("{}\n{secret_word}", proposed_lines.join("\n"));
        let (skill_id, _) =
            create_asking_skill(claimed, "First version").map_err(fail)?;

        propose(claimed, &skill_id, "1 line added", &proposed)
            .map_err(fail)?;

        let view = find_approval_view(claimed, &skill_id).map_err(fail)?;
        let action = &view["approval"]["action"];
        prop_assert_eq!(&action["proposed_instructions"], &json!(proposed));
        let stored =
            claimed.prepared.server.read_stored_state().map_err(fail)?;
        prop_assert!(!stored.contains(&secret_word));
        Ok(())
    });
}

#[test]
fn test_open_improvement_proposal_property_keeps_every_other_field() {
    let cases = (lines_text(), SUMMARY_PATTERN);
    check_proposals(&cases, |claimed, (proposed_lines, summary)| {
        let (skill_id, _) =
            create_asking_skill(claimed, "First version").map_err(fail)?;

        propose(claimed, &skill_id, &summary, &proposed_lines.join("\n"))
            .map_err(fail)?;

        let first = find_approval_view(claimed, &skill_id).map_err(fail)?;
        let second = find_approval_view(claimed, &skill_id).map_err(fail)?;
        let approval = &first["approval"];
        prop_assert_eq!(&approval["action"]["kind"], "improve_skill");
        prop_assert_eq!(&approval["action"]["summary"], &json!(summary));
        let run_id = claimed.assignment.run.id.0.to_string();
        prop_assert_eq!(&approval["run_id"], &json!(run_id));
        prop_assert_eq!(&approval["decision"], &Value::Null);
        prop_assert_eq!(&first["is_waiting"], true);
        prop_assert_eq!(&first, &second);
        Ok(())
    });
}

#[test]
fn test_open_improvement_proposal_property_other_approvals_pass_unchanged() {
    check_proposals(&"[a-z]{3,10}", |claimed, target| {
        let action = json!({ "kind": "deploy", "target": target });
        let created = claimed
            .prepared
            .device
            .run(&json!({
                "command": "create_approval",
                "run_id": null,
                "action": action,
            }))
            .map_err(fail)?;

        let listed = claimed
            .prepared
            .device
            .run(&json!({ "command": "list_approvals" }))
            .map_err(fail)?;

        let views =
            listed["approvals"].as_array().cloned().unwrap_or_default();
        let view = views
            .iter()
            .find(|view| view["approval"]["id"] == created["id"])
            .ok_or_else(|| fail("the approval is listed"))?;
        prop_assert_eq!(&view["approval"], &created);
        prop_assert_eq!(&view["skill_change"], &Value::Null);
        Ok(())
    });
}

#[test]
fn test_describe_skill_change_property_the_diff_rebuilds_both_versions() {
    let cases = (lines_text(), lines_text());
    check_proposals(&cases, |claimed, (current_lines, proposed_lines)| {
        let current = current_lines.join("\n");
        let (skill_id, name) =
            create_asking_skill(claimed, &current).map_err(fail)?;

        propose(claimed, &skill_id, "changed", &proposed_lines.join("\n"))
            .map_err(fail)?;

        let view = find_approval_view(claimed, &skill_id).map_err(fail)?;
        let skill_change = &view["skill_change"];
        prop_assert_eq!(&skill_change["skill_name"], &json!(name));
        let changes = &skill_change["changes"];
        prop_assert_eq!(collect_side(changes, "removed"), current_lines);
        prop_assert_eq!(collect_side(changes, "added"), proposed_lines);
        Ok(())
    });
}

#[test]
fn test_describe_skill_change_property_the_same_text_changes_nothing() {
    check_proposals(&lines_text(), |claimed, lines| {
        let text = lines.join("\n");
        let (skill_id, _) =
            create_asking_skill(claimed, &text).map_err(fail)?;

        propose(claimed, &skill_id, "no change", &text).map_err(fail)?;

        let view = find_approval_view(claimed, &skill_id).map_err(fail)?;
        let mut expected = Vec::new();
        for line in &lines {
            expected.push(json!({ "unchanged": line }));
        }
        prop_assert_eq!(&view["skill_change"]["changes"], &json!(expected));
        Ok(())
    });
}

#[test]
fn test_describe_skill_change_property_a_deleted_skill_shows_no_change() {
    check_proposals(&lines_text(), |claimed, proposed_lines| {
        let (skill_id, _) =
            create_asking_skill(claimed, "First version").map_err(fail)?;
        propose(claimed, &skill_id, "changed", &proposed_lines.join("\n"))
            .map_err(fail)?;

        claimed
            .prepared
            .device
            .run(&json!({ "command": "delete_skill", "skill_id": skill_id }))
            .map_err(fail)?;

        let view = find_approval_view(claimed, &skill_id).map_err(fail)?;
        prop_assert_eq!(&view["skill_change"], &Value::Null);
        let proposed = &view["approval"]["action"]["proposed_instructions"];
        prop_assert_eq!(proposed, &json!(proposed_lines.join("\n")));
        Ok(())
    });
}
