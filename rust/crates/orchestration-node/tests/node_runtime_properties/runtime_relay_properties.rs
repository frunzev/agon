use std::fs;
use std::net::{Ipv4Addr, SocketAddr, UdpSocket};
use std::time::{Duration, Instant};

use orchestration_core::peer_address::PeerAddress;
use orchestration_node::device_files::AppServerRecord;
use orchestration_node::node_runtime::NodeRuntime;
use orchestration_node::server_address::ServerAddress;
use proptest::prelude::*;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::damaged_server_records::server_record_in;
use crate::fake_runner::{FakeRunner, RunnerAnswer};
use crate::hosting_problem_steps::read_status_on;
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

const RELAY_CASES: u32 = 2;
const MOST_RESTARTS: usize = 3;
const DROP_LIMIT: Duration = Duration::from_secs(6);
const PEER_CONNECT_LIMIT: Duration = Duration::from_secs(10);
const DIAL_SLACK: Duration = Duration::from_secs(10);
const INVALID_RELAY_PATTERN: &str = "[a-z]{1,12}";
const WORKSPACE_NAME: &str = "acme";

fn start_with_relay(
    data_directory: &TempDir,
    peer_relay: &Value,
) -> Result<NodeRuntime, String> {
    let configuration = json!({
        "data_directory": data_directory.path(),
        "identity_store": "file",
        "peer_relay": peer_relay,
        "runner": "off",
    });
    NodeRuntime::start(&configuration.to_string())
        .map_err(|problem| problem.to_string())
}

fn free_udp_port() -> Result<u16, TestCaseError> {
    let socket = UdpSocket::bind((Ipv4Addr::LOCALHOST, 0)).map_err(fail)?;
    Ok(socket.local_addr().map_err(fail)?.port())
}

fn write_silent_peer_server(
    data_directory: &TempDir,
) -> Result<(), TestCaseError> {
    let silent_port = free_udp_port()?;
    let real_endpoint =
        FakeRunner::start(RunnerAnswer::StaySilent).map_err(fail)?;
    let peer_address = PeerAddress {
        endpoint_public_key: real_endpoint.address.endpoint_public_key,
        direct_addresses: vec![SocketAddr::from((
            Ipv4Addr::LOCALHOST,
            silent_port,
        ))],
        relay_url: None,
    };
    let record = AppServerRecord {
        server_address: ServerAddress::Peer(peer_address).to_string(),
    };
    let record_text = serde_json::to_string(&record).map_err(fail)?;
    fs::write(server_record_in(data_directory.path()), record_text)
        .map_err(fail)
}

fn measure_drop(runtime: NodeRuntime) -> Duration {
    let stopping_started = Instant::now();
    drop(runtime);
    stopping_started.elapsed()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RELAY_CASES))]

    #[test]
    fn test_to_relay_choice_property_an_unparsable_relay_is_refused(
        relay_text in INVALID_RELAY_PATTERN,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;

        let custom_relay = json!({ "custom": relay_text });
        let started = start_with_relay(&data_directory, &custom_relay);

        let problem = started.err().unwrap_or_default();
        prop_assert!(problem.contains(&relay_text), "{}", problem);
    }

    #[test]
    fn test_to_relay_choice_property_a_disabled_relay_starts(
        restart_count in 1..=MOST_RESTARTS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;

        for _ in 0..restart_count {
            let runtime = start_with_relay(&data_directory, &json!("disabled"))
                .map_err(fail)?;
            let status = read_status_on(&runtime).map_err(fail)?;
            prop_assert!(status["peer"].is_object(), "{}", status);
        }
    }

    #[test]
    fn test_to_relay_choice_property_a_local_custom_relay_starts(
        _seed in any::<u8>(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let relay_port = free_udp_port()?;
        let relay_url = format!("http://127.0.0.1:{relay_port}");

        let runtime =
            start_with_relay(&data_directory, &json!({ "custom": relay_url }))
                .map_err(fail)?;

        let status = read_status_on(&runtime).map_err(fail)?;
        prop_assert!(status["peer"].is_object(), "{}", status);
        prop_assert!(measure_drop(runtime) < DROP_LIMIT);
    }

    #[test]
    fn test_server_dialer_property_a_web_server_drops_quickly(
        _seed in any::<u8>(),
    ) {
        let server = TestServer::start().map_err(fail)?;
        let device = TestDevice::start().map_err(fail)?;
        device.create_account(&server, WORKSPACE_NAME).map_err(fail)?;

        let stopping_time = measure_drop(device.runtime);

        prop_assert!(stopping_time < DROP_LIMIT, "{:?}", stopping_time);
    }

    #[test]
    fn test_server_dialer_property_unused_dialers_drop_quickly(
        restart_count in 1..=MOST_RESTARTS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;

        for _ in 0..restart_count {
            let runtime = start_with_relay(&data_directory, &json!("disabled"))
                .map_err(fail)?;
            let stopping_time = measure_drop(runtime);
            prop_assert!(stopping_time < DROP_LIMIT, "{:?}", stopping_time);
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(1))]

    #[test]
    fn test_server_dialer_property_a_dialing_runtime_stops_in_bounds(
        _seed in any::<u8>(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        write_silent_peer_server(&data_directory)?;
        let runtime = start_with_relay(&data_directory, &json!("disabled"))
            .map_err(fail)?;

        let checking_started = Instant::now();
        let status = read_status_on(&runtime).map_err(fail)?;
        let checking_time = checking_started.elapsed();
        let stopping_time = measure_drop(runtime);

        prop_assert_eq!(&status["server_reachable"], &json!(false));
        prop_assert_eq!(&status["hosting_problem"], &Value::Null);
        let longest_check = PEER_CONNECT_LIMIT + DIAL_SLACK;
        prop_assert!(checking_time < longest_check, "{:?}", checking_time);
        prop_assert!(stopping_time < DROP_LIMIT, "{:?}", stopping_time);
    }
}
