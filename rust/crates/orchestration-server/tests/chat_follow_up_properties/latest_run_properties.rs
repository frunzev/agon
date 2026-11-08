use axum::http::StatusCode;
use orchestration_core::run_lifecycle::is_run_finished;
use proptest::prelude::*;

use crate::follow_up_desk::{
    FEWEST_RUNS, MOST_RUNS, find_latest_run, open_follow_up_desk,
    run_endings_strategy,
};
use crate::follow_up_fixtures::RunEnding;
use crate::test_client::block_on;

const LATEST_CASES: u32 = 10;
const OLDER_RETRY_REFUSAL: &str =
    "only the latest run of the task can be retried";

fn retryable_endings_strategy() -> impl Strategy<Value = Vec<RunEnding>> {
    let ending =
        prop_oneof![Just(RunEnding::Failed), Just(RunEnding::Cancelled)];
    proptest::collection::vec(ending, FEWEST_RUNS..=MOST_RUNS)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LATEST_CASES))]

    #[test]
    fn test_is_latest_run_property_only_the_highest_number_wakes(
        endings in run_endings_strategy(),
        chosen in any::<usize>(),
    ) {
        let (chosen_number, highest_number, woken_after) = block_on(async {
            let desk = open_follow_up_desk().await;
            let runs = desk.run_all_to_end(&endings).await;
            let chosen_run = runs[chosen % runs.len()].clone();
            let highest = find_latest_run(&runs).expect("runs exist").number;
            desk.send_message(&chosen_run, 0).await;
            let after = desk.read_run(&chosen_run).await;
            (chosen_run.number, highest, !is_run_finished(after.status))
        });

        prop_assert_eq!(woken_after, chosen_number == highest_number);
    }

    #[test]
    fn test_is_latest_run_property_wakes_and_retries_agree(
        endings in retryable_endings_strategy(),
        chosen in any::<usize>(),
    ) {
        let (retry_refusal, is_active_after) = block_on(async {
            let desk = open_follow_up_desk().await;
            let runs = desk.run_all_to_end(&endings).await;
            let chosen_run = runs[chosen % runs.len()].clone();
            let retried = desk.retry(&chosen_run).await;
            let is_refused_as_older = retried.status == StatusCode::CONFLICT
                && retried.error_message() == OLDER_RETRY_REFUSAL;
            let is_reopened_by_retry = retried.status == StatusCode::OK;
            if !is_reopened_by_retry {
                desk.send_message(&chosen_run, 0).await;
            }
            let after = desk.read_run(&chosen_run).await;
            (is_refused_as_older, !is_run_finished(after.status))
        });

        prop_assert_eq!(retry_refusal, !is_active_after);
    }

    #[test]
    fn test_is_latest_run_property_a_new_run_makes_the_old_one_older(
        endings in run_endings_strategy(),
    ) {
        let (first_woke, last_woke) = block_on(async {
            let desk = open_follow_up_desk().await;
            let runs = desk.run_all_to_end(&endings).await;
            let first = runs[0].clone();
            let last = find_latest_run(&runs).expect("runs exist").clone();
            desk.send_message(&first, 0).await;
            let first_after = desk.read_run(&first).await;
            desk.send_message(&last, 1).await;
            let last_after = desk.read_run(&last).await;
            (
                !is_run_finished(first_after.status),
                !is_run_finished(last_after.status),
            )
        });

        prop_assert!(!first_woke);
        prop_assert!(last_woke);
    }
}
