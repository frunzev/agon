use orchestration_api::catalog::ImproveSkillRequest;
use orchestration_api::work::CreateApprovalRequest;
use orchestration_core::approval::{ApprovalAction, ApprovalRequest};
use orchestration_core::library::SkillImprovement;
use proptest::prelude::*;

use crate::skill_improvement_fixtures::{
    ImprovableSkill, PROPOSAL_SUMMARY, improvement_path,
};
use crate::test_client::{TestResponse, TestServer};

pub const SUMMARY_PATTERN: &str = "[0-9] lines? (added|removed)";
pub const PLAIN_INSTRUCTIONS_PATTERN: &str = "[A-Za-z][A-Za-z0-9 .,\n]{0,40}";
pub const SEALED_HEX_PATTERN: &str = "([0-9a-f]{2}){1,24}";
pub const SEALED_TEXT_PREFIX: &str = "sealed-v1:";
pub const APPROVALS_PATH: &str = "/approvals";
pub const SKILL_PROPOSAL_REFUSAL: &str =
    "a skill improvement is proposed through its skill, not as an approval";
pub const UNSEALED_REFUSAL: &str = "the proposed instructions are not sealed";

pub fn proposed_instructions() -> impl Strategy<Value = String> {
    prop_oneof![
        PLAIN_INSTRUCTIONS_PATTERN.prop_map(String::from),
        SEALED_HEX_PATTERN
            .prop_map(|hex| format!("{SEALED_TEXT_PREFIX}{hex}")),
    ]
}

pub fn asking_or_automatic() -> impl Strategy<Value = SkillImprovement> {
    prop_oneof![Just(SkillImprovement::AskMe), Just(SkillImprovement::Auto)]
}

pub fn skill_proposal_request(
    improvable: &ImprovableSkill,
    summary: &str,
    instructions: &str,
) -> CreateApprovalRequest {
    CreateApprovalRequest {
        run_id: Some(improvable.claimed.run.id),
        action: ApprovalAction::ImproveSkill {
            skill_id: improvable.skill.id,
            summary: summary.to_owned(),
            proposed_instructions: instructions.to_owned(),
        },
    }
}

pub async fn ask_for_approval(
    test: &TestServer,
    improvable: &ImprovableSkill,
    request: &CreateApprovalRequest,
) -> TestResponse {
    let runner = &improvable.claimed.holder;
    test.post(runner, APPROVALS_PATH, request).await
}

pub async fn propose_instructions(
    test: &TestServer,
    improvable: &ImprovableSkill,
    instructions: &str,
) -> TestResponse {
    let request = ImproveSkillRequest {
        run_id: improvable.claimed.run.id,
        summary: PROPOSAL_SUMMARY.to_owned(),
        instructions: instructions.to_owned(),
    };
    let path = improvement_path(&improvable.skill);
    test.post(&improvable.claimed.holder, &path, &request).await
}

pub async fn list_every_approval(
    test: &TestServer,
    improvable: &ImprovableSkill,
) -> (Vec<ApprovalRequest>, Vec<ApprovalRequest>) {
    let owner = &improvable.claimed.account.owner;
    let runner = &improvable.claimed.holder;
    let to_owner = test.get(owner, APPROVALS_PATH).await.json();
    let to_runner = test.get(runner, APPROVALS_PATH).await.json();
    (to_owner, to_runner)
}
