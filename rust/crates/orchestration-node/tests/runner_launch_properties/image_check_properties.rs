use std::thread;
use std::time::Duration;

use orchestration_core::agent_place::AgentPlace;
use orchestration_node::place_offers::normalize_offers;
use proptest::prelude::*;
use serde_json::json;

use crate::engine_desk::{
    EngineDesk, LONGER_THAN_AN_IMAGE_RECHECK, MISSING_IMAGE, READY_ENGINE,
    local_sandbox, open_engine_desk, runner_settings,
};
use crate::engine_scripts::EngineAnswers;
use crate::launch_desk::LAUNCH_CASES;
use crate::runner_settings_samples::place_strategy;
use crate::support::test_device::fail;

const BOTH_PLACES: [&str; 2] = ["local_process", "container"];
const LOCAL_ONLY: [&str; 1] = ["local_process"];
const CONTAINER_ONLY: [&str; 1] = ["container"];
const MOST_STATUS_READS: usize = 5;
const RESTART_LIMIT: Duration = Duration::from_secs(5);
const NO_RESTART_PERIOD: Duration = Duration::from_secs(2);

fn open_local(answers: EngineAnswers) -> Result<EngineDesk, TestCaseError> {
    let settings = runner_settings(&local_sandbox(), &[]);
    open_engine_desk(&settings, answers).map_err(fail)
}

fn open_half_blocked() -> Result<EngineDesk, TestCaseError> {
    let desk = open_local(MISSING_IMAGE)?;
    desk.choose_offers(&json!(BOTH_PLACES)).map_err(fail)?;
    Ok(desk)
}

fn read_status_times(
    desk: &EngineDesk,
    read_count: usize,
) -> Result<(), TestCaseError> {
    for _ in 0..read_count {
        desk.read_status().map_err(fail)?;
    }
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LAUNCH_CASES))]

    #[test]
    fn test_is_image_check_due_property_reads_within_the_interval_skip_it(
        read_count in 1..=MOST_STATUS_READS,
    ) {
        let desk = open_half_blocked()?;
        let calls_after_choice = desk.count_engine_calls();

        read_status_times(&desk, read_count)?;

        prop_assert!(calls_after_choice > 0);
        prop_assert_eq!(desk.count_engine_calls(), calls_after_choice);
    }

    #[test]
    fn test_is_image_check_due_property_a_read_after_the_interval_checks(
        read_count in 1..=MOST_STATUS_READS,
    ) {
        let desk = open_half_blocked()?;
        let calls_after_choice = desk.count_engine_calls();

        thread::sleep(LONGER_THAN_AN_IMAGE_RECHECK);
        read_status_times(&desk, read_count)?;

        prop_assert!(desk.count_engine_calls() > calls_after_choice);
    }

    #[test]
    fn test_is_image_check_due_property_a_full_runner_is_not_rechecked(
        read_count in 1..=MOST_STATUS_READS,
    ) {
        let desk = open_local(READY_ENGINE)?;
        desk.choose_offers(&json!(BOTH_PLACES)).map_err(fail)?;
        let calls_after_choice = desk.count_engine_calls();

        thread::sleep(LONGER_THAN_AN_IMAGE_RECHECK);
        read_status_times(&desk, read_count)?;

        prop_assert_eq!(desk.count_engine_calls(), calls_after_choice);
    }

    #[test]
    fn test_lock_last_image_check_property_an_offer_change_clears_it(
        read_count in 0..=MOST_STATUS_READS,
    ) {
        let desk = open_half_blocked()?;
        read_status_times(&desk, read_count)?;
        let calls_before_change = desk.count_engine_calls();

        desk.choose_offers(&json!(CONTAINER_ONLY)).map_err(fail)?;

        prop_assert!(desk.count_engine_calls() > calls_before_change);
    }

    #[test]
    fn test_lock_last_image_check_property_a_new_credential_clears_it(
        read_count in 0..=MOST_STATUS_READS,
    ) {
        let desk = open_half_blocked()?;
        read_status_times(&desk, read_count)?;
        let calls_before_saving = desk.count_engine_calls();

        desk.save_api_key().map_err(fail)?;

        prop_assert!(desk.count_engine_calls() > calls_before_saving);
    }

    #[test]
    fn test_lock_last_image_check_property_reads_share_one_recheck(
        read_count in 2..=MOST_STATUS_READS,
    ) {
        let desk = open_half_blocked()?;
        thread::sleep(LONGER_THAN_AN_IMAGE_RECHECK);
        desk.read_status().map_err(fail)?;
        let calls_after_recheck = desk.count_engine_calls();

        read_status_times(&desk, read_count)?;

        prop_assert_eq!(desk.count_engine_calls(), calls_after_recheck);
    }

    #[test]
    fn test_have_offers_changed_property_the_same_choice_checks_nothing(
        offers in prop::collection::vec(place_strategy(), 1..5),
    ) {
        let desk = open_local(MISSING_IMAGE)?;
        desk.choose_offers(&json!(offers)).map_err(fail)?;
        let calls_after_choice = desk.count_engine_calls();
        let mut reordered = offers.clone();
        reordered.reverse();

        desk.choose_offers(&json!(reordered)).map_err(fail)?;

        prop_assert_eq!(desk.count_engine_calls(), calls_after_choice);
    }

    #[test]
    fn test_have_offers_changed_property_adding_a_container_checks_it(
        read_count in 0..=MOST_STATUS_READS,
    ) {
        let desk = open_local(MISSING_IMAGE)?;
        desk.choose_offers(&json!(LOCAL_ONLY)).map_err(fail)?;
        read_status_times(&desk, read_count)?;
        let calls_before = desk.count_engine_calls();

        desk.choose_offers(&json!(BOTH_PLACES)).map_err(fail)?;

        prop_assert!(desk.count_engine_calls() > calls_before);
    }

    #[test]
    fn test_have_offers_changed_property_checked_places_follow_the_choice(
        offers in prop::collection::vec(place_strategy(), 1..5),
    ) {
        let desk = open_local(MISSING_IMAGE)?;

        desk.choose_offers(&json!(offers)).map_err(fail)?;
        let checked = desk.list_checked_offers().map_err(fail)?;

        let mut checked_places: Vec<AgentPlace> = Vec::new();
        for offer in checked.as_array().cloned().unwrap_or_default() {
            let place = serde_json::from_value(offer["place"].clone());
            checked_places.push(place.map_err(fail)?);
        }
        prop_assert_eq!(checked_places, normalize_offers(&offers));
    }

    #[test]
    fn test_is_running_property_an_unchanged_runner_is_left_alone(
        read_count in 1..=MOST_STATUS_READS,
    ) {
        let desk = open_local(READY_ENGINE)?;
        desk.wait_for_heartbeat_after(0).map_err(fail)?;
        let seen_count = desk.read_heartbeats().len();

        read_status_times(&desk, read_count)?;
        let restarted =
            desk.wait_for_heartbeat_within(seen_count, NO_RESTART_PERIOD);

        prop_assert!(restarted.is_err(), "{:?}", restarted);
    }

    #[test]
    fn test_is_running_property_a_new_credential_restarts_a_container(
        _seed in any::<u8>(),
    ) {
        let desk = open_local(READY_ENGINE)?;
        desk.choose_offers(&json!(CONTAINER_ONLY)).map_err(fail)?;
        desk.wait_for_offers(&json!(CONTAINER_ONLY)).map_err(fail)?;
        let seen_count = desk.read_heartbeats().len();

        desk.save_api_key().map_err(fail)?;
        let restarted =
            desk.wait_for_heartbeat_within(seen_count, RESTART_LIMIT);

        prop_assert!(restarted.is_ok(), "{:?}", restarted);
    }

    #[test]
    fn test_is_running_property_a_dropped_offer_restarts_with_the_rest(
        _seed in any::<u8>(),
    ) {
        let desk = open_local(READY_ENGINE)?;
        desk.choose_offers(&json!(BOTH_PLACES)).map_err(fail)?;
        desk.wait_for_offers(&json!(BOTH_PLACES)).map_err(fail)?;

        desk.choose_offers(&json!(LOCAL_ONLY)).map_err(fail)?;

        prop_assert_eq!(desk.wait_for_offers(&json!(LOCAL_ONLY)), Ok(()));
    }
}
