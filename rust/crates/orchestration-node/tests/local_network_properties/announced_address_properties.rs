use std::net::{Ipv4Addr, SocketAddr, UdpSocket};

use orchestration_node::server_address::ServerAddress;
use proptest::prelude::*;

use crate::announcing::{AnnouncedProperty, Announcer};
use crate::counting_peer_server::CountingPeerServer;
use crate::search_joining::{
    check_asked_at_most_once, count_asks_until_asked,
    describe_with_direct_addresses, search_cases,
};
use crate::support::test_device::{TestDevice, describe, fail};

const OTHER_PROPERTY: &str = "address";
const ANY_FREE_PORT: u16 = 0;
const UNREACHABLE_LOOPBACK: Ipv4Addr = Ipv4Addr::new(127, 0, 0, 2);

fn hostile_address_strategy() -> impl Strategy<Value = String> {
    prop_oneof![
        Just(String::new()),
        "[\\PC]{0,40}",
        "peer://[0-9a-f]{0,70}(\\?[a-z]{1,8}=[^&]{0,12})?",
        "(http|https|ftp|file|peer):/{0,3}[^ ]{0,30}",
    ]
    .prop_filter("the text is no server address", |text| {
        ServerAddress::parse(text).is_err()
    })
}

fn check_companion_asked_alone(
    companion: &CountingPeerServer,
    skipped: Option<&CountingPeerServer>,
) -> Result<(), TestCaseError> {
    let joining = TestDevice::start().map_err(fail)?;

    let counts =
        count_asks_until_asked(&joining, &[companion]).map_err(fail)?;

    check_asked_at_most_once(&counts)?;
    if let Some(skipped) = skipped {
        prop_assert_eq!(skipped.count_connections(), 0);
    }
    Ok(())
}

fn announce_companion(
    announcer: &mut Announcer,
    companion: &CountingPeerServer,
) -> Result<(), TestCaseError> {
    let port = companion.ipv4_port().map_err(fail)?;
    let companion_address = companion.announced_address();
    announcer
        .announce_server_address(&companion_address, port)
        .map_err(fail)
}

fn take_silent_port() -> Result<UdpSocket, String> {
    UdpSocket::bind((Ipv4Addr::LOCALHOST, ANY_FREE_PORT)).map_err(describe)
}

proptest! {
    #![proptest_config(search_cases())]

    #[test]
    fn test_read_announced_address_property_no_address_property_is_skipped(
        _round in 0_u8..1,
    ) {
        let skipped = CountingPeerServer::start().map_err(fail)?;
        let companion = CountingPeerServer::start().map_err(fail)?;
        let skipped_port = skipped.ipv4_port().map_err(fail)?;
        let skipped_address = skipped.announced_address();
        let properties: [AnnouncedProperty<'_>; 1] =
            [(OTHER_PROPERTY, skipped_address.as_str())];
        let mut announcer = Announcer::start().map_err(fail)?;
        announcer.announce(&properties, skipped_port).map_err(fail)?;
        announce_companion(&mut announcer, &companion)?;

        check_companion_asked_alone(&companion, Some(&skipped))?;
    }

    #[test]
    fn test_read_announced_address_property_a_hostile_address_is_skipped(
        hostile_address in hostile_address_strategy(),
    ) {
        let companion = CountingPeerServer::start().map_err(fail)?;
        let silent_port = take_silent_port().map_err(fail)?;
        let port = silent_port.local_addr().map_err(fail)?.port();
        let mut announcer = Announcer::start().map_err(fail)?;
        announcer
            .announce_server_address(&hostile_address, port)
            .map_err(fail)?;
        announce_companion(&mut announcer, &companion)?;

        check_companion_asked_alone(&companion, None)?;
    }

    #[test]
    fn test_read_announced_address_property_uses_the_service_port(
        _round in 0_u8..1,
    ) {
        let misplaced = CountingPeerServer::start().map_err(fail)?;
        let companion = CountingPeerServer::start().map_err(fail)?;
        let silent_port = take_silent_port().map_err(fail)?;
        let wrong_port = silent_port.local_addr().map_err(fail)?.port();
        let misplaced_address = misplaced.announced_address();
        let mut announcer = Announcer::start().map_err(fail)?;
        announcer
            .announce_server_address(&misplaced_address, wrong_port)
            .map_err(fail)?;
        announce_companion(&mut announcer, &companion)?;

        check_companion_asked_alone(&companion, Some(&misplaced))?;
    }

    #[test]
    fn test_read_announced_address_property_adds_the_resolved_address(
        _round in 0_u8..1,
    ) {
        let server = CountingPeerServer::start().map_err(fail)?;
        let port = server.ipv4_port().map_err(fail)?;
        let unreachable = SocketAddr::from((UNREACHABLE_LOOPBACK, port));
        let announced =
            describe_with_direct_addresses(&server, &[unreachable]);
        let mut announcer = Announcer::start().map_err(fail)?;
        announcer
            .announce_server_address(&announced, port)
            .map_err(fail)?;

        check_companion_asked_alone(&server, None)?;
    }
}
