use std::net::{Ipv4Addr, UdpSocket};
use std::thread;
use std::time::Duration;

use orchestration_api::routes::DEVICE_PEER_ADDRESS;
use orchestration_p2p::peer_address::PeerAddress;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::forged_workspace::list_device_views;
use crate::peer_publishing::{read_announcement, wait_for_announcement};
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;
use crate::support::waiting::wait_for;

const ANNOUNCER_CASES: u32 = 2;
const MOST_TICKS: u64 = 3;
const ANNOUNCE_TICK: Duration = Duration::from_millis(1_100);
const PROBLEM_LIMIT: Duration = Duration::from_secs(20);
const PUT_METHOD: &str = "PUT";
const WORKSPACE_NAME: &str = "acme";

fn count_publishing(server: &TestServer) -> usize {
    let mut publishing_count = 0;
    for request in server.recorded_requests() {
        let is_publishing = request.method == PUT_METHOD
            && request.path == DEVICE_PEER_ADDRESS;
        if is_publishing {
            publishing_count += 1;
        }
    }
    publishing_count
}

fn read_listed_own_address(device: &TestDevice) -> Result<Value, String> {
    let views = list_device_views(device)?;
    let own_view = views
        .iter()
        .find(|view| view["is_this_device"] == json!(true))
        .ok_or("this device is not listed")?;
    Ok(own_view["device"]["peer_address"]["address"].clone())
}

fn start_with_account() -> Result<(TestServer, TestDevice), String> {
    let server = TestServer::start()?;
    let device = TestDevice::start()?;
    device.create_account(&server, WORKSPACE_NAME)?;
    Ok((server, device))
}

fn wait_ticks(tick_count: u64) {
    let ticks = u32::try_from(tick_count).unwrap_or(u32::MAX);
    thread::sleep(ANNOUNCE_TICK * ticks);
}

fn find_loopback_port(address: &PeerAddress) -> Option<u16> {
    address
        .direct_addresses
        .iter()
        .find(|direct| direct.ip() == Ipv4Addr::LOCALHOST)
        .map(std::net::SocketAddr::port)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ANNOUNCER_CASES))]

    #[test]
    fn test_start_announcer_property_publishes_once_an_account_exists(
        tick_count in 0..MOST_TICKS,
    ) {
        let (server, device) = start_with_account().map_err(fail)?;

        let announced = wait_for_announcement(&device).map_err(fail)?;
        wait_ticks(tick_count);

        let listed = read_listed_own_address(&device).map_err(fail)?;
        prop_assert_eq!(listed, json!(announced));
        let announcement = read_announcement(&device).map_err(fail)?;
        prop_assert_eq!(&announcement["problem"], &Value::Null);
        prop_assert!(count_publishing(&server) >= 1);
    }

    #[test]
    fn test_start_announcer_property_stays_quiet_without_an_account(
        tick_count in 1..=MOST_TICKS,
    ) {
        let device = TestDevice::start().map_err(fail)?;

        wait_ticks(tick_count);

        let announcement = read_announcement(&device).map_err(fail)?;
        let quiet = json!({ "published_address": null, "problem": null });
        prop_assert_eq!(announcement, quiet);
    }

    #[test]
    fn test_start_announcer_property_announces_again_after_a_restart(
        restart_count in 1_usize..3,
    ) {
        let (server, mut device) = start_with_account().map_err(fail)?;
        let first = wait_for_announcement(&device).map_err(fail)?;

        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
            let announced = wait_for_announcement(&device).map_err(fail)?;
            let listed = read_listed_own_address(&device).map_err(fail)?;
            prop_assert_eq!(
                announced.endpoint_public_key,
                first.endpoint_public_key
            );
            prop_assert_eq!(listed, json!(announced));
        }
        prop_assert!(count_publishing(&server) > restart_count);
    }

    #[test]
    fn test_announce_when_changed_property_an_unchanged_address_is_quiet(
        tick_count in 1..=MOST_TICKS,
    ) {
        let (server, device) = start_with_account().map_err(fail)?;
        wait_for_announcement(&device).map_err(fail)?;
        let published_count = count_publishing(&server);

        wait_ticks(tick_count);

        prop_assert_eq!(published_count, 1);
        prop_assert_eq!(count_publishing(&server), published_count);
    }

    #[test]
    fn test_announce_when_changed_property_a_lost_server_is_a_problem(
        _seed in any::<u8>(),
    ) {
        let (server, device) = start_with_account().map_err(fail)?;
        server.stop().map_err(fail)?;
        let device = device.stop_and_start_again().map_err(fail)?;

        let problem = wait_for(PROBLEM_LIMIT, "an announcement problem", || {
            let announcement = read_announcement(&device)?;
            Ok(announcement["problem"].as_str().map(str::to_owned))
        })
        .map_err(fail)?;
        let unpublished = read_announcement(&device).map_err(fail)?;
        server.start_again().map_err(fail)?;
        let announced = wait_for_announcement(&device).map_err(fail)?;
        let recovered = read_announcement(&device).map_err(fail)?;

        prop_assert!(!problem.trim().is_empty());
        prop_assert_eq!(&unpublished["published_address"], &Value::Null);
        prop_assert_eq!(&recovered["problem"], &Value::Null);
        let listed = read_listed_own_address(&device).map_err(fail)?;
        prop_assert_eq!(listed, json!(announced));
    }

    #[test]
    fn test_announce_when_changed_property_a_new_account_gets_the_address(
        _seed in any::<u8>(),
    ) {
        let (first_server, device) = start_with_account().map_err(fail)?;
        wait_for_announcement(&device).map_err(fail)?;
        device
            .run(&json!({ "command": "forget_this_device" }))
            .map_err(fail)?;
        let second_server = TestServer::start().map_err(fail)?;
        device
            .create_account(&second_server, WORKSPACE_NAME)
            .map_err(fail)?;

        let listed = wait_for(PROBLEM_LIMIT, "the new server to learn it", || {
            let listed = read_listed_own_address(&device)?;
            Ok((!listed.is_null()).then_some(listed))
        });

        prop_assert!(listed.is_ok(), "{:?}", listed);
        prop_assert_eq!(count_publishing(&second_server), 1);
        drop(first_server);
    }

    #[test]
    fn test_node_runtime_drop_property_stops_announcing_and_frees_the_port(
        tick_count in 1..=MOST_TICKS,
    ) {
        let (server, device) = start_with_account().map_err(fail)?;
        let announced = wait_for_announcement(&device).map_err(fail)?;
        let peer_port = find_loopback_port(&announced);

        drop(device);
        let request_count = server.recorded_requests().len();
        wait_ticks(tick_count);

        prop_assert_eq!(server.recorded_requests().len(), request_count);
        let peer_port = peer_port.ok_or_else(|| fail("no loopback port"))?;
        let rebound = UdpSocket::bind((Ipv4Addr::UNSPECIFIED, peer_port));
        prop_assert!(rebound.is_ok(), "{:?}", rebound);
    }
}
