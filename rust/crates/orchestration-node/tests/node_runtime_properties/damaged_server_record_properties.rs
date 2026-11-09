use std::fs;

use proptest::prelude::*;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::access_node::{has_no_app_server, open_node};
use crate::damaged_server_records::{
    KIND_FIELD, PROBLEM_FIELD, RECORD_DAMAGED_KIND,
    damaged_server_record_strategy, forget_device, read_status,
    server_record_in, set_up_again, start_with_damaged_record,
};
use crate::hosting_problem_steps::{
    forget_device_on, prepare_hosted_data, read_status_on,
};
use crate::runtime_steps::start_runtime;
use crate::support::test_device::fail;

const OPEN_CASES: u32 = 24;
const RUNTIME_CASES: u32 = 3;

fn has_problem_text(status: &Value) -> bool {
    status[PROBLEM_FIELD]
        .as_str()
        .is_some_and(|problem| !problem.trim().is_empty())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(OPEN_CASES))]

    #[test]
    fn test_open_property_a_damaged_server_record_still_opens(
        damaged_bytes in damaged_server_record_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let record_path = server_record_in(data_directory.path());
        fs::write(record_path, &damaged_bytes).map_err(fail)?;

        let opened = open_node(&data_directory);

        let node = opened.map_err(fail)?;
        prop_assert!(has_no_app_server(&node));
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RUNTIME_CASES))]

    #[test]
    fn test_open_property_a_damaged_server_record_is_reported_as_damage(
        damaged_bytes in damaged_server_record_strategy(),
    ) {
        let device =
            start_with_damaged_record(&damaged_bytes).map_err(fail)?;

        let status = read_status(&device).map_err(fail)?;

        prop_assert_eq!(&status[KIND_FIELD], &json!(RECORD_DAMAGED_KIND));
        prop_assert!(has_problem_text(&status), "{}", status);
        prop_assert!(status["account"].is_object(), "{}", status);
        prop_assert_eq!(&status["server_reachable"], &json!(false));
    }

    #[test]
    fn test_open_property_forgetting_a_damaged_server_record_sets_up_again(
        damaged_bytes in damaged_server_record_strategy(),
    ) {
        let device =
            start_with_damaged_record(&damaged_bytes).map_err(fail)?;

        let forgotten = forget_device(&device);
        let forgotten_status = read_status(&device).map_err(fail)?;
        let fresh_server = set_up_again(&device).map_err(fail)?;
        let fresh_status = read_status(&device).map_err(fail)?;

        prop_assert_eq!(forgotten, Ok(Value::Null));
        prop_assert_eq!(&forgotten_status[PROBLEM_FIELD], &Value::Null);
        prop_assert_eq!(&forgotten_status[KIND_FIELD], &Value::Null);
        prop_assert_eq!(&forgotten_status["account"], &Value::Null);
        prop_assert!(fresh_status["account"].is_object(), "{}", fresh_status);
        prop_assert_eq!(&fresh_status[PROBLEM_FIELD], &Value::Null);
        prop_assert_eq!(&fresh_status["server_reachable"], &json!(true));
        drop(fresh_server);
    }

    #[test]
    fn test_open_property_a_hosting_computer_reports_the_damaged_record(
        damaged_bytes in damaged_server_record_strategy(),
    ) {
        let hosted = prepare_hosted_data().map_err(fail)?;
        let data_directory = hosted.data_directory.path();
        fs::write(server_record_in(data_directory), &damaged_bytes)
            .map_err(fail)?;

        let runtime = start_runtime(data_directory, hosted.port)
            .map_err(fail)?;
        let status = read_status_on(&runtime).map_err(fail)?;
        let forgotten = forget_device_on(&runtime);
        let forgotten_status = read_status_on(&runtime).map_err(fail)?;

        prop_assert_eq!(&status[KIND_FIELD], &json!(RECORD_DAMAGED_KIND));
        prop_assert!(has_problem_text(&status), "{}", status);
        prop_assert_eq!(forgotten, Ok(Value::Null));
        prop_assert_eq!(&forgotten_status[PROBLEM_FIELD], &Value::Null);
        prop_assert_eq!(&forgotten_status["account"], &Value::Null);
    }
}
