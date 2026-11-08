use axum::http::StatusCode;
use orchestration_core::approval::ApprovalAction;
use proptest::prelude::*;

use crate::skill_improvement_fixtures::{start_with_skill, stored_skill};
use crate::skill_proposal_desk::{
    PLAIN_INSTRUCTIONS_PATTERN, SEALED_HEX_PATTERN, SEALED_TEXT_PREFIX,
    UNSEALED_REFUSAL, asking_or_automatic, list_every_approval,
    propose_instructions,
};
use crate::test_client::{TestServer, block_on};

const IMPROVEMENT_CASES: u32 = 6;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(IMPROVEMENT_CASES))]

    #[test]
    fn test_take_improvement_property_plain_instructions_are_refused(
        improvement in asking_or_automatic(),
        instructions in PLAIN_INSTRUCTIONS_PATTERN,
    ) {
        let test = TestServer::start();

        let response = block_on(async {
            let improvable = start_with_skill(&test, improvement).await;
            propose_instructions(&test, &improvable, &instructions).await
        });

        prop_assert_eq!(response.status, StatusCode::UNPROCESSABLE_ENTITY);
        prop_assert_eq!(response.error_message(), UNSEALED_REFUSAL);
    }

    #[test]
    fn test_take_improvement_property_a_refused_proposal_changes_nothing(
        improvement in asking_or_automatic(),
        instructions in PLAIN_INSTRUCTIONS_PATTERN,
    ) {
        let test = TestServer::start();

        let (skill_before, skill_after, listed) = block_on(async {
            let improvable = start_with_skill(&test, improvement).await;
            let skill_before = stored_skill(&test, &improvable).await;
            propose_instructions(&test, &improvable, &instructions).await;
            let skill_after = stored_skill(&test, &improvable).await;
            let listed = list_every_approval(&test, &improvable).await;
            (skill_before, skill_after, listed)
        });

        prop_assert_eq!(skill_after, skill_before);
        prop_assert_eq!(listed, (Vec::new(), Vec::new()));
    }

    #[test]
    fn test_take_improvement_property_sealed_instructions_are_taken(
        improvement in asking_or_automatic(),
        sealed_hex in SEALED_HEX_PATTERN,
    ) {
        let test = TestServer::start();
        let sealed = format!("{SEALED_TEXT_PREFIX}{sealed_hex}");

        let (response, skill_after, listed) = block_on(async {
            let improvable = start_with_skill(&test, improvement).await;
            let response =
                propose_instructions(&test, &improvable, &sealed).await;
            let skill_after = stored_skill(&test, &improvable).await;
            let listed = list_every_approval(&test, &improvable).await;
            (response, skill_after, listed)
        });

        prop_assert_eq!(response.status, StatusCode::NO_CONTENT);
        let (to_owner, _to_runner) = listed;
        let proposed: Vec<&ApprovalAction> = to_owner
            .iter()
            .map(|approval| &approval.action)
            .collect();
        let is_saved = skill_after.instructions == sealed;
        let is_asked = proposed.iter().any(|action| matches!(
            action,
            ApprovalAction::ImproveSkill { proposed_instructions, .. }
                if *proposed_instructions == sealed
        ));
        prop_assert!(is_saved != is_asked, "{:?} {:?}", skill_after, proposed);
    }
}
