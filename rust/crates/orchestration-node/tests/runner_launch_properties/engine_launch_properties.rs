use std::collections::BTreeSet;

use orchestration_core::agent_place::AgentPlace;
use orchestration_core::peer_address::PeerAddress;
use orchestration_node::place_offers::normalize_offers;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::engine_desk::{
    EngineDesk, LONGER_THAN_A_CLAIM_INTERVAL, MISSING_IMAGE, READY_ENGINE,
    RUNNER_LIMIT, STOPPED_ENGINE, container_sandbox, local_sandbox,
    open_engine_desk, runner_settings,
};
use crate::engine_scripts::EngineAnswers;
use crate::launch_desk::{
    LAUNCH_CASES, SILENCE_LIMIT, ask_live_host, ask_live_host_patiently,
    read_own_address, unknown_run_refusal,
};
use crate::runner_settings_samples::place_strategy;
use crate::support::test_device::fail;
use crate::support::waiting::wait_for;

const HOST_PATTERN: &str = "[a-z]{1,8}\\.(com|dev|io)";
const LOCAL_ONLY: &str = "local_process";

fn blocked_engine_strategy() -> impl Strategy<Value = EngineAnswers> {
    prop_oneof![Just(MISSING_IMAGE), Just(STOPPED_ENGINE)]
}

fn open_local(answers: EngineAnswers) -> Result<EngineDesk, TestCaseError> {
    let settings = runner_settings(&local_sandbox(), &[]);
    open_engine_desk(&settings, answers).map_err(fail)
}

fn places_json(places: &[AgentPlace]) -> Value {
    json!(places)
}

fn own_address_of(desk: &EngineDesk) -> Result<PeerAddress, String> {
    wait_for(RUNNER_LIMIT, "the published peer address", || {
        let list_devices = json!({ "command": "list_devices" });
        let devices = desk.runner.run(&list_devices)?;
        Ok(read_own_address(&devices).ok())
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LAUNCH_CASES))]

    #[test]
    fn test_choose_offered_sandboxes_property_starts_with_the_set_place(
        starts_in_a_container in any::<bool>(),
    ) {
        let sandbox = if starts_in_a_container {
            container_sandbox(&[])
        } else {
            local_sandbox()
        };
        let settings = runner_settings(&sandbox, &[]);
        let desk = open_engine_desk(&settings, READY_ENGINE).map_err(fail)?;

        let expected = if starts_in_a_container {
            json!(["container"])
        } else {
            json!([LOCAL_ONLY])
        };
        prop_assert_eq!(desk.wait_for_offers(&expected), Ok(()));
    }

    #[test]
    fn test_choose_offered_sandboxes_property_offers_the_choice_in_order(
        offers in prop::collection::vec(place_strategy(), 1..5),
    ) {
        let desk = open_local(READY_ENGINE)?;

        desk.choose_offers(&places_json(&offers)).map_err(fail)?;

        let expected = places_json(&normalize_offers(&offers));
        prop_assert_eq!(desk.wait_for_offers(&expected), Ok(()));
    }

    #[test]
    fn test_choose_offered_sandboxes_property_a_choice_survives_a_restart(
        offers in prop::collection::vec(place_strategy(), 1..5),
    ) {
        let desk = open_local(READY_ENGINE)?;
        desk.choose_offers(&places_json(&offers)).map_err(fail)?;
        let expected = places_json(&normalize_offers(&offers));
        desk.wait_for_offers(&expected).map_err(fail)?;

        let restarted = desk.restart().map_err(fail)?;
        let seen_count = restarted.read_heartbeats().len();
        let heartbeat =
            restarted.wait_for_heartbeat_after(seen_count).map_err(fail)?;

        prop_assert_eq!(&heartbeat["offers"], &expected);
    }

    #[test]
    fn test_configure_for_device_property_a_container_passes_its_hosts(
        hosts in prop::collection::btree_set(HOST_PATTERN, 0..4),
    ) {
        let hosts: Vec<String> = hosts.into_iter().collect();
        let settings = runner_settings(&container_sandbox(&hosts), &[]);
        let desk = open_engine_desk(&settings, READY_ENGINE).map_err(fail)?;

        let heartbeat = desk.wait_for_heartbeat_after(0).map_err(fail)?;

        let announced: BTreeSet<String> = serde_json::from_value(
            heartbeat["allowed_hosts"].clone(),
        )
        .map_err(fail)?;
        let expected: BTreeSet<String> = hosts.into_iter().collect();
        prop_assert_eq!(announced, expected);
    }

    #[test]
    fn test_keep_working_property_a_blocked_container_keeps_this_computer(
        answers in blocked_engine_strategy(),
    ) {
        let desk = open_local(answers)?;

        desk.choose_offers(&json!(["container", LOCAL_ONLY]))
            .map_err(fail)?;
        let checked = desk.list_checked_offers().map_err(fail)?;

        prop_assert_eq!(desk.wait_for_offers(&json!([LOCAL_ONLY])), Ok(()));
        prop_assert_eq!(&checked[0]["problem"], &Value::Null);
        prop_assert!(checked[1]["problem"].is_string(), "{}", checked);
    }

    #[test]
    fn test_keep_working_property_nothing_working_runs_nothing(
        answers in blocked_engine_strategy(),
    ) {
        let desk = open_local(answers)?;
        desk.wait_for_heartbeat_after(0).map_err(fail)?;

        desk.choose_offers(&json!(["container"])).map_err(fail)?;
        let status = desk.read_status().map_err(fail)?;

        prop_assert!(status["runner_problem"].is_string(), "{}", status);
        prop_assert!(desk.stays_quiet_for(LONGER_THAN_A_CLAIM_INTERVAL));
    }

    #[test]
    fn test_keep_working_property_every_working_offer_runs(
        offers in prop::collection::vec(place_strategy(), 1..5),
    ) {
        let desk = open_local(READY_ENGINE)?;

        desk.choose_offers(&places_json(&offers)).map_err(fail)?;
        let checked = desk.list_checked_offers().map_err(fail)?;

        let normalized = normalize_offers(&offers);
        prop_assert_eq!(
            desk.wait_for_offers(&places_json(&normalized)),
            Ok(())
        );
        let checked_list = checked.as_array().cloned().unwrap_or_default();
        prop_assert_eq!(checked_list.len(), normalized.len());
        for offer in &checked_list {
            prop_assert_eq!(&offer["problem"], &Value::Null);
        }
    }

    #[test]
    fn test_runner_handle_stop_property_requests_end_after_a_block(
        answers in blocked_engine_strategy(),
    ) {
        let desk = open_local(answers)?;
        desk.wait_for_heartbeat_after(0).map_err(fail)?;

        desk.choose_offers(&json!(["container"])).map_err(fail)?;

        prop_assert!(desk.stays_quiet_for(LONGER_THAN_A_CLAIM_INTERVAL));
    }

    #[test]
    fn test_runner_handle_stop_property_a_stopped_runner_answers_no_link(
        answers in blocked_engine_strategy(),
        number in any::<u128>(),
    ) {
        let desk = open_local(answers)?;
        let address = own_address_of(&desk).map_err(fail)?;
        let served = ask_live_host_patiently(&address, number);
        prop_assert_eq!(served.map_err(fail)?, unknown_run_refusal(number));

        desk.choose_offers(&json!(["container"])).map_err(fail)?;
        let after_stop = ask_live_host(&address, number, SILENCE_LIMIT);

        prop_assert!(after_stop.is_err(), "{:?}", after_stop);
    }

    #[test]
    fn test_runner_handle_stop_property_offering_again_restarts(
        answers in blocked_engine_strategy(),
    ) {
        let desk = open_local(answers)?;
        desk.choose_offers(&json!(["container"])).map_err(fail)?;
        let seen_count = desk.read_heartbeats().len();

        desk.choose_offers(&json!([LOCAL_ONLY])).map_err(fail)?;
        let heartbeat =
            desk.wait_for_heartbeat_after(seen_count).map_err(fail)?;

        prop_assert_eq!(&heartbeat["offers"], &json!([LOCAL_ONLY]));
    }
}
