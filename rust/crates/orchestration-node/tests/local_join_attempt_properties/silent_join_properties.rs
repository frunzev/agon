use std::time::Duration;

use proptest::prelude::*;
use serde_json::json;

use crate::silent_server::{HeldConnection, SilentServer};
use crate::support::code_join_retries::join_until_a_server_accepts;
use crate::support::hosting_steps::{
    NO_SERVER_ACCEPTED_CODE, start_hosting_device,
};
use crate::support::pairing_steps::join_on_local_network;
use crate::support::test_device::{TestDevice, fail, read_text};

const JOIN_CASES: u32 = 2;
const CODE_PATTERN: &str = "[0-9A-HJKMNP-TV-Z]{3}-[0-9A-HJKMNP-TV-Z]{3}";
const ATTEMPT_LIMIT: Duration = Duration::from_secs(5);
const ATTEMPT_SLACK: Duration = Duration::from_secs(3);
const MOST_SILENT_SERVERS: usize = 3;
const CODE_GROUP_SEPARATOR: &str = "-";

fn start_silent_servers(count: usize) -> Result<Vec<SilentServer>, String> {
    let mut servers = Vec::new();
    for _ in 0..count {
        servers.push(SilentServer::start()?);
    }
    Ok(servers)
}

fn is_left_in_time(held_connection: &HeldConnection) -> bool {
    held_connection.held_for <= ATTEMPT_LIMIT + ATTEMPT_SLACK
}

fn select_joins_with_code(
    held_connections: Vec<HeldConnection>,
    code: &str,
) -> Vec<HeldConnection> {
    let wire_code = code.replace(CODE_GROUP_SEPARATOR, "");
    let mut joins_with_code = Vec::new();
    for held_connection in held_connections {
        if held_connection.received_text.contains(&wire_code) {
            joins_with_code.push(held_connection);
        }
    }
    joins_with_code
}

fn check_left_in_time(
    silent: &SilentServer,
    code: &str,
) -> Result<(), TestCaseError> {
    let held_connections =
        silent.wait_for_closed_connections().map_err(fail)?;
    let joins_with_code = select_joins_with_code(held_connections, code);
    prop_assert!(!joins_with_code.is_empty(), "the server was never asked");
    for held_connection in &joins_with_code {
        prop_assert!(
            is_left_in_time(held_connection),
            "{:?}",
            held_connection
        );
    }
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig {
        cases: JOIN_CASES,
        max_shrink_iters: 0,
        ..ProptestConfig::default()
    })]

    #[test]
    fn test_join_server_on_local_network_property_a_silent_server_is_left(
        code in CODE_PATTERN,
    ) {
        let silent = SilentServer::start().map_err(fail)?;
        let joining = TestDevice::start().map_err(fail)?;

        let joined = join_on_local_network(&joining, &code);

        prop_assert_eq!(joined, Err(NO_SERVER_ACCEPTED_CODE.to_owned()));
        check_left_in_time(&silent, &code)?;
    }

    #[test]
    fn test_join_server_on_local_network_property_each_silent_server_is_left(
        code in CODE_PATTERN,
        silent_count in 2..=MOST_SILENT_SERVERS,
    ) {
        let silent_servers = start_silent_servers(silent_count).map_err(fail)?;
        let joining = TestDevice::start().map_err(fail)?;

        let joined = join_on_local_network(&joining, &code);

        prop_assert_eq!(joined, Err(NO_SERVER_ACCEPTED_CODE.to_owned()));
        for silent in &silent_servers {
            check_left_in_time(silent, &code)?;
        }
    }

    #[test]
    fn test_join_server_on_local_network_property_silence_hides_no_server(
        _seed in any::<u8>(),
    ) {
        let silent = SilentServer::start().map_err(fail)?;
        let hosting = start_hosting_device().map_err(fail)?;
        let joining = TestDevice::start().map_err(fail)?;
        let session = hosting
            .device
            .run(&json!({ "command": "start_pairing" }))
            .map_err(fail)?;
        let code = read_text(&session, "/display_code").map_err(fail)?;

        let joined = join_until_a_server_accepts(|| {
            join_on_local_network(&joining, &code)
        });

        let joined = joined.map_err(fail)?;
        prop_assert_eq!(&joined["display_code"], &json!(code));
        let held = silent.wait_for_closed_connections().map_err(fail)?;
        for held_connection in &select_joins_with_code(held, &code) {
            let is_in_time = is_left_in_time(held_connection);
            prop_assert!(is_in_time, "{:?}", held_connection);
        }
    }
}
