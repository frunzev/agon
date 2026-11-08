use axum::http::StatusCode;
use orchestration_core::run::Run;
use orchestration_core::run_lifecycle::is_run_finished;
use proptest::prelude::*;

use crate::follow_up_desk::{
    count_active_runs, find_latest_run, open_follow_up_desk,
    run_endings_strategy,
};
use crate::follow_up_fixtures::{
    chat_texts, count_waiting_steps, numbered_text,
};
use crate::test_client::block_on;

const RELAY_CASES: u32 = 10;
const MOST_RELAYED: usize = 3;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RELAY_CASES))]

    #[test]
    fn test_apply_run_event_property_a_relay_leaves_an_older_run_finished(
        endings in run_endings_strategy(),
        older_choice in any::<usize>(),
    ) {
        let (older_before, relayed, older_after, runs_after) =
            block_on(async {
                let desk = open_follow_up_desk().await;
                let runs = desk.run_all_to_end(&endings).await;
                let older_position = older_choice % (runs.len() - 1);
                let older_before = runs[older_position].clone();
                let relayed = desk.relay_message(&older_before, 0).await;
                let older_after = desk.read_run(&older_before).await;
                (older_before, relayed, older_after, desk.list_runs().await)
            });

        prop_assert_eq!(relayed.0, StatusCode::OK);
        prop_assert_eq!(older_after.status, older_before.status);
        prop_assert_eq!(older_after.finished_at, older_before.finished_at);
        prop_assert_eq!(count_waiting_steps(&older_after), 0);
        prop_assert_eq!(count_active_runs(&runs_after), 0);
    }

    #[test]
    fn test_apply_run_event_property_relays_reach_the_older_chat_in_order(
        endings in run_endings_strategy(),
        relayed_count in 1..=MOST_RELAYED,
    ) {
        let older_after = block_on(async {
            let desk = open_follow_up_desk().await;
            let runs = desk.run_all_to_end(&endings).await;
            for position in 0..relayed_count {
                let relayed = desk.relay_message(&runs[0], position).await;
                let (status, _run) = relayed;
                assert_eq!(status, StatusCode::OK);
            }
            desk.read_run(&runs[0]).await
        });

        let mut expected = Vec::new();
        for position in 0..relayed_count {
            expected.push(numbered_text(position));
        }
        prop_assert_eq!(chat_texts(&older_after), expected);
    }

    #[test]
    fn test_apply_run_event_property_a_relay_still_wakes_the_latest_run(
        endings in run_endings_strategy(),
    ) {
        let (relayed, claimed) = block_on(async {
            let desk = open_follow_up_desk().await;
            let runs = desk.run_all_to_end(&endings).await;
            let latest = find_latest_run(&runs).expect("runs exist").clone();
            let relayed = desk.relay_message(&latest, 0).await;
            (relayed, desk.claim().await)
        });

        prop_assert_eq!(relayed.0, StatusCode::OK);
        let woken: Run = relayed.1.expect("the relayed run is answered");
        prop_assert!(!is_run_finished(woken.status));
        let claimed = claimed.expect("the woken run is claimed again");
        prop_assert_eq!(claimed.id, woken.id);
    }
}
