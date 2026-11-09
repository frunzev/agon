use std::thread;
use std::time::Duration;

use proptest::prelude::*;

use crate::announcing::Announcer;
use crate::counting_peer_server::CountingPeerServer;
use crate::search_joining::{
    check_asked_at_most_once, count_asks_until_asked, create_fresh_code,
    join_once, search_cases,
};
use crate::support::test_device::{TestDevice, fail};

const MOST_REPEATS: usize = 4;
const LATE_ANSWER_WAIT: Duration = Duration::from_secs(8);
const DEVICE_THREAD_FAILED: &str = "a joining device stopped unexpectedly";

fn announce_plainly(
    server: &CountingPeerServer,
) -> Result<Announcer, TestCaseError> {
    let port = server.ipv4_port().map_err(fail)?;
    let mut announcer = Announcer::start().map_err(fail)?;
    announcer
        .announce_server_address(&server.announced_address(), port)
        .map_err(fail)?;
    Ok(announcer)
}

fn join_from_new_device(
    server: &CountingPeerServer,
) -> Result<Vec<Vec<usize>>, String> {
    let joining = TestDevice::start()?;
    count_asks_until_asked(&joining, &[server])
}

fn join_from_two_devices_at_once(
    server: &CountingPeerServer,
) -> Result<Vec<Vec<Vec<usize>>>, String> {
    thread::scope(|scope| {
        let first = scope.spawn(|| join_from_new_device(server));
        let second = scope.spawn(|| join_from_new_device(server));
        let mut counts_per_device = Vec::new();
        for joining in [first, second] {
            let joined = joining.join().map_err(|_| DEVICE_THREAD_FAILED)?;
            counts_per_device.push(joined?);
        }
        Ok(counts_per_device)
    })
}

proptest! {
    #![proptest_config(search_cases())]

    #[test]
    fn test_local_network_search_start_property_sees_earlier_servers(
        _round in 0_u8..1,
    ) {
        let server = CountingPeerServer::start().map_err(fail)?;
        let _announcer = announce_plainly(&server)?;
        let joining = TestDevice::start().map_err(fail)?;

        let counts = count_asks_until_asked(&joining, &[&server])
            .map_err(fail)?;

        check_asked_at_most_once(&counts)?;
    }

    #[test]
    fn test_local_network_search_start_property_each_search_asks_again(
        search_count in 2..=MOST_REPEATS,
    ) {
        let server = CountingPeerServer::start().map_err(fail)?;
        let _announcer = announce_plainly(&server)?;
        let joining = TestDevice::start().map_err(fail)?;

        for _ in 0..search_count {
            let counts = count_asks_until_asked(&joining, &[&server])
                .map_err(fail)?;
            check_asked_at_most_once(&counts)?;
        }
    }

    #[test]
    fn test_local_network_search_start_property_two_devices_search_alike(
        _round in 0_u8..1,
    ) {
        let server = CountingPeerServer::start().map_err(fail)?;
        let _announcer = announce_plainly(&server)?;

        let counts_per_device =
            join_from_two_devices_at_once(&server).map_err(fail)?;

        for counts in &counts_per_device {
            check_asked_at_most_once(counts)?;
        }
    }

    #[test]
    fn test_local_network_search_drop_property_a_late_server_is_never_asked(
        _round in 0_u8..1,
    ) {
        let joining = TestDevice::start().map_err(fail)?;
        let code = create_fresh_code();
        join_once(&joining, &code).map_err(fail)?;
        let server = CountingPeerServer::start().map_err(fail)?;

        let _announcer = announce_plainly(&server)?;
        thread::sleep(LATE_ANSWER_WAIT);

        prop_assert_eq!(server.count_connections_with_code(&code), 0);
    }

    #[test]
    fn test_local_network_search_drop_property_searches_keep_starting(
        search_count in 2..=MOST_REPEATS,
    ) {
        let joining = TestDevice::start().map_err(fail)?;

        for _ in 0..search_count {
            let code = create_fresh_code();
            let joined = join_once(&joining, &code);
            prop_assert_eq!(joined, Ok(()));
        }
    }

    #[test]
    fn test_local_network_search_drop_property_new_devices_see_the_server(
        device_count in 2..=MOST_REPEATS,
    ) {
        let server = CountingPeerServer::start().map_err(fail)?;
        let _announcer = announce_plainly(&server)?;

        for _ in 0..device_count {
            let counts = join_from_new_device(&server).map_err(fail)?;
            check_asked_at_most_once(&counts)?;
        }
    }
}
