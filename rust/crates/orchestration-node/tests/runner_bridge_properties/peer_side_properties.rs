use std::collections::BTreeSet;
use std::net::SocketAddr;

use orchestration_p2p::peer_address::PeerAddress;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::peer_publishing::{read_announcement, wait_for_announcement};
use crate::peer_side_steps::{
    create_account_on, read_listed_own_address, start_with_account, wait_ticks,
};
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

const PEER_CASES: u32 = 1;
const MOST_TICKS: u32 = 3;

fn has_loopback_twin(address: &PeerAddress, direct: &SocketAddr) -> bool {
    address.direct_addresses.iter().any(|candidate| {
        candidate.ip().is_loopback() && candidate.port() == direct.port()
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PEER_CASES))]

    #[test]
    fn test_peer_side_bind_property_restarts_keep_the_peer_key(
        restart_count in 1_usize..3,
    ) {
        let (_server, mut device) = start_with_account().map_err(fail)?;
        let first = wait_for_announcement(&device).map_err(fail)?;

        let mut keys = Vec::new();
        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
            let announced = wait_for_announcement(&device).map_err(fail)?;
            keys.push(announced.endpoint_public_key);
        }

        for key in keys {
            prop_assert_eq!(key, first.endpoint_public_key);
        }
    }

    #[test]
    fn test_peer_side_bind_property_a_disabled_relay_has_no_relay(
        _seed in any::<u8>(),
    ) {
        let (_server, device) = start_with_account().map_err(fail)?;

        let announced = wait_for_announcement(&device).map_err(fail)?;

        prop_assert_eq!(announced.relay_url, None);
        prop_assert!(!announced.direct_addresses.is_empty());
    }

    #[test]
    fn test_peer_side_bind_property_each_device_has_its_own_key(
        _seed in any::<u8>(),
    ) {
        let (_first_server, first) = start_with_account().map_err(fail)?;
        let (_second_server, second) = start_with_account().map_err(fail)?;

        let first_address = wait_for_announcement(&first).map_err(fail)?;
        let second_address = wait_for_announcement(&second).map_err(fail)?;

        prop_assert_ne!(
            first_address.endpoint_public_key,
            second_address.endpoint_public_key
        );
    }

    #[test]
    fn test_current_address_property_offers_this_computer_too(
        _seed in any::<u8>(),
    ) {
        let (_server, device) = start_with_account().map_err(fail)?;

        let announced = wait_for_announcement(&device).map_err(fail)?;

        for direct in &announced.direct_addresses {
            let has_twin = has_loopback_twin(&announced, direct);
            prop_assert!(has_twin, "{:?}", announced);
        }
    }

    #[test]
    fn test_current_address_property_lists_each_address_once(
        _seed in any::<u8>(),
    ) {
        let (_server, device) = start_with_account().map_err(fail)?;

        let announced = wait_for_announcement(&device).map_err(fail)?;

        let distinct: BTreeSet<SocketAddr> =
            announced.direct_addresses.iter().copied().collect();
        prop_assert_eq!(distinct.len(), announced.direct_addresses.len());
    }

    #[test]
    fn test_current_address_property_stays_the_same_while_running(
        tick_count in 1..=MOST_TICKS,
    ) {
        let (_server, device) = start_with_account().map_err(fail)?;
        let first = wait_for_announcement(&device).map_err(fail)?;

        wait_ticks(tick_count);
        let later = wait_for_announcement(&device).map_err(fail)?;

        prop_assert_eq!(later, first);
    }

    #[test]
    fn test_peer_side_announcement_property_hides_the_publisher(
        _seed in any::<u8>(),
    ) {
        let (_server, device) = start_with_account().map_err(fail)?;
        wait_for_announcement(&device).map_err(fail)?;

        let announcement = read_announcement(&device).map_err(fail)?;

        let fields = announcement.as_object().cloned().unwrap_or_default();
        let mut names: Vec<String> = fields.keys().cloned().collect();
        names.sort();
        prop_assert_eq!(names, vec!["problem", "published_address"]);
    }

    #[test]
    fn test_peer_side_announcement_property_quiet_until_an_account(
        tick_count in 1..=MOST_TICKS,
    ) {
        let server = TestServer::start().map_err(fail)?;
        let device = TestDevice::start().map_err(fail)?;
        wait_ticks(tick_count);
        let quiet = read_announcement(&device).map_err(fail)?;

        create_account_on(&device, &server).map_err(fail)?;
        let announced = wait_for_announcement(&device);

        let expected = json!({ "published_address": null, "problem": null });
        prop_assert_eq!(quiet, expected);
        prop_assert!(announced.is_ok(), "{:?}", announced);
    }

    #[test]
    fn test_peer_side_announcement_property_matches_the_listed_address(
        _seed in any::<u8>(),
    ) {
        let (_server, device) = start_with_account().map_err(fail)?;
        let announced = wait_for_announcement(&device).map_err(fail)?;

        let announcement = read_announcement(&device).map_err(fail)?;
        let listed = read_listed_own_address(&device).map_err(fail)?;

        prop_assert_eq!(&announcement["published_address"], &json!(announced));
        prop_assert_eq!(listed, json!(announced));
        prop_assert_eq!(&announcement["problem"], &Value::Null);
    }
}
