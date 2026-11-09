use std::sync::Arc;

use orchestration_api::catalog::ImproveSkillRequest;
use orchestration_api::work::RunEventsRequest;
use orchestration_core::identifiers::SkillId;
use orchestration_core::run::ChatAuthor;
use orchestration_runner::runner_server::RunnerServer;
use proptest::prelude::*;
use uuid::Uuid;

use crate::server_desk::{
    DETAILS_PATTERN, SERVER_CASES, chat_event, missing_claim_reason,
    server_desk, unknown_run,
};
use crate::support::test_device::{describe, fail};

const MOST_RUNS: usize = 3;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SERVER_CASES))]

    #[test]
    fn test_find_claimed_workspace_property_names_the_missing_run(
        numbers in prop::collection::vec(any::<u128>(), 1..4),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;

        for number in numbers {
            let run_id = unknown_run(number);
            let event = chat_event(ChatAuthor::Agent, "lost");
            let posted = desk.post(&runner, run_id, vec![event]);

            let reason = posted.map_err(|problem| problem.reason);
            prop_assert_eq!(reason, Err(missing_claim_reason(run_id)));
        }
    }

    #[test]
    fn test_find_claimed_workspace_property_guards_skill_proposals(
        number in any::<u128>(),
        skill_number in any::<u128>(),
        instructions in "\\PC{1,40}",
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let run_id = unknown_run(number);
        let proposal = ImproveSkillRequest {
            run_id,
            summary: "a summary".to_owned(),
            instructions,
        };
        let skill_id = SkillId(Uuid::from_u128(skill_number));

        let proposed =
            desk.wait(runner.propose_skill_improvement(skill_id, &proposal));

        let reason = proposed.map_err(|problem| problem.reason);
        prop_assert_eq!(reason, Err(missing_claim_reason(run_id)));
    }

    #[test]
    fn test_find_claimed_workspace_property_a_claim_opens_only_its_run(
        details in DETAILS_PATTERN,
        number in any::<u128>(),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&runner, &details).map_err(fail)?;
        let claimed_run = assignment.run.id;
        let other_run = unknown_run(number);
        prop_assume!(other_run != claimed_run);
        let event = chat_event(ChatAuthor::Agent, &details);

        let to_other = desk.post(&runner, other_run, vec![event.clone()]);
        let to_claimed = desk.post(&runner, claimed_run, vec![event]);

        let reason = to_other.map_err(|problem| problem.reason);
        prop_assert_eq!(reason, Err(missing_claim_reason(other_run)));
        prop_assert!(to_claimed.is_ok(), "{:?}", to_claimed);
    }

    #[test]
    fn test_lock_workspaces_property_parallel_posts_all_land(
        texts in prop::collection::vec(DETAILS_PATTERN, 1..=MOST_RUNS),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = Arc::new(desk.open_runner().map_err(fail)?);
        let mut run_ids = Vec::new();
        for text in &texts {
            let assignment =
                desk.claim_fresh_run(&runner, text).map_err(fail)?;
            run_ids.push(assignment.run.id);
        }

        let mut postings = Vec::new();
        for (run_id, text) in run_ids.iter().zip(&texts) {
            let posting_runner = Arc::clone(&runner);
            let run_id = *run_id;
            let request = RunEventsRequest {
                events: vec![chat_event(ChatAuthor::Agent, text)],
            };
            postings.push(desk.runtime.spawn(async move {
                posting_runner.post_run_events(run_id, &request).await
            }));
        }
        let mut outcomes = Vec::new();
        for posting in postings {
            outcomes.push(desk.wait(posting).map_err(describe));
        }

        for outcome in outcomes {
            prop_assert!(matches!(outcome, Ok(Ok(()))), "{:?}", outcome);
        }
    }

    #[test]
    fn test_lock_workspaces_property_a_refused_post_keeps_the_claims(
        details in DETAILS_PATTERN,
        number in any::<u128>(),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&runner, &details).map_err(fail)?;
        let unknown = unknown_run(number);
        prop_assume!(unknown != assignment.run.id);

        let refused = desk.post(&runner, unknown, Vec::new());
        let event = chat_event(ChatAuthor::Agent, &details);
        let accepted = desk.post(&runner, assignment.run.id, vec![event]);

        prop_assert!(refused.is_err());
        prop_assert!(accepted.is_ok(), "{:?}", accepted);
    }

    #[test]
    fn test_lock_workspaces_property_later_claims_keep_earlier_ones(
        texts in prop::collection::vec(DETAILS_PATTERN, 2..=MOST_RUNS),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let first =
            desk.claim_fresh_run(&runner, &texts[0]).map_err(fail)?;
        for text in &texts[1..] {
            desk.claim_fresh_run(&runner, text).map_err(fail)?;
        }

        let event = chat_event(ChatAuthor::Agent, &texts[0]);
        let posted = desk.post(&runner, first.run.id, vec![event]);

        prop_assert!(posted.is_ok(), "{:?}", posted);
    }
}
