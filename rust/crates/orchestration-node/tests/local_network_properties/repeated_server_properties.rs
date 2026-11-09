use std::net::SocketAddr;

use proptest::prelude::*;

use crate::announcing::Announcer;
use crate::counting_peer_server::CountingPeerServer;
use crate::search_joining::{
    check_asked_at_most_once, count_asks_until_asked,
    describe_with_direct_addresses, loopback_direct_addresses, search_cases,
};
use crate::support::test_device::{TestDevice, fail};

const LOOPBACK_ADDRESS_COUNT: usize = 3;
const SERVER_COUNT: usize = 2;

fn address_order_strategy() -> impl Strategy<Value = Vec<usize>> {
    let positions: Vec<usize> = (0..LOOPBACK_ADDRESS_COUNT).collect();
    Just(positions).prop_shuffle()
}

fn arrange_addresses(
    server: &CountingPeerServer,
    order: &[usize],
) -> Result<Vec<SocketAddr>, TestCaseError> {
    let port = server.ipv4_port().map_err(fail)?;
    let direct_addresses = loopback_direct_addresses(port);
    let mut arranged = Vec::new();
    for position in order {
        arranged.push(direct_addresses[*position]);
    }
    Ok(arranged)
}

fn announce_in_both_orders(
    announcer: &mut Announcer,
    server: &CountingPeerServer,
    order: &[usize],
) -> Result<(), TestCaseError> {
    let port = server.ipv4_port().map_err(fail)?;
    let arranged = arrange_addresses(server, order)?;
    let mut reversed = arranged.clone();
    reversed.reverse();
    for addresses in [arranged, reversed] {
        let ordered_address =
            describe_with_direct_addresses(server, &addresses);
        announcer
            .announce_server_address(&ordered_address, port)
            .map_err(fail)?;
    }
    Ok(())
}

proptest! {
    #![proptest_config(search_cases())]

    #[test]
    fn test_describe_server_identity_property_reordered_addresses_ask_once(
        order in address_order_strategy(),
    ) {
        let server = CountingPeerServer::start().map_err(fail)?;
        let mut announcer = Announcer::start().map_err(fail)?;
        announce_in_both_orders(&mut announcer, &server, &order)?;
        let joining = TestDevice::start().map_err(fail)?;

        let counts = count_asks_until_asked(&joining, &[&server])
            .map_err(fail)?;

        check_asked_at_most_once(&counts)?;
    }

    #[test]
    fn test_describe_server_identity_property_more_addresses_ask_no_more(
        order in address_order_strategy(),
        first_count in 1..LOOPBACK_ADDRESS_COUNT,
    ) {
        let server = CountingPeerServer::start().map_err(fail)?;
        let port = server.ipv4_port().map_err(fail)?;
        let arranged = arrange_addresses(&server, &order)?;
        let mut announcer = Announcer::start().map_err(fail)?;
        for known_count in [first_count, LOOPBACK_ADDRESS_COUNT] {
            let known = &arranged[..known_count];
            let announced = describe_with_direct_addresses(&server, known);
            announcer
                .announce_server_address(&announced, port)
                .map_err(fail)?;
        }
        let joining = TestDevice::start().map_err(fail)?;

        let counts = count_asks_until_asked(&joining, &[&server])
            .map_err(fail)?;

        check_asked_at_most_once(&counts)?;
    }

    #[test]
    fn test_describe_server_identity_property_each_server_is_asked_once(
        order in address_order_strategy(),
    ) {
        let mut servers = Vec::new();
        for _ in 0..SERVER_COUNT {
            servers.push(CountingPeerServer::start().map_err(fail)?);
        }
        let mut announcer = Announcer::start().map_err(fail)?;
        for server in &servers {
            announce_in_both_orders(&mut announcer, server, &order)?;
        }
        let joining = TestDevice::start().map_err(fail)?;
        let server_references: Vec<&CountingPeerServer> =
            servers.iter().collect();

        let counts =
            count_asks_until_asked(&joining, &server_references)
                .map_err(fail)?;

        check_asked_at_most_once(&counts)?;
    }
}
