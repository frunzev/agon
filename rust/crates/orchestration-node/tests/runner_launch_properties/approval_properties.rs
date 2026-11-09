use orchestration_api::work::CreateApprovalRequest;
use orchestration_core::approval::{ApprovalAction, ApprovalDecision};
use orchestration_runner::runner_server::RunnerServer;
use proptest::prelude::*;

use crate::approval_desk::{ApprovalDesk, open_approval_desk};
use crate::server_desk::{NO_ACCOUNT, open_accountless_runner, unknown_run};
use crate::support::runner_access::test_runtime;
use crate::support::test_device::fail;

const APPROVAL_CASES: u32 = 1;
const APPROVED: &str = "approved";
const DENIED: &str = "denied";
const REPOSITORY: &str = "github.com/acme/app";

type DecisionChoice = (&'static str, ApprovalDecision);

fn decision_strategy() -> impl Strategy<Value = DecisionChoice> {
    prop_oneof![
        Just((APPROVED, ApprovalDecision::Approved)),
        Just((DENIED, ApprovalDecision::Denied)),
    ]
}

fn decide_branch(
    desk: &ApprovalDesk,
    branch: &str,
    decision: &str,
) -> Result<(), String> {
    let approval_id = desk.wait_for_branch_approval(branch)?;
    desk.decide(&approval_id, decision)?;
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(APPROVAL_CASES))]

    #[test]
    fn test_request_approval_decision_property_returns_the_choice_made(
        (decision_text, decision) in decision_strategy(),
        branch in "feature/[a-z]{1,10}",
    ) {
        let desk = open_approval_desk().map_err(fail)?;
        let waiting = desk.start_waiting(desk.push_request(&branch));

        decide_branch(&desk, &branch, decision_text).map_err(fail)?;
        let finished = desk.finish_waiting(waiting).map_err(fail)?;

        let decided = finished.map_err(|problem| problem.reason);
        prop_assert_eq!(decided, Ok(decision));
    }

    #[test]
    fn test_request_approval_decision_property_each_request_hears_its_own(
        (first_text, first) in decision_strategy(),
        (second_text, second) in decision_strategy(),
    ) {
        let desk = open_approval_desk().map_err(fail)?;
        let first_wait = desk.start_waiting(desk.push_request("first/one"));
        let second_wait =
            desk.start_waiting(desk.push_request("second/one"));

        decide_branch(&desk, "second/one", second_text).map_err(fail)?;
        decide_branch(&desk, "first/one", first_text).map_err(fail)?;
        let first_finished = desk.finish_waiting(first_wait).map_err(fail)?;
        let second_finished =
            desk.finish_waiting(second_wait).map_err(fail)?;

        let first_decided = first_finished.map_err(|problem| problem.reason);
        let second_decided =
            second_finished.map_err(|problem| problem.reason);
        prop_assert_eq!(first_decided, Ok(first));
        prop_assert_eq!(second_decided, Ok(second));
    }

    #[test]
    fn test_request_approval_decision_property_needs_an_account(
        branch in "feature/[a-z]{1,10}",
        number in any::<u128>(),
    ) {
        let (_device, runner) = open_accountless_runner().map_err(fail)?;
        let runtime = test_runtime().map_err(fail)?;
        let request = CreateApprovalRequest {
            run_id: Some(unknown_run(number)),
            action: ApprovalAction::PushCommits {
                repository: REPOSITORY.to_owned(),
                branch: branch.clone(),
                commits: vec![branch],
            },
        };

        let decided =
            runtime.block_on(runner.request_approval_decision(&request));

        let reason = decided.map_err(|problem| problem.reason);
        prop_assert_eq!(reason, Err(NO_ACCOUNT.to_owned()));
    }
}
