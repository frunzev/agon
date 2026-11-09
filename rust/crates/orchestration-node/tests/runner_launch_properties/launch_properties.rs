use std::thread;

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::launch_desk::{
    LAUNCH_CASES, QUIET_PERIOD, SILENCE_LIMIT, ask_live_host,
    ask_live_host_patiently, count_runner_requests, local_settings,
    open_launch_desk, unknown_run_refusal, wait_for_first_heartbeat,
    wait_for_own_address,
};
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

const LABEL_PATTERN: &str = "[a-z][a-z0-9]{0,7}";
const RUNNING_ROLES: [&str; 2] = ["runner", "client_and_runner"];
const ALL_ROLES: [&str; 3] = ["client", "runner", "client_and_runner"];
const MOST_LABELS: usize = 4;
const MOST_SLOTS: u32 = 6;

fn labels_strategy() -> impl Strategy<Value = Vec<String>> {
    prop::collection::vec(LABEL_PATTERN, 0..MOST_LABELS)
}

fn unbuildable_settings_strategy() -> impl Strategy<Value = Value> {
    prop_oneof![
        labels_strategy().prop_map(|labels| local_settings(&labels, 0)),
        labels_strategy().prop_map(|labels| {
            let mut settings = local_settings(&labels, 1);
            settings["surprise"] = json!(true);
            settings
        }),
        "[a-z]{1,6}://[a-z0-9./-]{0,16}".prop_map(|template| {
            let mut settings = local_settings(&[], 1);
            settings["clone_url_template"] = json!(template);
            settings
        }),
        "[a-z]{1,8}".prop_map(|kind| {
            let mut settings = local_settings(&[], 1);
            settings["sandbox"] = json!({ "kind": kind });
            settings
        }),
    ]
}

fn read_settings_in_effect(device: &TestDevice) -> Result<Value, String> {
    let status = device.run(&json!({ "command": "status" }))?;
    Ok(status["runner_settings"].clone())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LAUNCH_CASES))]

    #[test]
    fn test_runner_launcher_prepare_property_off_never_runs(
        role in prop::sample::select(ALL_ROLES.to_vec()),
    ) {
        let server = TestServer::start().map_err(fail)?;
        let device = TestDevice::start().map_err(fail)?;
        device
            .create_account_with_role(&server, "acme", role)
            .map_err(fail)?;

        thread::sleep(QUIET_PERIOD);

        prop_assert_eq!(count_runner_requests(&server), 0);
        let settings = read_settings_in_effect(&device).map_err(fail)?;
        prop_assert_eq!(settings, Value::Null);
    }

    #[test]
    fn test_runner_launcher_prepare_property_given_settings_take_effect(
        labels in labels_strategy(),
        slot_capacity in 1..MOST_SLOTS,
    ) {
        let settings = local_settings(&labels, slot_capacity);
        let desk = open_launch_desk(&settings, "runner").map_err(fail)?;

        let in_effect = read_settings_in_effect(&desk.device).map_err(fail)?;

        prop_assert_eq!(&in_effect["labels"], &json!(labels));
        prop_assert_eq!(&in_effect["slot_capacity"], &json!(slot_capacity));
        prop_assert_eq!(&in_effect["sandbox"], &settings["sandbox"]);
    }

    #[test]
    fn test_runner_launcher_prepare_property_refuses_what_cannot_run(
        settings in unbuildable_settings_strategy(),
    ) {
        let started = TestDevice::start_runner(&settings);

        prop_assert!(started.is_err(), "{}", settings);
    }

    #[test]
    fn test_prepared_runner_prepare_property_keeps_a_template_with_address(
        prefix in "[a-z]{1,6}://[a-z0-9./-]{0,16}",
        suffix in "(\\.git)?",
    ) {
        let template = format!("{prefix}{{address}}{suffix}");
        let mut settings = local_settings(&[], 1);
        settings["clone_url_template"] = json!(template);
        let desk = open_launch_desk(&settings, "runner").map_err(fail)?;

        let in_effect = read_settings_in_effect(&desk.device).map_err(fail)?;

        prop_assert_eq!(&in_effect["clone_url_template"], &json!(template));
    }

    #[test]
    fn test_prepared_runner_prepare_property_needs_the_address_placeholder(
        template in "[a-z]{1,6}://[a-z0-9./-]{0,16}",
    ) {
        let mut settings = local_settings(&[], 1);
        settings["clone_url_template"] = json!(template);

        let started = TestDevice::start_runner(&settings);

        let Err(message) = started else {
            return Err(fail("a template without the address started"));
        };
        prop_assert!(message.contains("clone template"), "{}", message);
    }

    #[test]
    fn test_prepared_runner_prepare_property_takes_effect_with_an_account(
        labels in labels_strategy(),
    ) {
        let server = TestServer::start().map_err(fail)?;
        let settings = local_settings(&labels, 1);
        let device = TestDevice::start_runner(&settings).map_err(fail)?;
        let before = read_settings_in_effect(&device).map_err(fail)?;

        device
            .create_account_with_role(&server, "acme", "runner")
            .map_err(fail)?;
        let after = read_settings_in_effect(&device).map_err(fail)?;

        prop_assert_eq!(before, Value::Null);
        prop_assert_eq!(&after["labels"], &json!(labels));
    }

    #[test]
    fn test_start_when_ready_property_a_client_device_never_runs(
        labels in labels_strategy(),
    ) {
        let settings = local_settings(&labels, 1);
        let desk = open_launch_desk(&settings, "client").map_err(fail)?;

        thread::sleep(QUIET_PERIOD);

        prop_assert_eq!(count_runner_requests(&desk.server), 0);
    }

    #[test]
    fn test_start_when_ready_property_a_runner_device_announces_itself(
        role in prop::sample::select(RUNNING_ROLES.to_vec()),
    ) {
        let settings = local_settings(&[], 1);
        let desk = open_launch_desk(&settings, role).map_err(fail)?;

        let heartbeat = wait_for_first_heartbeat(&desk.server);

        prop_assert!(heartbeat.is_ok(), "{:?}", heartbeat);
    }

    #[test]
    fn test_start_when_ready_property_a_forgotten_device_stops_serving(
        number in any::<u128>(),
    ) {
        let settings = local_settings(&[], 1);
        let desk = open_launch_desk(&settings, "runner").map_err(fail)?;
        let address = wait_for_own_address(&desk.device).map_err(fail)?;
        let served = ask_live_host_patiently(&address, number);
        prop_assert_eq!(served.map_err(fail)?, unknown_run_refusal(number));

        desk.device
            .run(&json!({ "command": "forget_this_device" }))
            .map_err(fail)?;
        let after_forgetting = ask_live_host(&address, number, SILENCE_LIMIT);

        prop_assert!(after_forgetting.is_err(), "{:?}", after_forgetting);
    }
}
