use std::net::{Ipv4Addr, SocketAddr};

use orchestration_core::peer_address::PeerAddress;
use orchestration_node::server_address::ServerAddress;
use proptest::prelude::*;
use proptest::test_runner::Config;
use uuid::Uuid;

use crate::counting_peer_server::CountingPeerServer;
use crate::support::hosting_steps::NO_SERVER_ACCEPTED_CODE;
use crate::support::pairing_steps::join_on_local_network;
use crate::support::test_device::TestDevice;

const SEARCH_CASES: u32 = 2;
const MOST_SEARCHES: usize = 3;
const CODE_SYMBOLS: &[u8; 32] = b"0123456789ABCDEFGHJKMNPQRSTVWXYZ";
const CODE_GROUP_LENGTH: usize = 3;
const CODE_GROUP_SEPARATOR: char = '-';
const LOOPBACK_ADDRESSES: [Ipv4Addr; 3] = [
    Ipv4Addr::LOCALHOST,
    Ipv4Addr::new(127, 0, 0, 2),
    Ipv4Addr::new(127, 0, 0, 3),
];
const NEVER_ASKED: &str = "no search asked the announced server";

pub fn search_cases() -> Config {
    Config {
        cases: SEARCH_CASES,
        max_shrink_iters: 0,
        ..Config::default()
    }
}

pub fn create_fresh_code() -> String {
    let random_bytes = Uuid::new_v4().into_bytes();
    let mut code = String::new();
    for (position, random_byte) in random_bytes.iter().enumerate() {
        if position == CODE_GROUP_LENGTH * 2 {
            break;
        }
        if position == CODE_GROUP_LENGTH {
            code.push(CODE_GROUP_SEPARATOR);
        }
        let symbol_index = usize::from(*random_byte) % CODE_SYMBOLS.len();
        code.push(char::from(CODE_SYMBOLS[symbol_index]));
    }
    code
}

pub fn loopback_direct_addresses(port: u16) -> Vec<SocketAddr> {
    let mut direct_addresses = Vec::new();
    for loopback in LOOPBACK_ADDRESSES {
        direct_addresses.push(SocketAddr::from((loopback, port)));
    }
    direct_addresses
}

pub fn describe_with_direct_addresses(
    server: &CountingPeerServer,
    direct_addresses: &[SocketAddr],
) -> String {
    let address = ServerAddress::Peer(PeerAddress {
        direct_addresses: direct_addresses.to_vec(),
        ..server.peer_address()
    });
    address.to_string()
}

pub fn join_once(joining: &TestDevice, code: &str) -> Result<(), String> {
    let joined = join_on_local_network(joining, code);
    if joined == Err(NO_SERVER_ACCEPTED_CODE.to_owned()) {
        return Ok(());
    }
    Err(format!("the join ended as {joined:?}"))
}

pub fn count_asks_until_asked(
    joining: &TestDevice,
    servers: &[&CountingPeerServer],
) -> Result<Vec<Vec<usize>>, String> {
    let mut counts_per_search = Vec::new();
    let mut is_asked = vec![false; servers.len()];
    for _ in 0..MOST_SEARCHES {
        let code = create_fresh_code();
        join_once(joining, &code)?;
        let mut counts = Vec::new();
        for (position, server) in servers.iter().enumerate() {
            let count = server.count_connections_with_code(&code);
            is_asked[position] = is_asked[position] || count > 0;
            counts.push(count);
        }
        counts_per_search.push(counts);
        if is_asked.iter().all(|asked| *asked) {
            return Ok(counts_per_search);
        }
    }
    Err(format!("{NEVER_ASKED}: {counts_per_search:?}"))
}

pub fn check_asked_at_most_once(
    counts_per_search: &[Vec<usize>],
) -> Result<(), TestCaseError> {
    for counts in counts_per_search {
        for count in counts {
            prop_assert!(*count <= 1, "{:?}", counts_per_search);
        }
    }
    Ok(())
}
