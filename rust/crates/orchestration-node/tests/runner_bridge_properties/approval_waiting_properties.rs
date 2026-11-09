use std::thread;
use std::time::Duration;

use orchestration_core::approval::ApprovalDecision;
use proptest::prelude::*;

use crate::approval_desk::open_approval_desk;
use crate::approval_forging_server::ApprovalForgery;
use crate::support::test_device::fail;

const APPROVAL_CASES: u32 = 1;
const UNDECIDED_WAIT: Duration = Duration::from_millis(2_500);
const QUIET_WAIT: Duration = Duration::from_millis(2_500);
const BRANCH_PATTERN: &str = "agent/[a-z]{1,10}";
const UNTRUSTED_START: &str = "the approval decision cannot be trusted";
const NO_TRUSTED_DEVICE: &str = "no trusted client device";
const NO_LONGER_MATCHES: &str = "no longer matches";
const NOT_FOUND_WORD: &str = "approval";

fn decision_strategy()
-> impl Strategy<Value = (&'static str, ApprovalDecision)> {
    prop::sample::select(vec![
        ("approved", ApprovalDecision::Approved),
        ("denied", ApprovalDecision::Denied),
    ])
}

fn refusal_of(
    forgery: ApprovalForgery,
    branch: &str,
) -> Result<String, TestCaseError> {
    let desk = open_approval_desk().map_err(fail)?;
    desk.server.forge(forgery);
    let waiting = desk.start_waiting(desk.push_request(branch));
    let approval_id = desk.wait_for_branch_approval(branch).map_err(fail)?;
    desk.decide(&approval_id, "approved").map_err(fail)?;

    let finished = desk.finish_waiting(waiting).map_err(fail)?;

    match finished {
        Ok(decision) => Err(fail(format!("trusted {decision:?}"))),
        Err(problem) => Ok(problem.reason),
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(APPROVAL_CASES))]

    #[test]
    fn test_wait_for_decision_property_returns_the_clients_decision(
        branch in BRANCH_PATTERN,
        (decision_name, decision) in decision_strategy(),
    ) {
        let desk = open_approval_desk().map_err(fail)?;
        let waiting = desk.start_waiting(desk.push_request(&branch));
        let approval_id =
            desk.wait_for_branch_approval(&branch).map_err(fail)?;

        desk.decide(&approval_id, decision_name).map_err(fail)?;
        let finished = desk.finish_waiting(waiting).map_err(fail)?;

        prop_assert_eq!(finished.map_err(fail)?, decision);
    }

    #[test]
    fn test_wait_for_decision_property_waits_while_undecided(
        branch in BRANCH_PATTERN,
    ) {
        let desk = open_approval_desk().map_err(fail)?;
        let waiting = desk.start_waiting(desk.push_request(&branch));
        desk.wait_for_branch_approval(&branch).map_err(fail)?;

        thread::sleep(UNDECIDED_WAIT);

        prop_assert!(!waiting.is_finished());
        waiting.abort();
    }

    #[test]
    fn test_wait_for_decision_property_stops_asking_once_dropped(
        branch in BRANCH_PATTERN,
    ) {
        let desk = open_approval_desk().map_err(fail)?;
        let waiting = desk.start_waiting(desk.push_request(&branch));
        desk.wait_for_branch_approval(&branch).map_err(fail)?;

        waiting.abort();
        let _ended = desk.runtime.block_on(waiting);
        let listings_after_stop = desk.server.count_listings();
        thread::sleep(QUIET_WAIT);

        prop_assert_eq!(desk.server.count_listings(), listings_after_stop);
    }

    #[test]
    fn test_wait_for_decision_property_a_changed_action_is_refused(
        branch in BRANCH_PATTERN,
    ) {
        let reason = refusal_of(ApprovalForgery::ChangedAction, &branch)?;

        prop_assert!(reason.contains(NO_LONGER_MATCHES), "{}", reason);
    }

    #[test]
    fn test_read_approval_property_each_wait_gets_its_own_decision(
        first_branch in BRANCH_PATTERN,
        second_branch in BRANCH_PATTERN,
    ) {
        prop_assume!(first_branch != second_branch);
        let desk = open_approval_desk().map_err(fail)?;
        let first = desk.start_waiting(desk.push_request(&first_branch));
        let second = desk.start_waiting(desk.push_request(&second_branch));
        let first_id =
            desk.wait_for_branch_approval(&first_branch).map_err(fail)?;
        let second_id =
            desk.wait_for_branch_approval(&second_branch).map_err(fail)?;

        desk.decide(&second_id, "denied").map_err(fail)?;
        desk.decide(&first_id, "approved").map_err(fail)?;
        let first_decision = desk.finish_waiting(first).map_err(fail)?;
        let second_decision = desk.finish_waiting(second).map_err(fail)?;

        let first_decision = first_decision.map_err(fail)?;
        let second_decision = second_decision.map_err(fail)?;
        prop_assert_eq!(first_decision, ApprovalDecision::Approved);
        prop_assert_eq!(second_decision, ApprovalDecision::Denied);
    }

    #[test]
    fn test_read_approval_property_another_decision_never_answers(
        first_branch in BRANCH_PATTERN,
        second_branch in BRANCH_PATTERN,
    ) {
        prop_assume!(first_branch != second_branch);
        let desk = open_approval_desk().map_err(fail)?;
        let first = desk.start_waiting(desk.push_request(&first_branch));
        let second = desk.start_waiting(desk.push_request(&second_branch));
        desk.wait_for_branch_approval(&first_branch).map_err(fail)?;
        let second_id =
            desk.wait_for_branch_approval(&second_branch).map_err(fail)?;

        desk.decide(&second_id, "approved").map_err(fail)?;
        let second_decision = desk.finish_waiting(second).map_err(fail)?;
        thread::sleep(UNDECIDED_WAIT);

        let second_decision = second_decision.map_err(fail)?;
        prop_assert_eq!(second_decision, ApprovalDecision::Approved);
        prop_assert!(!first.is_finished());
        first.abort();
    }

    #[test]
    fn test_read_approval_property_a_vanished_approval_ends_the_wait(
        branch in BRANCH_PATTERN,
    ) {
        let desk = open_approval_desk().map_err(fail)?;
        let waiting = desk.start_waiting(desk.push_request(&branch));
        desk.wait_for_branch_approval(&branch).map_err(fail)?;

        desk.server.forge(ApprovalForgery::RemovedApproval);
        let finished = desk.finish_waiting(waiting).map_err(fail)?;

        let Err(problem) = finished else {
            return Err(fail(format!("{finished:?}")));
        };
        prop_assert!(problem.reason.contains(NOT_FOUND_WORD), "{}", problem);
    }

    #[test]
    fn test_verify_trusted_decision_property_a_flipped_decision_fails(
        branch in BRANCH_PATTERN,
    ) {
        let reason = refusal_of(ApprovalForgery::FlippedDecision, &branch)?;

        prop_assert!(reason.starts_with(UNTRUSTED_START), "{}", reason);
    }

    #[test]
    fn test_verify_trusted_decision_property_a_foreign_decider_fails(
        branch in BRANCH_PATTERN,
    ) {
        let reason = refusal_of(ApprovalForgery::ForeignDecider, &branch)?;

        prop_assert!(reason.starts_with(UNTRUSTED_START), "{}", reason);
        prop_assert!(reason.contains(NO_TRUSTED_DEVICE), "{}", reason);
    }

    #[test]
    fn test_verify_trusted_decision_property_a_changed_signature_fails(
        branch in BRANCH_PATTERN,
    ) {
        let reason = refusal_of(ApprovalForgery::ChangedSignature, &branch)?;

        prop_assert!(reason.starts_with(UNTRUSTED_START), "{}", reason);
    }
}
