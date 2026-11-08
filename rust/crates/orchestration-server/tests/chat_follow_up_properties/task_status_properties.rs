use axum::http::StatusCode;
use orchestration_api::work::RunEvent;
use orchestration_core::run::LogLine;
use proptest::prelude::*;

use crate::follow_up_desk::{
    find_latest_run, open_follow_up_desk, run_endings_strategy,
    status_shown_for,
};
use crate::follow_up_fixtures::numbered_text;
use crate::run_fixtures::post_events;
use crate::run_history_properties::{history_strategy, observe_history};
use crate::test_client::block_on;

const STATUS_CASES: u32 = 10;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STATUS_CASES))]

    #[test]
    fn test_sync_task_status_property_an_older_message_keeps_the_row_status(
        endings in run_endings_strategy(),
        older_choice in any::<usize>(),
    ) {
        let (shown_before, shown_after, latest_status) = block_on(async {
            let desk = open_follow_up_desk().await;
            let runs = desk.run_all_to_end(&endings).await;
            let shown_before = desk.read_task().await.status;
            let older = &runs[older_choice % (runs.len() - 1)];
            desk.send_message(older, 0).await;
            let shown_after = desk.read_task().await.status;
            let latest = find_latest_run(&runs).expect("runs exist").status;
            (shown_before, shown_after, latest)
        });

        prop_assert_eq!(shown_after, shown_before);
        prop_assert_eq!(shown_after, status_shown_for(latest_status));
    }

    #[test]
    fn test_sync_task_status_property_a_late_older_log_keeps_the_row_status(
        endings in run_endings_strategy(),
        older_choice in any::<usize>(),
    ) {
        let (response_status, shown_after, latest_status) = block_on(async {
            let desk = open_follow_up_desk().await;
            let runs = desk.run_all_to_end(&endings).await;
            let older = &runs[older_choice % (runs.len() - 1)];
            let line = LogLine {
                at: desk.test.now(),
                step_name: older.steps[0].name.clone(),
                text: numbered_text(0),
                is_error: false,
            };
            let events = vec![RunEvent::LogAppended { line }];
            let (response_status, _run) =
                post_events(&desk.test, &desk.runner, older, events).await;
            let shown_after = desk.read_task().await.status;
            let latest = find_latest_run(&runs).expect("runs exist").status;
            (response_status, shown_after, latest)
        });

        prop_assert_eq!(response_status, StatusCode::OK);
        prop_assert_eq!(shown_after, status_shown_for(latest_status));
    }

    #[test]
    fn test_sync_task_status_property_follows_the_latest_run_after_each_step(
        actions in history_strategy(),
    ) {
        let observed = observe_history(&actions);

        for step in &observed {
            let Some(latest) = find_latest_run(&step.runs) else {
                continue;
            };
            let shown = status_shown_for(latest.status);
            prop_assert_eq!(step.task.status, shown, "{:?}", step);
        }
    }
}
