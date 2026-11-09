use orchestration_node::device_files::AppServerRecord;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::damaged_device_records::{
    ACCOUNT_RECORD_NAME, PENDING_JOIN_RECORD_NAME, SERVER_GROUP_RECORD_NAME,
    damaged_device_record_strategy, damaged_server_group_strategy,
    start_with_damaged_device_record,
};
use crate::damaged_server_records::{
    KIND_FIELD, PROBLEM_FIELD, RECORD_DAMAGED_KIND,
    damaged_server_record_strategy, read_status, start_with_damaged_record,
};
use crate::hosting_problem_steps::{
    HostingFailure, damaged_record_strategy, read_status_on,
    start_after_failure,
};
use crate::support::test_device::fail;

const DAMAGE_CASES: u32 = 3;
const HOSTED_RECORD_PROBLEM: &str =
    "the saved hosted server record is damaged";
const SERVER_RECORD_PROBLEM: &str =
    "the saved server address record is damaged";
const ADDRESS_PROBLEM_START: &str = "the server address ";
const GROUP_RECORD_PROBLEM: &str = "the saved server group record is damaged";

fn plain_record_name(file_name: &str) -> &'static str {
    match file_name {
        ACCOUNT_RECORD_NAME => "account",
        SERVER_GROUP_RECORD_NAME => "server group",
        PENDING_JOIN_RECORD_NAME => "pending join",
        _ => "unknown",
    }
}

fn read_problem(status: &Value) -> String {
    status[PROBLEM_FIELD]
        .as_str()
        .unwrap_or_default()
        .to_owned()
}

fn holds_a_server_record(bytes: &[u8]) -> bool {
    serde_json::from_slice::<AppServerRecord>(bytes).is_ok()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DAMAGE_CASES))]

    #[test]
    fn test_load_record_reporting_damage_property_names_the_record(
        damaged in damaged_device_record_strategy(),
    ) {
        let device =
            start_with_damaged_device_record(&damaged).map_err(fail)?;

        let status = read_status(&device).map_err(fail)?;

        let record_name = plain_record_name(damaged.record_name);
        let expected = format!("the saved {record_name} record is damaged");
        prop_assert_eq!(read_problem(&status), expected);
        prop_assert_eq!(&status[KIND_FIELD], &json!(RECORD_DAMAGED_KIND));
    }

    #[test]
    fn test_describe_failed_start_property_names_a_damaged_hosted_record(
        damaged_bytes in damaged_record_strategy(),
    ) {
        let failure = HostingFailure::DamagedRecord(damaged_bytes);
        let failed = start_after_failure(&failure).map_err(fail)?;

        let status = read_status_on(&failed.runtime).map_err(fail)?;

        prop_assert_eq!(read_problem(&status), HOSTED_RECORD_PROBLEM);
        prop_assert_eq!(&status[KIND_FIELD], &json!(RECORD_DAMAGED_KIND));
    }

    #[test]
    fn test_describe_failed_start_property_names_a_damaged_server_record(
        damaged_bytes in damaged_server_record_strategy(),
    ) {
        let device = start_with_damaged_record(&damaged_bytes).map_err(fail)?;

        let status = read_status(&device).map_err(fail)?;

        let problem = read_problem(&status);
        if holds_a_server_record(&damaged_bytes) {
            let names_the_address = problem.starts_with(ADDRESS_PROBLEM_START);
            prop_assert!(names_the_address, "{}", problem);
        } else {
            prop_assert_eq!(problem, SERVER_RECORD_PROBLEM);
        }
        prop_assert_eq!(&status[KIND_FIELD], &json!(RECORD_DAMAGED_KIND));
    }

    #[test]
    fn test_describe_failed_start_property_names_a_damaged_group_at_start(
        damaged in damaged_server_group_strategy(),
    ) {
        let device =
            start_with_damaged_device_record(&damaged).map_err(fail)?;

        let status = read_status(&device).map_err(fail)?;

        prop_assert_eq!(read_problem(&status), GROUP_RECORD_PROBLEM);
        prop_assert_eq!(&status[KIND_FIELD], &json!(RECORD_DAMAGED_KIND));
    }
}
