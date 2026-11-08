use axum::http::StatusCode;
use orchestration_core::run::{Run, RunStatus, StepStatus};
use orchestration_core::run_lifecycle::is_run_finished;
use orchestration_server::StateStorage;
use proptest::prelude::*;

use crate::follow_up_desk::{
    FollowUpDesk, count_active_runs, find_latest_run, open_follow_up_desk,
    run_endings_strategy,
};
use crate::follow_up_fixtures::chat_texts;
use crate::test_client::block_on;

const LEGACY_CASES: u32 = 8;

fn reopen_as_left_by_an_old_retry(run: &Run) -> Run {
    let mut steps = run.steps.clone();
    steps[0].status = StepStatus::Running;
    steps[0].finished_at = None;
    Run {
        status: RunStatus::Running,
        steps,
        failure: None,
        finished_at: None,
        ..run.clone()
    }
}

fn keep_oldest_run_active(desk: FollowUpDesk) -> FollowUpDesk {
    let mut state = desk
        .test
        .server
        .snapshot_state()
        .expect("the state is readable");
    let oldest_id = state
        .runs
        .values()
        .min_by_key(|record| record.run.number)
        .map(|record| record.run.id)
        .expect("a run exists");
    let record = state.runs.get_mut(&oldest_id).expect("the run is stored");
    record.run = reopen_as_left_by_an_old_retry(&record.run);
    let storage = StateStorage::new(desk.test.directory.path().to_path_buf());
    storage.save_state(&state).expect("the state saves");
    FollowUpDesk {
        test: desk.test.restart(),
        ..desk
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LEGACY_CASES))]

    #[test]
    fn test_has_other_active_run_property_the_latest_stays_finished(
        endings in run_endings_strategy(),
    ) {
        let (response, latest_after, runs_after) = block_on(async {
            let desk = open_follow_up_desk().await;
            desk.run_all_to_end(&endings).await;
            let desk = keep_oldest_run_active(desk);
            let desk_runs = desk.list_runs().await;
            let latest = find_latest_run(&desk_runs).expect("runs exist");
            let response = desk.send_message(latest, 0).await;
            let latest_after = desk.read_run(latest).await;
            (response, latest_after, desk.list_runs().await)
        });

        prop_assert_eq!(response.status, StatusCode::OK);
        prop_assert!(is_run_finished(latest_after.status));
        prop_assert_eq!(chat_texts(&latest_after).len(), 1);
        prop_assert_eq!(count_active_runs(&runs_after), 1);
    }

    #[test]
    fn test_has_other_active_run_property_a_relay_never_adds_a_second(
        endings in run_endings_strategy(),
    ) {
        let (relayed_status, runs_after) = block_on(async {
            let desk = open_follow_up_desk().await;
            desk.run_all_to_end(&endings).await;
            let desk = keep_oldest_run_active(desk);
            let desk_runs = desk.list_runs().await;
            let latest = find_latest_run(&desk_runs).expect("runs exist");
            let (relayed_status, _run) = desk.relay_message(latest, 0).await;
            (relayed_status, desk.list_runs().await)
        });

        prop_assert_eq!(relayed_status, StatusCode::OK);
        prop_assert_eq!(count_active_runs(&runs_after), 1);
        prop_assert!(!is_run_finished(runs_after[0].status));
    }

    #[test]
    fn test_has_other_active_run_property_the_active_run_is_untouched(
        endings in run_endings_strategy(),
        message_count in 1_usize..=3,
    ) {
        let (oldest_before, oldest_after) = block_on(async {
            let desk = open_follow_up_desk().await;
            desk.run_all_to_end(&endings).await;
            let desk = keep_oldest_run_active(desk);
            let desk_runs = desk.list_runs().await;
            let oldest_before = desk_runs[0].clone();
            let latest = find_latest_run(&desk_runs).expect("runs exist");
            for position in 0..message_count {
                desk.send_message(latest, position).await;
            }
            (oldest_before, desk.read_run(&desk_runs[0]).await)
        });

        prop_assert_eq!(oldest_after, oldest_before);
    }
}
