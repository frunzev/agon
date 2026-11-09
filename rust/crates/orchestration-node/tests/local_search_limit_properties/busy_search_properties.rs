use std::time::{Duration, Instant};

use proptest::prelude::*;
use proptest::test_runner::Config;
use serde_json::{Value, json};

use crate::silent_server::SilentServer;
use crate::support::hosting_steps::{NO_SERVER_ACCEPTED_CODE, read_status};
use crate::support::pairing_steps::join_on_local_network;
use crate::support::test_device::{TestDevice, fail};

const CODE_PATTERN: &str = "[0-9A-HJKMNP-TV-Z]{3}-[0-9A-HJKMNP-TV-Z]{3}";
const CODE_GROUP_SEPARATOR: &str = "-";
const SEARCH_LIMIT: Duration = Duration::from_secs(30);
const SEARCH_SLACK: Duration = Duration::from_secs(8);
const EARLY_END_TOLERANCE: Duration = Duration::from_secs(1);
const ATTEMPT_LIMIT: Duration = Duration::from_secs(5);
const ATTEMPT_SLACK: Duration = Duration::from_secs(3);
const BUSY_SERVER_COUNT: usize = 8;
const NO_PENDING_JOIN: &str = "no pairing request from this device is waiting";

fn busy_cases() -> Config {
    Config {
        cases: 1,
        max_shrink_iters: 0,
        ..Config::default()
    }
}

fn start_busy_network() -> Result<Vec<SilentServer>, TestCaseError> {
    let mut silent_servers = Vec::new();
    for _ in 0..BUSY_SERVER_COUNT {
        silent_servers.push(SilentServer::start().map_err(fail)?);
    }
    Ok(silent_servers)
}

fn search_on_busy_network(
    code: &str,
) -> Result<(TestDevice, Duration, Vec<SilentServer>), TestCaseError> {
    let silent_servers = start_busy_network()?;
    let joining = TestDevice::start().map_err(fail)?;
    let started = Instant::now();

    let joined = join_on_local_network(&joining, code);
    let searched_for = started.elapsed();

    prop_assert_eq!(joined, Err(NO_SERVER_ACCEPTED_CODE.to_owned()));
    Ok((joining, searched_for, silent_servers))
}

fn check_left_in_time(
    silent: &SilentServer,
    code: &str,
) -> Result<(), TestCaseError> {
    let wire_code = code.replace(CODE_GROUP_SEPARATOR, "");
    let held_connections =
        silent.wait_for_closed_connections().map_err(fail)?;
    for held_connection in &held_connections {
        if !held_connection.received_text.contains(&wire_code) {
            continue;
        }
        let is_left_in_time =
            held_connection.held_for <= ATTEMPT_LIMIT + ATTEMPT_SLACK;
        prop_assert!(is_left_in_time, "{:?}", held_connection);
    }
    Ok(())
}

proptest! {
    #![proptest_config(busy_cases())]

    #[test]
    fn test_join_server_on_local_network_property_a_busy_search_ends_in_time(
        code in CODE_PATTERN,
    ) {
        let (_joining, searched_for, _silent_servers) =
            search_on_busy_network(&code)?;

        let allowed = SEARCH_LIMIT + SEARCH_SLACK;
        prop_assert!(searched_for <= allowed, "{:?}", searched_for);
    }

    #[test]
    fn test_join_server_on_local_network_property_busy_searches_use_the_limit(
        code in CODE_PATTERN,
    ) {
        let (_joining, searched_for, _silent_servers) =
            search_on_busy_network(&code)?;

        let lasted = searched_for + EARLY_END_TOLERANCE;
        prop_assert!(lasted >= SEARCH_LIMIT, "{:?}", searched_for);
    }

    #[test]
    fn test_join_server_on_local_network_property_a_cut_search_keeps_nothing(
        code in CODE_PATTERN,
    ) {
        let (joining, _searched_for, silent_servers) =
            search_on_busy_network(&code)?;

        for silent in &silent_servers {
            check_left_in_time(silent, &code)?;
        }
        let join_status = joining.run(&json!({ "command": "join_status" }));
        prop_assert_eq!(join_status, Err(NO_PENDING_JOIN.to_owned()));
        let status = read_status(&joining).map_err(fail)?;
        prop_assert_eq!(&status["server_address"], &Value::Null);
    }
}
