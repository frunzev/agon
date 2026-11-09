use std::fs;

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::damaged_device_records::{
    damaged_account_strategy, damaged_device_record_strategy,
    damaged_pending_join_strategy, damaged_server_group_strategy,
    start_with_damaged_device_record,
};
use crate::damaged_server_records::{
    KIND_FIELD, PROBLEM_FIELD, RECORD_DAMAGED_KIND, forget_device,
    read_status, set_up_again,
};
use crate::hosting_problem_steps::{
    forget_device_on, prepare_hosted_data, read_status_on,
};
use crate::runtime_steps::start_runtime;
use crate::support::test_device::fail;

const DAMAGE_CASES: u32 = 3;

fn has_problem_text(status: &Value) -> bool {
    status[PROBLEM_FIELD]
        .as_str()
        .is_some_and(|problem| !problem.trim().is_empty())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DAMAGE_CASES))]

    #[test]
    fn test_load_record_reporting_damage_property_a_damaged_account_shows(
        damaged in damaged_account_strategy(),
    ) {
        let device =
            start_with_damaged_device_record(&damaged).map_err(fail)?;

        let status = read_status(&device).map_err(fail)?;

        prop_assert_eq!(&status[KIND_FIELD], &json!(RECORD_DAMAGED_KIND));
        prop_assert!(has_problem_text(&status), "{}", status);
        prop_assert_eq!(&status["account"], &Value::Null);
    }

    #[test]
    fn test_load_record_reporting_damage_property_a_damaged_group_shows(
        damaged in damaged_server_group_strategy(),
    ) {
        let device =
            start_with_damaged_device_record(&damaged).map_err(fail)?;

        let status = read_status(&device).map_err(fail)?;

        prop_assert_eq!(&status[KIND_FIELD], &json!(RECORD_DAMAGED_KIND));
        prop_assert!(has_problem_text(&status), "{}", status);
        prop_assert!(status["account"].is_object(), "{}", status);
    }

    #[test]
    fn test_load_record_reporting_damage_property_forgetting_sets_up_again(
        damaged in damaged_device_record_strategy(),
    ) {
        let device =
            start_with_damaged_device_record(&damaged).map_err(fail)?;

        let damaged_status = read_status(&device).map_err(fail)?;
        let forgotten = forget_device(&device);
        let forgotten_status = read_status(&device).map_err(fail)?;
        let fresh_server = set_up_again(&device).map_err(fail)?;
        let fresh_status = read_status(&device).map_err(fail)?;

        prop_assert_eq!(
            &damaged_status[KIND_FIELD],
            &json!(RECORD_DAMAGED_KIND)
        );
        prop_assert_eq!(forgotten, Ok(Value::Null));
        prop_assert_eq!(&forgotten_status[PROBLEM_FIELD], &Value::Null);
        prop_assert_eq!(&forgotten_status[KIND_FIELD], &Value::Null);
        prop_assert_eq!(&forgotten_status["account"], &Value::Null);
        prop_assert!(fresh_status["account"].is_object(), "{}", fresh_status);
        prop_assert_eq!(&fresh_status[PROBLEM_FIELD], &Value::Null);
        drop(fresh_server);
    }

    #[test]
    fn test_load_record_reporting_damage_property_a_damaged_join_shows(
        damaged in damaged_pending_join_strategy(),
    ) {
        let device =
            start_with_damaged_device_record(&damaged).map_err(fail)?;

        let status = read_status(&device).map_err(fail)?;

        prop_assert_eq!(&status[KIND_FIELD], &json!(RECORD_DAMAGED_KIND));
        prop_assert!(has_problem_text(&status), "{}", status);
        prop_assert_eq!(&status["pending_join"], &Value::Null);
        prop_assert!(status["account"].is_object(), "{}", status);
    }

    #[test]
    fn test_load_record_reporting_damage_property_a_hosting_computer_too(
        damaged in damaged_device_record_strategy(),
    ) {
        let hosted = prepare_hosted_data().map_err(fail)?;
        let data_directory = hosted.data_directory.path();
        let record_path = data_directory.join(damaged.record_name);
        fs::write(record_path, &damaged.damaged_bytes).map_err(fail)?;

        let runtime =
            start_runtime(data_directory, hosted.port).map_err(fail)?;
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
