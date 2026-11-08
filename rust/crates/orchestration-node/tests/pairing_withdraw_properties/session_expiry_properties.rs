use chrono::TimeDelta;
use orchestration_security::pairing::PAIRING_SESSION_LIFETIME;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::Value;

use crate::approver_desk::start_pairing;
use crate::command_device::CommandDevice;
use crate::skipping_clock_server::SkippingClockServer;
use crate::slow_board::{SilentBoardDevice, SilentBoardProxy};
use crate::support::pairing_steps::join_at_address;
use crate::support::test_device::{TestDevice, fail, read_text};

const EXPIRY_CASES: u32 = 3;
const MOST_SECONDS_PAST_EXPIRY: i64 = 3_600;
const EXPIRED_SESSION_MESSAGE: &str = "the pairing session has expired";

struct ExpiringDesk {
    server: SkippingClockServer,
    approver: SilentBoardDevice,
    _proxy: SilentBoardProxy,
}

fn open_expiring_desk_or_panic() -> ExpiringDesk {
    let Ok(proxy) = SilentBoardProxy::start() else {
        panic!("the silent board proxy starts");
    };
    let approver = SilentBoardDevice::start(&proxy);
    let Ok(approver) = approver else {
        panic!("the device starts behind the proxy: {approver:?}");
    };
    let server = SkippingClockServer::start();
    let Ok(server) = server else {
        panic!("the skipping clock server starts: {server:?}");
    };
    let account_command = server.build_create_account_command();
    let account = account_command.and_then(|command| approver.run(&command));
    if let Err(problem) = account {
        panic!("the approver creates an account: {problem}");
    }
    ExpiringDesk {
        server,
        approver,
        _proxy: proxy,
    }
}

fn join_with_shown_code(
    server: &SkippingClockServer,
    display_code: &str,
) -> Result<Value, String> {
    let joiner = TestDevice::start()?;
    join_at_address(&joiner, &server.address, display_code)
}

#[test]
fn test_withdraw_when_published_property_a_left_code_dies_with_its_session() {
    let expiring = open_expiring_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(EXPIRY_CASES));
    let seconds_past_expiry = 0..=MOST_SECONDS_PAST_EXPIRY;

    let outcome = runner.run(&seconds_past_expiry, |seconds_past| {
        let session = start_pairing(&expiring.approver).map_err(fail)?;
        let display_code =
            read_text(&session, "/display_code").map_err(fail)?;
        let past_expiry =
            PAIRING_SESSION_LIFETIME + TimeDelta::seconds(seconds_past);

        let server = &expiring.server;
        let expired_join = server.run_skipped_ahead(past_expiry, || {
            join_with_shown_code(server, &display_code)
        });
        let live_join = join_with_shown_code(server, &display_code);

        let reply_problem = &session["rendezvous_problem"];
        prop_assert!(reply_problem.is_string(), "{}", reply_problem);
        let refusal = expired_join.err().unwrap_or_default();
        prop_assert!(refusal.contains(EXPIRED_SESSION_MESSAGE), "{}", refusal);
        prop_assert!(live_join.is_ok(), "{:?}", live_join);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
