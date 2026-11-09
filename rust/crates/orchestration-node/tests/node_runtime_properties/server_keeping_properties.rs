use std::collections::BTreeSet;
use std::path::Path;
use std::thread;
use std::time::Duration;

use orchestration_core::peer_address::PeerAddress;
use orchestration_node::node_runtime::NodeRuntime;
use proptest::prelude::*;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::hosting_accessor_properties::read_peer_address;
use crate::hosting_problem_steps::{forget_device_on, read_status_on};
use crate::runtime_steps::{host_on, start_runtime};
use crate::support::hosting_steps::pick_free_port;
use crate::support::test_device::{describe, fail};

const KEEPING_CASES: u32 = 2;
const MOST_RESTARTS: usize = 3;
const MOST_TAKEOVER_SECONDS: u64 = 120;
const ACTIVE_STANDING: &str = "active";
const NO_STANDING: &str = "none";
const KEEPER_PAUSE: Duration = Duration::from_millis(1_500);

fn start_keeping_runtime(
    data_directory: &Path,
    port: u16,
    takeover_seconds: u64,
) -> Result<NodeRuntime, String> {
    let configuration = json!({
        "data_directory": data_directory,
        "identity_store": "file",
        "peer_relay": "disabled",
        "runner": "off",
        "app_server_port": port,
        "server_takeover_seconds": takeover_seconds,
    });
    NodeRuntime::start(&configuration.to_string()).map_err(describe)
}

fn read_standing(status: &Value) -> Value {
    status["app_servers"]["this_device"].clone()
}

fn list_active_servers(status: &Value) -> Vec<Value> {
    let servers = status["app_servers"]["servers"].as_array();
    let mut active = Vec::new();
    for server in servers.into_iter().flatten() {
        if server["standing"] == json!(ACTIVE_STANDING) {
            active.push(server["device_id"].clone());
        }
    }
    active
}

fn list_ports(address: &PeerAddress) -> BTreeSet<u16> {
    let mut ports = BTreeSet::new();
    for direct_address in &address.direct_addresses {
        ports.insert(direct_address.port());
    }
    ports
}

fn read_hosted_peer_address(
    status: &Value,
) -> Result<PeerAddress, TestCaseError> {
    let hosted_text = status["hosted_server_address"].as_str();
    let hosted_text =
        hosted_text.ok_or_else(|| TestCaseError::fail("nothing is hosted"))?;
    read_peer_address(hosted_text)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(KEEPING_CASES))]

    #[test]
    fn test_peer_relay_property_a_disabled_relay_names_no_relay(
        _seed in any::<u8>(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let runtime =
            start_runtime(data_directory.path(), port).map_err(fail)?;
        host_on(&runtime).map_err(fail)?;

        let status = read_status_on(&runtime).map_err(fail)?;

        let hosted = read_hosted_peer_address(&status)?;
        prop_assert_eq!(hosted.relay_url, None);
        prop_assert!(!hosted.direct_addresses.is_empty());
    }

    #[test]
    fn test_peer_relay_property_restarts_keep_the_hosted_endpoint(
        restart_count in 1..=MOST_RESTARTS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let first = start_runtime(data_directory.path(), port).map_err(fail)?;
        host_on(&first).map_err(fail)?;
        let first_hosted =
            read_hosted_peer_address(&read_status_on(&first).map_err(fail)?)?;
        drop(first);

        for _ in 0..restart_count {
            let runtime =
                start_runtime(data_directory.path(), port).map_err(fail)?;
            let status = read_status_on(&runtime).map_err(fail)?;
            let hosted = read_hosted_peer_address(&status)?;
            prop_assert_eq!(
                hosted.endpoint_public_key,
                first_hosted.endpoint_public_key
            );
            prop_assert_eq!(hosted.relay_url, None);
        }
    }

    #[test]
    fn test_peer_relay_property_restarts_keep_the_hosted_ports(
        restart_count in 1..=MOST_RESTARTS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let first = start_runtime(data_directory.path(), port).map_err(fail)?;
        host_on(&first).map_err(fail)?;
        let first_hosted =
            read_hosted_peer_address(&read_status_on(&first).map_err(fail)?)?;
        drop(first);

        let first_ports = list_ports(&first_hosted);
        for _ in 0..restart_count {
            let runtime =
                start_runtime(data_directory.path(), port).map_err(fail)?;
            let status = read_status_on(&runtime).map_err(fail)?;
            let hosted = read_hosted_peer_address(&status)?;
            prop_assert_eq!(list_ports(&hosted), first_ports.clone());
        }
    }

    #[test]
    fn test_takeover_after_property_a_lone_server_stays_active(
        takeover_seconds in 0..MOST_TAKEOVER_SECONDS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let data_path = data_directory.path();
        let runtime = start_keeping_runtime(data_path, port, takeover_seconds)
            .map_err(fail)?;
        host_on(&runtime).map_err(fail)?;

        thread::sleep(KEEPER_PAUSE);
        let status = read_status_on(&runtime).map_err(fail)?;

        prop_assert_eq!(read_standing(&status), json!(ACTIVE_STANDING));
        prop_assert_eq!(&status["hosting_problem"], &Value::Null);
    }

    #[test]
    fn test_takeover_after_property_a_new_value_keeps_the_server_active(
        first_seconds in 0..MOST_TAKEOVER_SECONDS,
        second_seconds in 0..MOST_TAKEOVER_SECONDS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let first =
            start_keeping_runtime(data_directory.path(), port, first_seconds)
                .map_err(fail)?;
        host_on(&first).map_err(fail)?;
        drop(first);

        let second =
            start_keeping_runtime(data_directory.path(), port, second_seconds)
                .map_err(fail)?;
        thread::sleep(KEEPER_PAUSE);
        let status = read_status_on(&second).map_err(fail)?;

        prop_assert_eq!(read_standing(&status), json!(ACTIVE_STANDING));
        prop_assert_eq!(&status["hosting_problem"], &Value::Null);
    }

    #[test]
    fn test_takeover_after_property_the_group_names_one_active_server(
        takeover_seconds in 0..MOST_TAKEOVER_SECONDS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let data_path = data_directory.path();
        let runtime = start_keeping_runtime(data_path, port, takeover_seconds)
            .map_err(fail)?;
        host_on(&runtime).map_err(fail)?;

        thread::sleep(KEEPER_PAUSE);
        let status = read_status_on(&runtime).map_err(fail)?;

        let own_id = status["device_id"].clone();
        prop_assert_eq!(list_active_servers(&status), vec![own_id]);
    }

    #[test]
    fn test_shared_server_dialer_property_hosting_keeps_the_group(
        status_count in 1..=MOST_RESTARTS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let runtime =
            start_runtime(data_directory.path(), port).map_err(fail)?;
        host_on(&runtime).map_err(fail)?;

        for _ in 0..status_count {
            let status = read_status_on(&runtime).map_err(fail)?;
            let own_id = status["device_id"].clone();
            prop_assert_eq!(list_active_servers(&status), vec![own_id]);
            prop_assert_eq!(&status["server_reachable"], &json!(true));
        }
    }

    #[test]
    fn test_shared_server_dialer_property_restarts_keep_the_group_again(
        restart_count in 1..=MOST_RESTARTS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let first = start_runtime(data_directory.path(), port).map_err(fail)?;
        host_on(&first).map_err(fail)?;
        let first_status = read_status_on(&first).map_err(fail)?;
        drop(first);

        for _ in 0..restart_count {
            let runtime =
                start_runtime(data_directory.path(), port).map_err(fail)?;
            let status = read_status_on(&runtime).map_err(fail)?;
            prop_assert_eq!(
                list_active_servers(&status),
                list_active_servers(&first_status)
            );
        }
    }

    #[test]
    fn test_shared_server_dialer_property_forgetting_stops_keeping(
        _seed in any::<u8>(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let runtime =
            start_runtime(data_directory.path(), port).map_err(fail)?;
        host_on(&runtime).map_err(fail)?;

        forget_device_on(&runtime).map_err(fail)?;
        thread::sleep(KEEPER_PAUSE);
        let status = read_status_on(&runtime).map_err(fail)?;

        prop_assert_eq!(read_standing(&status), json!(NO_STANDING));
        prop_assert!(list_active_servers(&status).is_empty());
        prop_assert_eq!(&status["server_address"], &Value::Null);
    }
}
