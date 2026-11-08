use axum::http::StatusCode;
use chrono::TimeDelta;
use orchestration_api::work::RunEvent;
use orchestration_core::run::{Run, StepStatus};
use orchestration_core::run_lifecycle::is_run_finished;
use orchestration_server::{ABANDONED_STEP_TIMEOUT, requeue_abandoned_steps};
use proptest::prelude::*;

use crate::follow_up_desk::{
    FollowUpDesk, find_latest_run, open_follow_up_desk, run_endings_strategy,
    status_shown_for,
};
use crate::follow_up_fixtures::{
    chat_texts, count_waiting_steps, person_message, run_ending_strategy,
};
use crate::run_fixtures::post_events;
use crate::test_client::block_on;

const COVERAGE_CASES: u32 = 8;
const SILENCE_PAST_TIMEOUT: TimeDelta = TimeDelta::minutes(1);

async fn abandon_a_running_latest_run(desk: &FollowUpDesk) -> Run {
    let started: Run = desk.start().await.json();
    let claimed = desk.claim().await.expect("the runner claims the run");
    desk.change_step(&claimed, StepStatus::Running).await;
    desk.test
        .clock
        .advance(ABANDONED_STEP_TIMEOUT + SILENCE_PAST_TIMEOUT);
    requeue_abandoned_steps(&desk.test.server)
        .expect("the scheduler pass saves its changes");
    desk.read_run(&started).await
}

async fn finish_and_message_in_one_batch(desk: &FollowUpDesk) -> Run {
    let response = desk.start().await;
    assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
    let claimed = desk.claim().await.expect("the runner claims the run");
    desk.change_step(&claimed, StepStatus::Running).await;
    let events = vec![
        RunEvent::StepStatusChanged {
            step_name: claimed.steps[0].name.clone(),
            status: StepStatus::Done,
        },
        RunEvent::ChatAppended {
            message: person_message(&desk.test, 0),
        },
    ];
    let (status, run) =
        post_events(&desk.test, &desk.runner, &claimed, events).await;
    assert_eq!(status, StatusCode::OK);
    run.expect("the batch is stored")
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(COVERAGE_CASES))]

    #[test]
    fn test_send_person_message_property_the_answer_is_the_stored_run(
        endings in run_endings_strategy(),
        chosen in any::<usize>(),
    ) {
        let (answered, stored) = block_on(async {
            let desk = open_follow_up_desk().await;
            let runs = desk.run_all_to_end(&endings).await;
            let chosen_run = &runs[chosen % runs.len()];
            let answered: Run = desk.send_message(chosen_run, 0).await.json();
            (answered, desk.read_run(chosen_run).await)
        });

        prop_assert_eq!(answered, stored);
    }

    #[test]
    fn test_find_latest_run_property_a_new_run_takes_over_the_row(
        endings in run_endings_strategy(),
    ) {
        let (task_status, newest) = block_on(async {
            let desk = open_follow_up_desk().await;
            desk.run_all_to_end(&endings).await;
            let newest: Run = desk.start().await.json();
            (desk.read_task().await.status, newest)
        });

        prop_assert_eq!(task_status, status_shown_for(newest.status));
    }

    #[test]
    fn test_find_latest_run_property_numbers_rise_with_every_start(
        endings in run_endings_strategy(),
    ) {
        let runs = block_on(async {
            let desk = open_follow_up_desk().await;
            desk.run_all_to_end(&endings).await
        });

        let latest = find_latest_run(&runs).expect("runs exist");
        prop_assert_eq!(latest.id, runs[runs.len() - 1].id);
        for (position, run) in runs.iter().enumerate() {
            let number = usize::try_from(run.number).ok();
            prop_assert_eq!(number, Some(position + 1));
        }
    }

    #[test]
    fn test_record_run_events_property_a_finishing_batch_still_wakes(
        _round in 0_u8..1,
    ) {
        let woken = block_on(async {
            let desk = open_follow_up_desk().await;
            finish_and_message_in_one_batch(&desk).await
        });

        prop_assert!(!is_run_finished(woken.status), "{:?}", woken);
        prop_assert_eq!(count_waiting_steps(&woken), 1);
    }

    #[test]
    fn test_record_run_events_property_a_finishing_batch_keeps_the_message(
        _round in 0_u8..1,
    ) {
        let (woken, task_status) = block_on(async {
            let desk = open_follow_up_desk().await;
            let woken = finish_and_message_in_one_batch(&desk).await;
            (woken, desk.read_task().await.status)
        });

        prop_assert_eq!(chat_texts(&woken).len(), 1);
        prop_assert_eq!(task_status, status_shown_for(woken.status));
    }

    #[test]
    fn test_record_run_events_property_an_older_batch_keeps_the_row(
        endings in run_endings_strategy(),
        older_choice in any::<usize>(),
    ) {
        let (task_status, latest_status) = block_on(async {
            let desk = open_follow_up_desk().await;
            let runs = desk.run_all_to_end(&endings).await;
            let older = &runs[older_choice % (runs.len() - 1)];
            let events = vec![RunEvent::ChatAppended {
                message: person_message(&desk.test, 0),
            }];
            post_events(&desk.test, &desk.runner, older, events).await;
            let latest = find_latest_run(&runs).expect("runs exist").status;
            (desk.read_task().await.status, latest)
        });

        prop_assert_eq!(task_status, status_shown_for(latest_status));
    }

    #[test]
    fn test_release_abandoned_steps_property_the_row_follows_the_requeue(
        endings in proptest::collection::vec(run_ending_strategy(), 0..3),
    ) {
        let (released, task_status) = block_on(async {
            let desk = open_follow_up_desk().await;
            desk.run_all_to_end(&endings).await;
            let released = abandon_a_running_latest_run(&desk).await;
            (released, desk.read_task().await.status)
        });

        prop_assert_eq!(task_status, status_shown_for(released.status));
    }

    #[test]
    fn test_release_abandoned_steps_property_a_released_step_waits(
        endings in proptest::collection::vec(run_ending_strategy(), 0..3),
    ) {
        let released = block_on(async {
            let desk = open_follow_up_desk().await;
            desk.run_all_to_end(&endings).await;
            abandon_a_running_latest_run(&desk).await
        });

        prop_assert!(!is_run_finished(released.status));
        prop_assert_eq!(count_waiting_steps(&released), 1);
    }

    #[test]
    fn test_release_abandoned_steps_property_older_runs_stay_untouched(
        endings in run_endings_strategy(),
    ) {
        let (before, after) = block_on(async {
            let desk = open_follow_up_desk().await;
            let before = desk.run_all_to_end(&endings).await;
            abandon_a_running_latest_run(&desk).await;
            let after = desk.list_runs().await;
            (before, after)
        });

        prop_assert_eq!(&after[..before.len()], &before[..]);
    }
}
