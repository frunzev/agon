use orchestration_api::catalog::ImproveSkillRequest;
use orchestration_core::identifiers::SkillId;
use orchestration_runner::runner_server::RunnerServer;
use orchestration_security::sealing::{WorkspaceKey, seal_text};
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
use crate::support::server_access::use_server_at;
use crate::support::test_device::{describe, read_text};

pub const LISTING_CASES: u32 = 3;
pub const FIRST_INSTRUCTIONS: &str = "First version";
pub const SUMMARY: &str = "1 line added";
const LINE_PATTERN: &str = "[a-z][a-z ]{0,12}";
const GARBAGE_HEX_PATTERN: &str = "([0-9a-f]{2}){0,40}";
const SEALED_TEXT_PREFIX: &str = "sealed-v1:";
const TASK_DETAILS: &str = "Improve the notes";

#[derive(Clone, Debug)]
pub enum UnreadableText {
    SealedWithForeignKey(String),
    GarbageCiphertext(String),
}

pub type ListingCheck = Result<(), TestCaseError>;

pub fn unreadable_texts() -> impl Strategy<Value = UnreadableText> {
    prop_oneof![
        LINE_PATTERN.prop_map(UnreadableText::SealedWithForeignKey),
        GARBAGE_HEX_PATTERN.prop_map(UnreadableText::GarbageCiphertext),
    ]
}

pub fn proposed_lines() -> impl Strategy<Value = String> {
    proptest::collection::vec(LINE_PATTERN, 1..=4)
        .prop_map(|lines| lines.join("\n"))
}

pub fn seal_unreadably(unreadable: &UnreadableText) -> Result<String, String> {
    match unreadable {
        UnreadableText::SealedWithForeignKey(plain_text) => {
            let foreign_key = WorkspaceKey::generate().map_err(describe)?;
            seal_text(&foreign_key, plain_text).map_err(describe)
        }
        UnreadableText::GarbageCiphertext(hex) => {
            Ok(format!("{SEALED_TEXT_PREFIX}{hex}"))
        }
    }
}

pub fn check_listings<Cases, Check>(cases: &Cases, check: Check)
where
    Cases: Strategy,
    Check: Fn(&ClaimedRun, Cases::Value) -> ListingCheck,
{
    let claimed = prepare_workspace().and_then(|prepared| {
        let command = started_task_command(&prepared, TASK_DETAILS);
        claim_started_task(prepared, &command)
    });
    let claimed = match claimed {
        Ok(claimed) => claimed,
        Err(message) => panic!("a run is claimed: {message}"),
    };
    let mut runner = TestRunner::new(Config::with_cases(LISTING_CASES));
    let outcome = runner.run(cases, |value| check(&claimed, value));
    assert!(outcome.is_ok(), "{outcome:?}");
}

pub fn create_asking_skill(
    claimed: &ClaimedRun,
) -> Result<(String, String), String> {
    let prepared = &claimed.prepared;
    let mut command =
        create_skill_command(&prepared.workspace_id, FIRST_INSTRUCTIONS);
    let name = format!("skill-{}", Uuid::new_v4().simple());
    command["name"] = json!(name);
    command["improvement"] = json!("ask_me");
    let skill = prepared.device.run(&command)?;
    Ok((read_text(&skill, "/id")?, name))
}

fn improvement_request(
    claimed: &ClaimedRun,
    instructions: &str,
) -> ImproveSkillRequest {
    ImproveSkillRequest {
        run_id: claimed.assignment.run.id,
        summary: SUMMARY.to_owned(),
        instructions: instructions.to_owned(),
    }
}

pub fn propose_readably(
    claimed: &ClaimedRun,
    skill_id: &str,
    instructions: &str,
) -> Result<(), String> {
    let skill_uuid = Uuid::parse_str(skill_id).map_err(describe)?;
    let request = improvement_request(claimed, instructions);
    let proposing = claimed
        .runner
        .propose_skill_improvement(SkillId(skill_uuid), &request);
    claimed.runtime.block_on(proposing).map_err(describe)
}

pub fn post_unreadable_proposal(
    claimed: &ClaimedRun,
    skill_id: &str,
    sealed_text: &str,
) -> Result<(), String> {
    let skill_uuid = Uuid::parse_str(skill_id).map_err(describe)?;
    let request = improvement_request(claimed, sealed_text);
    let identity = claimed.prepared.device.load_identity()?;
    use_server_at(&claimed.prepared.server.address, async |server| {
        let client = server.signed(&identity);
        client.improve_skill(SkillId(skill_uuid), &request).await
    })
}

pub fn list_approvals(claimed: &ClaimedRun) -> Result<Value, String> {
    let device = &claimed.prepared.device;
    device.run(&json!({ "command": "list_approvals" }))
}

pub fn find_views_of_skill(listing: &Value, skill_id: &str) -> Vec<Value> {
    let views = listing["approvals"].as_array().cloned().unwrap_or_default();
    let wanted = json!(skill_id);
    let mut found = Vec::new();
    for view in views {
        if view["approval"]["action"]["skill_id"] == wanted {
            found.push(view);
        }
    }
    found
}

pub fn count_waiting_views(listing: &Value) -> usize {
    let views = listing["approvals"].as_array().cloned().unwrap_or_default();
    let mut waiting = 0;
    for view in views {
        if view["is_waiting"] == json!(true) {
            waiting += 1;
        }
    }
    waiting
}
