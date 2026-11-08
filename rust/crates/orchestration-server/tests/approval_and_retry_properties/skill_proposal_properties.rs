use axum::http::StatusCode;
use orchestration_api::work::CreateApprovalRequest;
use orchestration_core::approval::ApprovalAction;
use orchestration_core::library::SkillImprovement;
use proptest::prelude::*;

use crate::skill_improvement_fixtures::{start_with_skill, stored_skill};
use crate::skill_proposal_desk::{
    SKILL_PROPOSAL_REFUSAL, SUMMARY_PATTERN, ask_for_approval,
    list_every_approval, proposed_instructions, skill_proposal_request,
};
use crate::test_client::{TestServer, block_on};

const PROPOSAL_CASES: u32 = 6;
const DEPLOY_TARGET_PATTERN: &str = "[a-z][a-z0-9-]{0,12}";

fn any_improvement() -> impl Strategy<Value = SkillImprovement> {
    prop_oneof![
        Just(SkillImprovement::Never),
        Just(SkillImprovement::AskMe),
        Just(SkillImprovement::Auto),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROPOSAL_CASES))]

    #[test]
    fn test_create_approval_property_a_skill_proposal_is_refused(
        improvement in any_improvement(),
        summary in SUMMARY_PATTERN,
        instructions in proposed_instructions(),
    ) {
        let test = TestServer::start();

        let response = block_on(async {
            let improvable = start_with_skill(&test, improvement).await;
            let request =
                skill_proposal_request(&improvable, &summary, &instructions);
            ask_for_approval(&test, &improvable, &request).await
        });

        prop_assert_eq!(response.status, StatusCode::FORBIDDEN);
        prop_assert_eq!(response.error_message(), SKILL_PROPOSAL_REFUSAL);
    }

    #[test]
    fn test_create_approval_property_a_refused_proposal_changes_nothing(
        improvement in any_improvement(),
        summary in SUMMARY_PATTERN,
        instructions in proposed_instructions(),
    ) {
        let test = TestServer::start();

        let (listed, skill_before, skill_after) = block_on(async {
            let improvable = start_with_skill(&test, improvement).await;
            let skill_before = stored_skill(&test, &improvable).await;
            let request =
                skill_proposal_request(&improvable, &summary, &instructions);
            ask_for_approval(&test, &improvable, &request).await;
            let listed = list_every_approval(&test, &improvable).await;
            let skill_after = stored_skill(&test, &improvable).await;
            (listed, skill_before, skill_after)
        });

        prop_assert_eq!(listed, (Vec::new(), Vec::new()));
        prop_assert_eq!(skill_after, skill_before);
    }

    #[test]
    fn test_create_approval_property_other_actions_are_still_opened(
        target in DEPLOY_TARGET_PATTERN,
        summary in SUMMARY_PATTERN,
        instructions in proposed_instructions(),
    ) {
        let test = TestServer::start();

        let (refused, opened, listed) = block_on(async {
            let improvable =
                start_with_skill(&test, SkillImprovement::AskMe).await;
            let proposal =
                skill_proposal_request(&improvable, &summary, &instructions);
            let refused =
                ask_for_approval(&test, &improvable, &proposal).await;
            let deploy = CreateApprovalRequest {
                run_id: Some(improvable.claimed.run.id),
                action: ApprovalAction::Deploy { target: target.clone() },
            };
            let opened = ask_for_approval(&test, &improvable, &deploy).await;
            let listed = list_every_approval(&test, &improvable).await;
            (refused, opened, listed)
        });

        prop_assert_eq!(refused.status, StatusCode::FORBIDDEN);
        prop_assert_eq!(opened.status, StatusCode::CREATED);
        let (to_owner, to_runner) = listed;
        prop_assert_eq!(&to_owner, &to_runner);
        let [only_approval] = to_owner.as_slice() else {
            return Err(TestCaseError::fail("one approval is listed"));
        };
        prop_assert_eq!(
            &only_approval.action,
            &ApprovalAction::Deploy { target }
        );
    }
}
