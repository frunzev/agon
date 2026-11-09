use std::fs;

use orchestration_core::peer_address::PeerAddress;
use orchestration_node::device_files::HostedServerRecord;
use orchestration_node::server_address::ServerAddress;
use proptest::prelude::*;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::hosting_problem_steps::{forget_device_on, read_status_on};
use crate::runtime_steps::{host_on, hosted_record_in, start_runtime};
use crate::support::hosting_steps::{
    create_hosted_account, pick_free_port, read_hosted_address, read_status,
    start_hosting_device,
};
use crate::support::test_device::{TestDevice, fail};

const HOSTING_CASES: u32 = 2;
const MOST_REPEATS: usize = 3;

pub fn read_peer_address(
    hosted_text: &str,
) -> Result<PeerAddress, TestCaseError> {
    match ServerAddress::parse(hosted_text).map_err(fail)? {
        ServerAddress::Peer(peer_address) => Ok(peer_address),
        ServerAddress::Web(web_address) => {
            let problem = format!("not a peer address: {web_address}");
            Err(TestCaseError::fail(problem))
        }
    }
}

fn read_record_port(data_directory: &TempDir) -> Result<u16, TestCaseError> {
    let record_path = hosted_record_in(data_directory.path());
    let record_text = fs::read_to_string(record_path).map_err(fail)?;
    let record: HostedServerRecord =
        serde_json::from_str(&record_text).map_err(fail)?;
    Ok(record.port)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HOSTING_CASES))]

    #[test]
    fn test_app_server_port_property_the_record_keeps_the_configured_port(
        _seed in any::<u8>(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let runtime =
            start_runtime(data_directory.path(), port).map_err(fail)?;

        host_on(&runtime).map_err(fail)?;

        prop_assert_eq!(read_record_port(&data_directory)?, port);
        let status = read_status_on(&runtime).map_err(fail)?;
        let expected = json!(format!("http://127.0.0.1:{port}"));
        prop_assert_eq!(&status["server_address"], &expected);
    }

    #[test]
    fn test_app_server_port_property_each_device_keeps_its_own_port(
        device_count in 2..=MOST_REPEATS,
    ) {
        let mut hosted = Vec::new();
        for _ in 0..device_count {
            let data_directory = TempDir::new().map_err(fail)?;
            let port = pick_free_port().map_err(fail)?;
            let runtime =
                start_runtime(data_directory.path(), port).map_err(fail)?;
            host_on(&runtime).map_err(fail)?;
            hosted.push((data_directory, port, runtime));
        }

        for (data_directory, port, _runtime) in &hosted {
            prop_assert_eq!(read_record_port(data_directory)?, *port);
        }
    }

    #[test]
    fn test_app_server_port_property_restarting_serves_the_same_port(
        restart_count in 1..=MOST_REPEATS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let first = start_runtime(data_directory.path(), port).map_err(fail)?;
        host_on(&first).map_err(fail)?;
        drop(first);

        for _ in 0..restart_count {
            let runtime =
                start_runtime(data_directory.path(), port).map_err(fail)?;
            let status = read_status_on(&runtime).map_err(fail)?;
            prop_assert_eq!(&status["server_reachable"], &json!(true));
            prop_assert_eq!(read_record_port(&data_directory)?, port);
        }
    }

    #[test]
    fn test_hosted_server_address_property_a_plain_device_hosts_nothing(
        status_count in 1..=MOST_REPEATS,
    ) {
        let device = TestDevice::start().map_err(fail)?;

        for _ in 0..status_count {
            let status = read_status(&device).map_err(fail)?;
            prop_assert_eq!(&status["hosted_server_address"], &Value::Null);
        }
    }

    #[test]
    fn test_hosted_server_address_property_is_a_steady_peer_address(
        status_count in 1..=MOST_REPEATS,
    ) {
        let hosting = start_hosting_device().map_err(fail)?;
        let first = read_hosted_address(&hosting.device).map_err(fail)?;

        for _ in 0..status_count {
            let repeated = read_hosted_address(&hosting.device).map_err(fail)?;
            prop_assert_eq!(&repeated, &first);
        }
        let peer_address = read_peer_address(&first)?;
        prop_assert!(!peer_address.direct_addresses.is_empty());
    }

    #[test]
    fn test_hosted_server_address_property_forgetting_clears_it(
        _seed in any::<u8>(),
    ) {
        let hosting = start_hosting_device().map_err(fail)?;

        hosting
            .device
            .run(&json!({ "command": "forget_this_device" }))
            .map_err(fail)?;

        let status = read_status(&hosting.device).map_err(fail)?;
        prop_assert_eq!(&status["hosted_server_address"], &Value::Null);
    }

    #[test]
    fn test_lock_hosted_app_server_property_hosting_again_is_refused_once(
        _seed in any::<u8>(),
    ) {
        let hosting = start_hosting_device().map_err(fail)?;
        let first = read_hosted_address(&hosting.device).map_err(fail)?;

        let again = create_hosted_account(&hosting.device);

        prop_assert!(again.is_err(), "{:?}", again);
        let kept = read_hosted_address(&hosting.device).map_err(fail)?;
        prop_assert_eq!(kept, first);
    }

    #[test]
    fn test_lock_hosted_app_server_property_forgetting_frees_the_slot(
        _seed in any::<u8>(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let runtime =
            start_runtime(data_directory.path(), port).map_err(fail)?;
        host_on(&runtime).map_err(fail)?;
        let first = read_status_on(&runtime).map_err(fail)?;

        forget_device_on(&runtime).map_err(fail)?;
        host_on(&runtime).map_err(fail)?;
        let second = read_status_on(&runtime).map_err(fail)?;

        let first_address = first["hosted_server_address"].as_str();
        let second_address = second["hosted_server_address"].as_str();
        prop_assert!(second_address.is_some());
        prop_assert_ne!(first_address, second_address);
    }

    #[test]
    fn test_lock_hosted_app_server_property_restarts_fill_the_slot_again(
        restart_count in 1..=MOST_REPEATS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let first = start_runtime(data_directory.path(), port).map_err(fail)?;
        host_on(&first).map_err(fail)?;
        drop(first);

        for _ in 0..restart_count {
            let runtime =
                start_runtime(data_directory.path(), port).map_err(fail)?;
            let status = read_status_on(&runtime).map_err(fail)?;
            prop_assert!(status["hosted_server_address"].is_string());
            prop_assert_eq!(&status["hosting_problem"], &Value::Null);
        }
    }
}
