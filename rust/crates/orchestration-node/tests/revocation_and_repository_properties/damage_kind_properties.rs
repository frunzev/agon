use std::fs;

use proptest::prelude::*;
use serde_json::Value;

use crate::damaged_hosting_steps::{
    RECORD_DAMAGED_KIND, SERVER_FAILED_KIND, SERVER_KEY_FILE_NAME,
    STATE_FILE_NAME, damaged_hosted_bytes_strategy, hosted_file_strategy,
    read_kind_text, read_problem_text, start_with_file_bytes,
    start_with_folder_instead_of,
};
use crate::hosting_problem_steps::{forget_device_on, has_hosted_files};
use crate::support::test_device::fail;

const DAMAGE_CASES: u32 = 4;
const FAILED_PREFIX: &str = "the app server on this device failed: ";
const DAMAGED_TEXT: &str = "damaged";
const SERVER_FILE_NAMES: [&str; 2] = [SERVER_KEY_FILE_NAME, STATE_FILE_NAME];

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DAMAGE_CASES))]

    #[test]
    fn test_describe_failed_start_property_damaged_hosted_files_offer_set_up(
        file_name in hosted_file_strategy(),
        damaged_bytes in damaged_hosted_bytes_strategy(),
    ) {
        let damaged =
            start_with_file_bytes(file_name, &damaged_bytes).map_err(fail)?;

        let status = damaged.read_status().map_err(fail)?;

        prop_assert_eq!(read_kind_text(&status), RECORD_DAMAGED_KIND);
        prop_assert!(!read_problem_text(&status).is_empty(), "{}", status);
    }

    #[test]
    fn test_describe_failed_start_property_setting_up_again_clears_damage(
        file_name in hosted_file_strategy(),
        damaged_bytes in damaged_hosted_bytes_strategy(),
    ) {
        let damaged =
            start_with_file_bytes(file_name, &damaged_bytes).map_err(fail)?;

        forget_device_on(&damaged.runtime).map_err(fail)?;
        let status = damaged.read_status().map_err(fail)?;

        prop_assert_eq!(&status["account"], &Value::Null);
        prop_assert_eq!(&status["hosting_problem"], &Value::Null);
        prop_assert_eq!(&status["hosting_problem_kind"], &Value::Null);
        prop_assert!(!has_hosted_files(&damaged.hosted));
    }

    #[test]
    fn test_describe_failed_start_property_an_unopenable_file_is_not_damage(
        file_name in hosted_file_strategy(),
    ) {
        let failed = start_with_folder_instead_of(file_name).map_err(fail)?;

        let status = failed.read_status().map_err(fail)?;

        prop_assert_eq!(read_kind_text(&status), SERVER_FAILED_KIND);
        prop_assert!(!read_problem_text(&status).is_empty(), "{}", status);
    }

    #[test]
    fn test_hosted_app_server_start_property_a_damaged_key_is_kept(
        damaged_bytes in damaged_hosted_bytes_strategy(),
    ) {
        let damaged =
            start_with_file_bytes(SERVER_KEY_FILE_NAME, &damaged_bytes)
                .map_err(fail)?;

        let status = damaged.read_status().map_err(fail)?;
        let key_after =
            fs::read(damaged.path_of(SERVER_KEY_FILE_NAME)).map_err(fail)?;

        prop_assert_eq!(read_kind_text(&status), RECORD_DAMAGED_KIND);
        prop_assert_eq!(key_after, damaged_bytes);
    }

    #[test]
    fn test_hosted_app_server_start_property_a_damaged_state_is_kept(
        damaged_bytes in damaged_hosted_bytes_strategy(),
    ) {
        let damaged = start_with_file_bytes(STATE_FILE_NAME, &damaged_bytes)
            .map_err(fail)?;

        let status = damaged.read_status().map_err(fail)?;
        let state_after =
            fs::read(damaged.path_of(STATE_FILE_NAME)).map_err(fail)?;

        prop_assert_eq!(read_kind_text(&status), RECORD_DAMAGED_KIND);
        prop_assert_eq!(state_after, damaged_bytes);
    }

    #[test]
    fn test_hosted_app_server_start_property_damage_keeps_the_failed_text(
        file_name in prop::sample::select(SERVER_FILE_NAMES.to_vec()),
        damaged_bytes in damaged_hosted_bytes_strategy(),
    ) {
        let damaged =
            start_with_file_bytes(file_name, &damaged_bytes).map_err(fail)?;

        let status = damaged.read_status().map_err(fail)?;
        let problem = read_problem_text(&status);

        prop_assert!(problem.starts_with(FAILED_PREFIX), "{problem}");
        prop_assert!(problem.contains(DAMAGED_TEXT), "{problem}");
    }
}
