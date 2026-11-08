use std::time::{Duration, Instant};

use orchestration_node::code_rendezvous::RECORD_BOARD_WAIT_LIMIT;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::command_device::CommandDevice;
use crate::slow_board::{SilentBoardDevice, SilentBoardProxy};
use crate::support::rendezvous_lookup::generate_unissued_code;
use crate::support::test_device::fail;

const JOIN_CASES: u32 = 2;
const LONGEST_JOIN_WAIT: Duration = Duration::from_secs(30);
const SILENT_BOARD_START: &str = "the code could not be published or looked \
                                  up: the public record board could not be \
                                  reached: no answer within ";
const SECONDS_END: &str = " seconds";
const NO_PENDING_JOIN: &str = "no pairing request from this device is waiting";
const JOINING_ROLES: [&str; 3] = ["client", "runner", "client_and_runner"];
const JOINING_NAMES: [&str; 3] = ["mac-mini", "studio", "build-box-2"];

struct SilentJoiner {
    proxy: SilentBoardProxy,
    joiner: SilentBoardDevice,
}

fn start_silent_joiner_or_panic() -> SilentJoiner {
    let Ok(proxy) = SilentBoardProxy::start() else {
        panic!("the silent board proxy starts");
    };
    let joiner = SilentBoardDevice::start(&proxy);
    let Ok(joiner) = joiner else {
        panic!("the joiner starts behind the proxy: {joiner:?}");
    };
    SilentJoiner { proxy, joiner }
}

fn join_strategy() -> impl Strategy<Value = (&'static str, &'static str)> {
    (
        proptest::sample::select(JOINING_NAMES.to_vec()),
        proptest::sample::select(JOINING_ROLES.to_vec()),
    )
}

fn join_without_address(
    joiner: &SilentBoardDevice,
    device_name: &str,
    role: &str,
) -> Result<Result<Value, String>, TestCaseError> {
    let code = generate_unissued_code().map_err(fail)?;
    Ok(joiner.run(&json!({
        "command": "join_with_code",
        "code": code,
        "device_name": device_name,
        "role": role,
    })))
}

fn describe_expected_silence() -> String {
    let wait_seconds = RECORD_BOARD_WAIT_LIMIT.as_secs();
    format!("{SILENT_BOARD_START}{wait_seconds}{SECONDS_END}")
}

#[test]
fn test_find_server_by_code_property_a_silent_board_ends_the_join_in_time() {
    let silent = start_silent_joiner_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));

    let outcome = runner.run(&join_strategy(), |(device_name, role)| {
        let tunnels_before =
            silent.proxy.count_board_tunnels().map_err(fail)?;
        let started_at = Instant::now();
        let joined = join_without_address(&silent.joiner, device_name, role)?;
        let waited = started_at.elapsed();
        let tunnels_after =
            silent.proxy.count_board_tunnels().map_err(fail)?;

        prop_assert!(joined.is_err(), "{:?}", joined);
        prop_assert!(waited >= RECORD_BOARD_WAIT_LIMIT, "{:?}", waited);
        prop_assert!(waited < LONGEST_JOIN_WAIT, "{:?}", waited);
        prop_assert!(tunnels_after > tunnels_before, "{}", tunnels_after);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_find_server_by_code_property_a_silent_board_names_its_silence() {
    let silent = start_silent_joiner_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));

    let outcome = runner.run(&join_strategy(), |(device_name, role)| {
        let joined = join_without_address(&silent.joiner, device_name, role)?;

        prop_assert_eq!(joined, Err(describe_expected_silence()));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_find_server_by_code_property_a_silent_lookup_leaves_nothing_behind() {
    let silent = start_silent_joiner_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));

    let outcome = runner.run(&join_strategy(), |(device_name, role)| {
        let joined = join_without_address(&silent.joiner, device_name, role)?;
        let join_status =
            silent.joiner.run(&json!({ "command": "join_status" }));
        let status = silent
            .joiner
            .run(&json!({ "command": "status" }))
            .map_err(fail)?;

        prop_assert!(joined.is_err(), "{:?}", joined);
        prop_assert_eq!(join_status, Err(NO_PENDING_JOIN.to_owned()));
        prop_assert_eq!(&status["pending_join"], &Value::Null);
        prop_assert_eq!(&status["account"], &Value::Null);
        prop_assert_eq!(&status["server_address"], &Value::Null);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
