use std::time::{Duration, Instant};

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::local_search_bound::join_locally_within_search_bound;
use crate::support::code_join_retries::join_until_a_server_accepts;
use crate::support::command_builders::prepare_workspace;
use crate::support::hosting_steps::{
    HostingDevice, NO_SERVER_ACCEPTED_CODE, read_hosted_address,
    read_server_identity, read_status, start_hosting_device,
};
use crate::support::pairing_steps::{join_at_address, join_on_local_network};
use crate::support::test_device::{
    TestDevice, UNREACHABLE_SERVER_ADDRESS, fail, read_text,
};
use crate::support::test_server::TestServer;

const JOIN_CASES: u32 = 2;
const CODE_PATTERN: &str = "[0-9A-HJKMNP-TV-Z]{3}-[0-9A-HJKMNP-TV-Z]{3}";
const NO_PENDING_JOIN: &str = "no pairing request from this device is waiting";
const UNREACHABLE_START: &str = "could not reach the app server";
const CLIENT_REFUSAL_START: &str = "the app server answered 4";
const WAITING_STATE: &str = "waiting";
const QUIET_PERIOD: Duration = Duration::from_secs(5);

fn start_joining_device() -> Result<TestDevice, TestCaseError> {
    TestDevice::start().map_err(fail)
}

fn start_hosting() -> Result<HostingDevice, TestCaseError> {
    start_hosting_device().map_err(fail)
}

fn read_join_status(device: &TestDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "join_status" }))
}

fn read_pending_join(device: &TestDevice) -> Result<Value, String> {
    let status = read_status(device)?;
    Ok(status["pending_join"].clone())
}

fn read_remembered_server(device: &TestDevice) -> Result<Value, String> {
    let status = read_status(device)?;
    Ok(status["server_address"].clone())
}

fn start_pairing_code(device: &TestDevice) -> Result<String, String> {
    let session = device.run(&json!({ "command": "start_pairing" }))?;
    read_text(&session, "/display_code")
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(JOIN_CASES))]

    #[test]
    fn test_join_server_at_property_an_unreachable_server_leaves_no_join(
        code in CODE_PATTERN,
    ) {
        let joining = start_joining_device()?;

        let joined =
            join_at_address(&joining, UNREACHABLE_SERVER_ADDRESS, &code);
        let problem = joined.err().unwrap_or_default();

        prop_assert!(problem.starts_with(UNREACHABLE_START), "{}", problem);
        let join_status = read_join_status(&joining);
        prop_assert_eq!(join_status, Err(NO_PENDING_JOIN.to_owned()));
        prop_assert_eq!(read_remembered_server(&joining), Ok(Value::Null));
    }

    #[test]
    fn test_join_server_at_property_an_unissued_code_is_refused(
        code in CODE_PATTERN,
    ) {
        let server = TestServer::start().map_err(fail)?;
        let joining = start_joining_device()?;

        let problem = join_at_address(&joining, &server.address, &code)
            .err()
            .unwrap_or_default();

        prop_assert!(problem.starts_with(CLIENT_REFUSAL_START), "{}", problem);
        let join_status = read_join_status(&joining);
        prop_assert_eq!(join_status, Err(NO_PENDING_JOIN.to_owned()));
        prop_assert_eq!(read_remembered_server(&joining), Ok(Value::Null));
    }

    #[test]
    fn test_join_server_at_property_an_issued_code_waits_for_approval(
        lowercase in any::<bool>(),
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let joining = start_joining_device()?;
        let code = start_pairing_code(&prepared.device).map_err(fail)?;
        let typed_code = if lowercase {
            code.to_lowercase()
        } else {
            code.clone()
        };

        let server_address = &prepared.server.address;
        let joined = join_at_address(&joining, server_address, &typed_code)
            .map_err(fail)?;

        prop_assert_eq!(&joined["display_code"], &json!(code));
        let join_status = read_join_status(&joining).map_err(fail)?;
        prop_assert_eq!(&join_status["state"], &json!(WAITING_STATE));
        let pending = read_pending_join(&joining).map_err(fail)?;
        prop_assert_eq!(&pending["display_code"], &json!(code));
        prop_assert_eq!(
            read_remembered_server(&joining),
            Ok(json!(prepared.server.address))
        );
    }

    #[test]
    fn test_join_server_by_code_property_a_closed_relay_ends_locally(
        code in CODE_PATTERN,
    ) {
        let joining = start_joining_device()?;

        let (joining, joined) =
            join_locally_within_search_bound(joining, code).map_err(fail)?;

        prop_assert_eq!(joined, Err(NO_SERVER_ACCEPTED_CODE.to_owned()));
        let join_status = read_join_status(&joining);
        prop_assert_eq!(join_status, Err(NO_PENDING_JOIN.to_owned()));
    }

    #[test]
    fn test_join_server_by_code_property_a_failed_search_keeps_the_device_free(
        code in CODE_PATTERN,
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let joining = start_joining_device()?;
        let refused = join_on_local_network(&joining, &code);
        let issued = start_pairing_code(&prepared.device).map_err(fail)?;

        let server_address = &prepared.server.address;
        let joined = join_at_address(&joining, server_address, &issued);

        prop_assert_eq!(refused, Err(NO_SERVER_ACCEPTED_CODE.to_owned()));
        prop_assert!(joined.is_ok(), "{:?}", joined);
    }

    #[test]
    fn test_join_server_by_code_property_finds_the_issuing_hosted_server(
        _seed in any::<u8>(),
    ) {
        let hosting = start_hosting()?;
        let joining = start_joining_device()?;
        let code = start_pairing_code(&hosting.device).map_err(fail)?;

        let joined = join_until_a_server_accepts(|| {
            join_on_local_network(&joining, &code)
        });

        prop_assert!(joined.is_ok(), "{:?}", joined);
        let remembered = read_remembered_server(&joining)
            .map(|address| address.as_str().unwrap_or_default().to_owned());
        prop_assert_eq!(
            read_server_identity(remembered),
            read_server_identity(read_hosted_address(&hosting.device))
        );
    }

    #[test]
    fn test_join_server_on_local_network_property_skips_refusing_servers(
        code in CODE_PATTERN,
    ) {
        let _hosting = start_hosting()?;
        let joining = start_joining_device()?;

        let joined = join_on_local_network(&joining, &code);

        prop_assert_eq!(joined, Err(NO_SERVER_ACCEPTED_CODE.to_owned()));
        prop_assert_eq!(read_remembered_server(&joining), Ok(Value::Null));
    }

    #[test]
    fn test_join_server_on_local_network_property_shows_the_issued_code(
        _seed in any::<u8>(),
    ) {
        let hosting = start_hosting()?;
        let joining = start_joining_device()?;
        let code = start_pairing_code(&hosting.device).map_err(fail)?;

        let joined = join_until_a_server_accepts(|| {
            join_on_local_network(&joining, &code)
        })
        .map_err(fail)?;

        prop_assert_eq!(&joined["display_code"], &json!(code));
    }

    #[test]
    fn test_join_server_on_local_network_property_repeats_the_same_refusal(
        code in CODE_PATTERN,
    ) {
        let joining = start_joining_device()?;

        let first = join_on_local_network(&joining, &code);
        let second = join_on_local_network(&joining, &code);

        prop_assert_eq!(&first, &Err(NO_SERVER_ACCEPTED_CODE.to_owned()));
        prop_assert_eq!(second, first);
    }

    #[test]
    fn test_wait_for_next_server_property_a_quiet_network_ends_the_search(
        code in CODE_PATTERN,
    ) {
        let joining = start_joining_device()?;

        let (_joining, joined) =
            join_locally_within_search_bound(joining, code).map_err(fail)?;

        prop_assert_eq!(joined, Err(NO_SERVER_ACCEPTED_CODE.to_owned()));
    }

    #[test]
    fn test_wait_for_next_server_property_waits_the_quiet_period(
        code in CODE_PATTERN,
    ) {
        let joining = start_joining_device()?;
        let started = Instant::now();

        let joined = join_on_local_network(&joining, &code);

        prop_assert_eq!(joined, Err(NO_SERVER_ACCEPTED_CODE.to_owned()));
        prop_assert!(started.elapsed() >= QUIET_PERIOD);
    }

    #[test]
    fn test_wait_for_next_server_property_hands_over_an_announced_server(
        _seed in any::<u8>(),
    ) {
        let hosting = start_hosting()?;
        let joining = start_joining_device()?;
        let code = start_pairing_code(&hosting.device).map_err(fail)?;

        let joined = join_until_a_server_accepts(|| {
            join_on_local_network(&joining, &code)
        });

        prop_assert!(joined.is_ok(), "{:?}", joined);
        let join_status = read_join_status(&joining).map_err(fail)?;
        prop_assert_eq!(&join_status["state"], &json!(WAITING_STATE));
        let pending = read_pending_join(&joining).map_err(fail)?;
        prop_assert_eq!(&pending["display_code"], &json!(code));
    }
}
