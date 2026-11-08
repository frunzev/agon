use axum::http::StatusCode;
use orchestration_core::run::{Run, StepStatus};
use orchestration_core::run_lifecycle::is_run_finished;
use proptest::prelude::*;

use crate::follow_up_desk::{
    count_active_runs, find_latest_run, open_follow_up_desk,
    run_endings_strategy, status_shown_for,
};
use crate::follow_up_fixtures::{
    chat_texts, count_waiting_steps, numbered_text, run_ending_strategy,
};
use crate::test_client::block_on;

const MESSAGE_CASES: u32 = 12;
const MOST_MESSAGES: usize = 3;

fn without_chat(run: &Run) -> Run {
    Run {
        chat: Vec::new(),
        ..run.clone()
    }
}

fn expected_texts(message_count: usize) -> Vec<String> {
    let mut texts = Vec::new();
    for position in 0..message_count {
        texts.push(numbered_text(position));
    }
    texts
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(MESSAGE_CASES))]

    #[test]
    fn test_append_chat_message_property_an_older_run_is_not_woken(
        endings in run_endings_strategy(),
        older_choice in any::<usize>(),
    ) {
        let (older_before, response, older_after, runs_after, task_after) =
            block_on(async {
                let desk = open_follow_up_desk().await;
                let runs = desk.run_all_to_end(&endings).await;
                let older_position = older_choice % (runs.len() - 1);
                let older_before = runs[older_position].clone();
                let response = desk.send_message(&older_before, 0).await;
                let older_after = desk.read_run(&older_before).await;
                let runs_after = desk.list_runs().await;
                let task_after = desk.read_task().await;
                (older_before, response, older_after, runs_after, task_after)
            });

        prop_assert_eq!(response.status, StatusCode::OK, "{:?}", response);
        prop_assert_eq!(
            without_chat(&older_after),
            without_chat(&older_before)
        );
        prop_assert_eq!(chat_texts(&older_after), expected_texts(1));
        prop_assert_eq!(count_waiting_steps(&older_after), 0);
        prop_assert_eq!(count_active_runs(&runs_after), 0);
        let latest = find_latest_run(&runs_after).expect("runs exist");
        prop_assert_eq!(task_after.status, status_shown_for(latest.status));
    }

    #[test]
    fn test_append_chat_message_property_never_makes_a_second_active_run(
        older_ending in run_ending_strategy(),
        is_newer_claimed in any::<bool>(),
        message_count in 1..=MOST_MESSAGES,
    ) {
        let (older_after, runs_after, newer_after) = block_on(async {
            let desk = open_follow_up_desk().await;
            let older = desk.run_to_end(older_ending).await;
            let newer: Run = desk.start().await.json();
            if is_newer_claimed {
                let claimed = desk.claim().await;
                let claimed = claimed.expect("the newer is claimed");
                desk.change_step(&claimed, StepStatus::Running).await;
            }
            for position in 0..message_count {
                let response = desk.send_message(&older, position).await;
                assert_eq!(response.status, StatusCode::OK, "{response:?}");
            }
            let older_after = desk.read_run(&older).await;
            let newer_after = desk.read_run(&newer).await;
            (older_after, desk.list_runs().await, newer_after)
        });

        prop_assert_eq!(count_active_runs(&runs_after), 1);
        prop_assert!(is_run_finished(older_after.status));
        prop_assert!(!is_run_finished(newer_after.status));
        let expected = expected_texts(message_count);
        prop_assert_eq!(chat_texts(&older_after), expected);
        prop_assert!(newer_after.chat.is_empty());
    }

    #[test]
    fn test_send_person_message_property_an_older_run_keeps_every_message(
        endings in run_endings_strategy(),
        message_count in 1..=MOST_MESSAGES,
    ) {
        let (task_before, task_after, older_after, claim_after) =
            block_on(async {
                let desk = open_follow_up_desk().await;
                let runs = desk.run_all_to_end(&endings).await;
                let older = runs[0].clone();
                let task_before = desk.read_task().await;
                for position in 0..message_count {
                    desk.send_message(&older, position).await;
                }
                let older_after = desk.read_run(&older).await;
                let task_after = desk.read_task().await;
                (task_before, task_after, older_after, desk.claim().await)
            });

        let expected = expected_texts(message_count);
        prop_assert_eq!(chat_texts(&older_after), expected);
        prop_assert_eq!(task_after.status, task_before.status);
        prop_assert!(claim_after.is_none(), "{:?}", claim_after);
    }

    #[test]
    fn test_find_follow_up_step_property_an_older_run_offers_nothing(
        endings in run_endings_strategy(),
        older_choice in any::<usize>(),
    ) {
        let (claim_after, runs_before, runs_after) = block_on(async {
            let desk = open_follow_up_desk().await;
            let runs_before = desk.run_all_to_end(&endings).await;
            let older = &runs_before[older_choice % (runs_before.len() - 1)];
            desk.send_message(older, 0).await;
            let claim_after = desk.claim().await;
            (claim_after, runs_before, desk.list_runs().await)
        });

        prop_assert!(claim_after.is_none(), "{:?}", claim_after);
        prop_assert_eq!(runs_after.len(), runs_before.len());
        for (after, before) in runs_after.iter().zip(&runs_before) {
            prop_assert_eq!(after.status, before.status);
            prop_assert_eq!(after.finished_at, before.finished_at);
        }
    }

    #[test]
    fn test_find_follow_up_step_property_the_latest_run_still_wakes(
        endings in run_endings_strategy(),
    ) {
        let (latest_after, task_after, claimed) = block_on(async {
            let desk = open_follow_up_desk().await;
            let runs = desk.run_all_to_end(&endings).await;
            let latest = find_latest_run(&runs).expect("runs exist").clone();
            let response = desk.send_message(&latest, 0).await;
            let latest_after: Run = response.json();
            let task_after = desk.read_task().await;
            (latest_after, task_after, desk.claim().await)
        });

        prop_assert!(!is_run_finished(latest_after.status));
        prop_assert_eq!(count_waiting_steps(&latest_after), 1);
        let shown = status_shown_for(latest_after.status);
        prop_assert_eq!(task_after.status, shown);
        let claimed = claimed.expect("the woken run is claimed again");
        prop_assert_eq!(claimed.id, latest_after.id);
    }

    #[test]
    fn test_find_follow_up_step_property_a_single_run_is_its_own_latest(
        ending in run_ending_strategy(),
    ) {
        let woken = block_on(async {
            let desk = open_follow_up_desk().await;
            let only_run = desk.run_to_end(ending).await;
            let response = desk.send_message(&only_run, 0).await;
            let woken: Run = response.json();
            woken
        });

        prop_assert!(!is_run_finished(woken.status), "{:?}", woken);
        prop_assert_eq!(count_waiting_steps(&woken), 1);
    }
}
