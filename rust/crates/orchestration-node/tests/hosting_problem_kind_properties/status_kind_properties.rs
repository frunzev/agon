use proptest::prelude::*;
use serde_json::Value;
use tempfile::TempDir;

use crate::hosting_problem_steps::{
    forget_device_on, has_hosted_files, hosting_failure_strategy,
    read_status_on, start_after_failure,
};
use crate::kind_reading::{
    DeviceStage, KIND_FIELD, KNOWN_KINDS, read_kind, read_problem,
    read_status_at_stage,
};
use crate::runtime_steps::start_runtime;
use crate::support::hosting_steps::pick_free_port;
use crate::support::test_device::{describe, fail};

const STATUS_CASES: u32 = 3;
const MOST_READS: usize = 3;
const MOST_RESTARTS: usize = 3;

fn device_stage_strategy() -> impl Strategy<Value = DeviceStage> {
    prop_oneof![
        Just(DeviceStage::Fresh),
        Just(DeviceStage::HealthyHost),
        Just(DeviceStage::TakenPort),
        Just(DeviceStage::DamagedRecord),
    ]
}

fn names_a_known_kind(kind: &Value) -> bool {
    let kind_text = kind.as_str().unwrap_or_default();
    KNOWN_KINDS.contains(&kind_text)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STATUS_CASES))]

    #[test]
    fn test_describe_status_property_kind_and_problem_come_together(
        stage in device_stage_strategy(),
    ) {
        let status = read_status_at_stage(stage).map_err(fail)?;

        let has_kind = !read_kind(&status).is_null();
        let has_problem = !read_problem(&status).is_null();
        prop_assert!(status.get(KIND_FIELD).is_some(), "{}", status);
        prop_assert_eq!(has_kind, has_problem, "{}", status);
    }

    #[test]
    fn test_describe_status_property_a_failure_names_a_known_kind(
        failure in hosting_failure_strategy(),
    ) {
        let failed = start_after_failure(&failure).map_err(fail)?;

        let status = read_status_on(&failed.runtime).map_err(fail)?;

        prop_assert!(names_a_known_kind(&read_kind(&status)), "{}", status);
    }

    #[test]
    fn test_forget_hosting_problem_property_forgetting_clears_the_kind(
        failure in hosting_failure_strategy(),
    ) {
        let failed = start_after_failure(&failure).map_err(fail)?;

        let forgotten = forget_device_on(&failed.runtime);
        let status = read_status_on(&failed.runtime).map_err(fail)?;

        prop_assert!(forgotten.is_ok(), "{:?}", forgotten);
        prop_assert_eq!(read_kind(&status), Value::Null);
        prop_assert_eq!(read_problem(&status), Value::Null);
    }

    #[test]
    fn test_record_hosting_problem_property_the_kind_stays_put(
        failure in hosting_failure_strategy(),
        read_count in 1..=MOST_READS,
    ) {
        let failed = start_after_failure(&failure).map_err(fail)?;
        let first_status = read_status_on(&failed.runtime).map_err(fail)?;
        let first_kind = read_kind(&first_status);

        for _ in 0..read_count {
            let status = read_status_on(&failed.runtime).map_err(fail)?;

            prop_assert_eq!(read_kind(&status), first_kind.clone());
        }
        prop_assert!(names_a_known_kind(&first_kind), "{}", first_status);
    }

    #[test]
    fn test_restart_recorded_app_server_property_no_record_names_no_kind(
        restart_count in 1..=MOST_RESTARTS,
    ) {
        let data_directory = TempDir::new().map_err(describe).map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;

        for _ in 0..restart_count {
            let runtime =
                start_runtime(data_directory.path(), port).map_err(fail)?;
            let status = read_status_on(&runtime).map_err(fail)?;

            prop_assert_eq!(read_kind(&status), Value::Null);
            prop_assert_eq!(read_problem(&status), Value::Null);
        }
    }

    #[test]
    fn test_restart_off_the_calling_thread_property_failure_keeps_the_data(
        failure in hosting_failure_strategy(),
    ) {
        let failed = start_after_failure(&failure).map_err(fail)?;

        let status = read_status_on(&failed.runtime).map_err(fail)?;

        prop_assert!(!read_kind(&status).is_null(), "{}", status);
        prop_assert!(has_hosted_files(&failed.hosted));
        prop_assert!(status["account"].is_object(), "{}", status);
    }
}
