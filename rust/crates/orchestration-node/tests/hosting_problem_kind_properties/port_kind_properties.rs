use proptest::prelude::*;
use serde_json::{Value, json};

use crate::hosting_problem_steps::{
    HostingFailure, hosting_failure_strategy, read_status_on,
    start_after_failure,
};
use crate::kind_reading::{
    PORT_UNAVAILABLE_KIND, RECORD_DAMAGED_KIND, read_kind, read_problem,
    start_with_port_held,
};
use crate::runtime_steps::start_runtime;
use crate::support::test_device::fail;

const PORT_CASES: u32 = 3;
const MOST_READS: usize = 3;
const PORT_REFUSAL_START: &str = "the app server cannot listen on port ";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PORT_CASES))]

    #[test]
    fn test_describe_failed_start_property_a_taken_port_is_port_unavailable(
        read_count in 1..=MOST_READS,
    ) {
        let failed =
            start_after_failure(&HostingFailure::TakenPort).map_err(fail)?;

        for _ in 0..read_count {
            let status = read_status_on(&failed.runtime).map_err(fail)?;

            prop_assert_eq!(read_kind(&status), json!(PORT_UNAVAILABLE_KIND));
            prop_assert!(status["account"].is_object(), "{}", status);
        }
    }

    #[test]
    fn test_describe_failed_start_property_the_kind_agrees_with_the_text(
        failure in hosting_failure_strategy(),
    ) {
        let failed = start_after_failure(&failure).map_err(fail)?;

        let status = read_status_on(&failed.runtime).map_err(fail)?;

        let problem = read_problem(&status);
        let problem_text = problem.as_str().unwrap_or_default();
        let names_a_port = problem_text.starts_with(PORT_REFUSAL_START);
        let kind = read_kind(&status);
        prop_assert_eq!(kind == json!(PORT_UNAVAILABLE_KIND), names_a_port);
        let is_damage = matches!(failure, HostingFailure::DamagedRecord(_));
        prop_assert_eq!(kind == json!(RECORD_DAMAGED_KIND), is_damage);
    }

    #[test]
    fn test_describe_failed_start_property_a_freed_port_starts_without_a_kind(
        read_count in 1..=MOST_READS,
    ) {
        let failed = start_with_port_held().map_err(fail)?;
        let held_status = read_status_on(&failed.runtime).map_err(fail)?;
        drop(failed.runtime);
        drop(failed.occupier);
        let data_directory = failed.hosted.data_directory.path();

        let restarted =
            start_runtime(data_directory, failed.hosted.port).map_err(fail)?;

        prop_assert_eq!(read_kind(&held_status), json!(PORT_UNAVAILABLE_KIND));
        for _ in 0..read_count {
            let status = read_status_on(&restarted).map_err(fail)?;

            prop_assert_eq!(read_kind(&status), Value::Null);
            prop_assert_eq!(read_problem(&status), Value::Null);
            prop_assert!(status["hosted_server_address"].is_string());
        }
    }
}
