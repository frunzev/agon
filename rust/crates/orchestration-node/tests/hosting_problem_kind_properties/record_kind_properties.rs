use proptest::prelude::*;
use serde_json::{Value, json};

use crate::hosting_problem_steps::{damaged_record_strategy, read_status_on};
use crate::kind_reading::{
    RECORD_DAMAGED_KIND, SERVER_FAILED_KIND, read_kind, read_problem,
    start_with_record_as_folder, start_with_record_bytes,
};
use crate::support::test_device::fail;

const RECORD_CASES: u32 = 3;
const MOST_READS: usize = 3;
const FIRST_PORT_BEYOND_RANGE: i64 = 65_536;

fn port_beyond_range_strategy() -> impl Strategy<Value = i64> {
    prop_oneof![FIRST_PORT_BEYOND_RANGE..=i64::MAX, i64::MIN..0_i64]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RECORD_CASES))]

    #[test]
    fn test_describe_unreadable_record_property_damage_names_record_damaged(
        damaged_bytes in damaged_record_strategy(),
    ) {
        let failed = start_with_record_bytes(&damaged_bytes).map_err(fail)?;

        let status = read_status_on(&failed.runtime).map_err(fail)?;

        prop_assert_eq!(read_kind(&status), json!(RECORD_DAMAGED_KIND));
        let problem = read_problem(&status);
        let problem_text = problem.as_str().unwrap_or_default();
        prop_assert!(!problem_text.is_empty(), "{}", status);
    }

    #[test]
    fn test_describe_unreadable_record_property_a_port_beyond_range_is_damage(
        port_number in port_beyond_range_strategy(),
    ) {
        let record = json!({ "port": port_number }).to_string();
        let failed =
            start_with_record_bytes(record.as_bytes()).map_err(fail)?;

        let status = read_status_on(&failed.runtime).map_err(fail)?;

        prop_assert_eq!(read_kind(&status), json!(RECORD_DAMAGED_KIND));
        prop_assert_eq!(&status["hosted_server_address"], &Value::Null);
    }

    #[test]
    fn test_describe_unreadable_record_property_unopenable_is_not_damage(
        read_count in 1..=MOST_READS,
    ) {
        let failed = start_with_record_as_folder().map_err(fail)?;

        for _ in 0..read_count {
            let status = read_status_on(&failed.runtime).map_err(fail)?;

            prop_assert_eq!(read_kind(&status), json!(SERVER_FAILED_KIND));
            prop_assert!(read_problem(&status).is_string(), "{}", status);
        }
    }
}
