use std::thread;
use std::time::Duration;

use proptest::prelude::*;

use crate::announcing::Announcer;
use crate::counting_peer_server::CountingPeerServer;
use crate::search_joining::{
    check_asked_at_most_once, count_asks_until_asked, search_cases,
};
use crate::support::test_device::{TestDevice, fail};

const MOST_SERVERS: usize = 3;
const LATE_ANNOUNCEMENT_PAUSE: Duration = Duration::from_secs(2);

fn start_servers(
    count: usize,
) -> Result<Vec<CountingPeerServer>, TestCaseError> {
    let mut servers = Vec::new();
    for _ in 0..count {
        servers.push(CountingPeerServer::start().map_err(fail)?);
    }
    Ok(servers)
}

fn announce_into(
    announcer: &mut Announcer,
    server: &CountingPeerServer,
) -> Result<(), String> {
    let port = server.ipv4_port()?;
    announcer.announce_server_address(&server.announced_address(), port)
}

fn announce_later(server: &CountingPeerServer) -> Result<Announcer, String> {
    thread::sleep(LATE_ANNOUNCEMENT_PAUSE);
    let mut announcer = Announcer::start()?;
    announce_into(&mut announcer, server)?;
    Ok(announcer)
}

proptest! {
    #![proptest_config(search_cases())]

    #[test]
    fn test_next_server_address_property_offers_every_announced_server(
        server_count in 2..=MOST_SERVERS,
    ) {
        let servers = start_servers(server_count)?;
        let mut announcer = Announcer::start().map_err(fail)?;
        for server in &servers {
            announce_into(&mut announcer, server).map_err(fail)?;
        }
        let joining = TestDevice::start().map_err(fail)?;
        let server_references: Vec<&CountingPeerServer> =
            servers.iter().collect();

        let counts =
            count_asks_until_asked(&joining, &server_references)
                .map_err(fail)?;

        check_asked_at_most_once(&counts)?;
    }

    #[test]
    fn test_next_server_address_property_offers_a_server_announced_late(
        _round in 0_u8..1,
    ) {
        let early = CountingPeerServer::start().map_err(fail)?;
        let late = CountingPeerServer::start().map_err(fail)?;
        let mut announcer = Announcer::start().map_err(fail)?;
        announce_into(&mut announcer, &early).map_err(fail)?;
        let joining = TestDevice::start().map_err(fail)?;

        let (counts, late_announcer) = thread::scope(|scope| {
            let announcing = scope.spawn(|| announce_later(&late));
            let counts = count_asks_until_asked(&joining, &[&early, &late]);
            (counts, announcing.join())
        });

        let is_announced = matches!(late_announcer, Ok(Ok(_)));
        prop_assert!(is_announced, "the late announcement failed");
        check_asked_at_most_once(&counts.map_err(fail)?)?;
    }

    #[test]
    fn test_next_server_address_property_skips_a_withdrawn_server(
        _round in 0_u8..1,
    ) {
        let withdrawn = CountingPeerServer::start().map_err(fail)?;
        let live = CountingPeerServer::start().map_err(fail)?;
        let mut withdrawn_announcer = Announcer::start().map_err(fail)?;
        announce_into(&mut withdrawn_announcer, &withdrawn).map_err(fail)?;
        drop(withdrawn_announcer);
        let mut live_announcer = Announcer::start().map_err(fail)?;
        announce_into(&mut live_announcer, &live).map_err(fail)?;
        let joining = TestDevice::start().map_err(fail)?;

        let counts = count_asks_until_asked(&joining, &[&live])
            .map_err(fail)?;

        check_asked_at_most_once(&counts)?;
        prop_assert_eq!(withdrawn.count_connections(), 0);
    }
}
