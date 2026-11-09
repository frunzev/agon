use std::collections::BTreeSet;

use orchestration_core::run::ChatAuthor;
use orchestration_node::runner_bridge::NodeRunnerServer;
use orchestration_runner::runner_server::RunnerServer;
use proptest::prelude::*;

use crate::server_desk::{
    DETAILS_PATTERN, NO_ACCOUNT, SERVER_CASES, ServerDesk, chat_event,
    missing_claim_reason, open_accountless_runner, server_desk, unknown_run,
};
use crate::support::runner_access::sample_heartbeat;
use crate::support::test_device::{describe, fail};

const MOST_RUNS: usize = 3;

fn claim_once(
    desk: &ServerDesk,
    runner: &NodeRunnerServer,
) -> Result<Option<String>, String> {
    let heartbeat = sample_heartbeat();
    desk.wait(runner.send_heartbeat(&heartbeat))
        .map_err(describe)?;
    let response = desk.wait(runner.claim_next_run()).map_err(describe)?;
    let assignment = response.assignment;
    Ok(assignment.map(|claimed| claimed.task.details))
}

fn claim_until_empty(
    desk: &ServerDesk,
    runner: &NodeRunnerServer,
) -> Result<Vec<String>, String> {
    let mut claimed_details = Vec::new();
    while let Some(details) = claim_once(desk, runner)? {
        claimed_details.push(details);
    }
    Ok(claimed_details)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SERVER_CASES))]

    #[test]
    fn test_node_runner_server_new_property_starts_with_no_claims(
        number in any::<u128>(),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let run_id = unknown_run(number);

        let posted = desk.post(&runner, run_id, Vec::new());

        let reason = posted.map_err(|problem| problem.reason);
        prop_assert_eq!(reason, Err(missing_claim_reason(run_id)));
    }

    #[test]
    fn test_node_runner_server_new_property_servers_never_share_claims(
        details in DETAILS_PATTERN,
    ) {
        let desk = server_desk().map_err(fail)?;
        let claiming = desk.open_runner().map_err(fail)?;
        let stranger = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&claiming, &details).map_err(fail)?;
        let run_id = assignment.run.id;
        let event = chat_event(ChatAuthor::Agent, &details);

        let by_stranger = desk.post(&stranger, run_id, vec![event.clone()]);
        let by_claimant = desk.post(&claiming, run_id, vec![event]);

        let reason = by_stranger.map_err(|problem| problem.reason);
        prop_assert_eq!(reason, Err(missing_claim_reason(run_id)));
        prop_assert!(by_claimant.is_ok(), "{:?}", by_claimant);
    }

    #[test]
    fn test_node_runner_server_new_property_reads_need_no_claim(
        details in DETAILS_PATTERN,
    ) {
        let desk = server_desk().map_err(fail)?;
        let claiming = desk.open_runner().map_err(fail)?;
        let reader = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&claiming, &details).map_err(fail)?;
        let run_id = assignment.run.id;

        let stopped = desk.wait(reader.is_run_stopped(run_id));
        let messages = desk.wait(reader.read_user_messages(run_id));

        prop_assert_eq!(stopped.ok(), Some(false));
        prop_assert_eq!(messages.ok(), Some(Vec::new()));
    }

    #[test]
    fn test_claim_property_opens_the_sealed_task_details(
        details in DETAILS_PATTERN,
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;

        let assignment =
            desk.claim_fresh_run(&runner, &details).map_err(fail)?;

        prop_assert_eq!(assignment.task.details, details);
        let workspace_text = assignment.workspace_id.0.to_string();
        prop_assert_eq!(workspace_text, desk.prepared.workspace_id.clone());
    }

    #[test]
    fn test_claim_property_an_empty_queue_gives_nothing_again_and_again(
        repeat_count in 1_usize..4,
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let _turn = desk.take_claim_turn();
        claim_until_empty(desk, &runner).map_err(fail)?;

        for _ in 0..repeat_count {
            prop_assert_eq!(claim_once(desk, &runner).map_err(fail)?, None);
        }
    }

    #[test]
    fn test_claim_property_remembers_the_workspace_of_each_claim(
        texts in prop::collection::vec(DETAILS_PATTERN, 1..=MOST_RUNS),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let mut run_ids = Vec::new();
        for text in &texts {
            let assignment =
                desk.claim_fresh_run(&runner, text).map_err(fail)?;
            run_ids.push(assignment.run.id);
        }

        for (run_id, text) in run_ids.iter().zip(&texts) {
            let event = chat_event(ChatAuthor::Agent, text);
            let posted = desk.post(&runner, *run_id, vec![event]);
            prop_assert!(posted.is_ok(), "{:?}", posted);
        }
    }

    #[test]
    fn test_claim_next_run_property_each_started_run_is_given_once(
        texts in prop::collection::vec(DETAILS_PATTERN, 1..=MOST_RUNS),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let _turn = desk.take_claim_turn();
        claim_until_empty(desk, &runner).map_err(fail)?;
        for text in &texts {
            desk.start_task(text).map_err(fail)?;
        }

        let claimed = claim_until_empty(desk, &runner).map_err(fail)?;

        let claimed_set: BTreeSet<String> = claimed.iter().cloned().collect();
        let started_set: BTreeSet<String> = texts.iter().cloned().collect();
        prop_assert_eq!(claimed.len(), texts.len());
        prop_assert_eq!(claimed_set, started_set);
    }

    #[test]
    fn test_claim_next_run_property_a_device_without_account_is_refused(
        repeat_count in 1_usize..3,
    ) {
        let (_device, runner) = open_accountless_runner().map_err(fail)?;
        let desk = server_desk().map_err(fail)?;

        for _ in 0..repeat_count {
            let claimed = desk.wait(runner.claim_next_run());
            let reason = claimed.map_err(|problem| problem.reason);
            prop_assert_eq!(reason, Err(NO_ACCOUNT.to_owned()));
        }
    }

    #[test]
    fn test_claim_next_run_property_names_the_started_task(
        details in DETAILS_PATTERN,
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let _turn = desk.take_claim_turn();
        claim_until_empty(desk, &runner).map_err(fail)?;
        let task_id = desk.start_task(&details).map_err(fail)?;

        let heartbeat = sample_heartbeat();
        desk.wait(runner.send_heartbeat(&heartbeat)).map_err(fail)?;
        let response = desk.wait(runner.claim_next_run()).map_err(fail)?;

        let assignment = response.assignment;
        let claimed_task = assignment.map(|claimed| claimed.task.id.0);
        let claimed_text = claimed_task.map(|task| task.to_string());
        prop_assert_eq!(claimed_text, Some(task_id));
    }
}
