use orchestration_node::device_files::DeviceFiles;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::Index;
use serde_json::{Value, json};

use crate::device_folder::{
    HOSTED_SERVER_FILE_NAME, RECORD_FILE_NAMES, SERVER_FILE_NAME,
};
use crate::record_checks::{
    check_half_written_file_is_refused, check_last_save_wins,
    check_only_its_file_is_written, check_round_trip,
    check_unrelated_files_load_nothing, check_wrong_shape_is_refused,
};
use crate::record_strategies::{
    app_server_strategy, hosted_server_strategy, wrong_shape_strategy,
};

const CASE_COUNT: u32 = 32;
const MOST_SAVES: usize = 6;
const LONGEST_UNRELATED_CONTENT: usize = 64;
const FIRST_PORT_BEYOND_RANGE: i64 = 65_536;

fn unrelated_name_strategy() -> impl Strategy<Value = &'static str> {
    prop::sample::select(RECORD_FILE_NAMES.to_vec())
}

fn unrelated_content_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..LONGEST_UNRELATED_CONTENT)
}

fn wrong_port_strategy() -> impl Strategy<Value = Value> {
    prop_oneof![
        (FIRST_PORT_BEYOND_RANGE..i64::MAX)
            .prop_map(|port| json!({ "port": port })),
        (i64::MIN..0).prop_map(|port| json!({ "port": port })),
        any::<f64>().prop_map(|port| json!({ "port": port + 0.5 })),
        any::<String>().prop_map(|port| json!({ "port": port })),
        wrong_shape_strategy(),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CASE_COUNT))]

    #[test]
    fn test_save_app_server_property_loads_back_after_reopening(
        app_server in app_server_strategy(),
    ) {
        check_round_trip(
            DeviceFiles::save_app_server,
            DeviceFiles::load_app_server,
            &app_server,
        )?;
    }

    #[test]
    fn test_save_app_server_property_the_last_save_wins(
        app_servers in vec(app_server_strategy(), 1..MOST_SAVES),
    ) {
        check_last_save_wins(
            DeviceFiles::save_app_server,
            DeviceFiles::load_app_server,
            &app_servers,
        )?;
    }

    #[test]
    fn test_save_app_server_property_writes_only_its_json_file(
        app_server in app_server_strategy(),
    ) {
        check_only_its_file_is_written(
            DeviceFiles::save_app_server,
            &app_server,
            SERVER_FILE_NAME,
        )?;
    }

    #[test]
    fn test_load_app_server_property_other_files_load_nothing(
        unrelated_name in unrelated_name_strategy(),
        unrelated_content in unrelated_content_strategy(),
    ) {
        prop_assume!(unrelated_name != SERVER_FILE_NAME);
        check_unrelated_files_load_nothing(
            DeviceFiles::load_app_server,
            unrelated_name,
            &unrelated_content,
        )?;
    }

    #[test]
    fn test_load_app_server_property_a_half_written_file_is_refused(
        app_server in app_server_strategy(),
        cut in any::<Index>(),
    ) {
        check_half_written_file_is_refused(
            DeviceFiles::load_app_server,
            &app_server,
            SERVER_FILE_NAME,
            cut,
        )?;
    }

    #[test]
    fn test_load_app_server_property_a_wrong_shape_is_refused(
        wrong_shape in wrong_shape_strategy(),
    ) {
        check_wrong_shape_is_refused(
            DeviceFiles::load_app_server,
            SERVER_FILE_NAME,
            &wrong_shape,
        )?;
    }

    #[test]
    fn test_save_hosted_server_property_loads_back_after_reopening(
        hosted_server in hosted_server_strategy(),
    ) {
        check_round_trip(
            DeviceFiles::save_hosted_server,
            DeviceFiles::load_hosted_server,
            &hosted_server,
        )?;
    }

    #[test]
    fn test_save_hosted_server_property_the_last_save_wins(
        hosted_servers in vec(hosted_server_strategy(), 1..MOST_SAVES),
    ) {
        check_last_save_wins(
            DeviceFiles::save_hosted_server,
            DeviceFiles::load_hosted_server,
            &hosted_servers,
        )?;
    }

    #[test]
    fn test_save_hosted_server_property_writes_only_its_json_file(
        hosted_server in hosted_server_strategy(),
    ) {
        check_only_its_file_is_written(
            DeviceFiles::save_hosted_server,
            &hosted_server,
            HOSTED_SERVER_FILE_NAME,
        )?;
    }

    #[test]
    fn test_load_hosted_server_property_other_files_load_nothing(
        unrelated_name in unrelated_name_strategy(),
        unrelated_content in unrelated_content_strategy(),
    ) {
        prop_assume!(unrelated_name != HOSTED_SERVER_FILE_NAME);
        check_unrelated_files_load_nothing(
            DeviceFiles::load_hosted_server,
            unrelated_name,
            &unrelated_content,
        )?;
    }

    #[test]
    fn test_load_hosted_server_property_a_half_written_file_is_refused(
        hosted_server in hosted_server_strategy(),
        cut in any::<Index>(),
    ) {
        check_half_written_file_is_refused(
            DeviceFiles::load_hosted_server,
            &hosted_server,
            HOSTED_SERVER_FILE_NAME,
            cut,
        )?;
    }

    #[test]
    fn test_load_hosted_server_property_a_port_outside_range_is_refused(
        wrong_port in wrong_port_strategy(),
    ) {
        check_wrong_shape_is_refused(
            DeviceFiles::load_hosted_server,
            HOSTED_SERVER_FILE_NAME,
            &wrong_port,
        )?;
    }
}
