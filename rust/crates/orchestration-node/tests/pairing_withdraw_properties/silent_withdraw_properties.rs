use std::sync::Mutex;
use std::time::{Duration, Instant};

use orchestration_node::code_rendezvous::RECORD_BOARD_WAIT_LIMIT;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::Value;

use crate::approver_desk::{
    ApproverDesk, PairingEnding, pairing_endings, read_approver_words,
    read_join_state,
};
use crate::at_once::{CommandOutcome, run_at_once};
use crate::slow_board::{SilentBoardDevice, SilentBoardProxy};
use crate::support::test_device::fail;

const SILENT_CASES: u32 = 3;
const CODES_AT_ONCE: usize = 2;
const SERVER_ANSWER_ALLOWANCE: Duration = Duration::from_secs(3);

struct SilentDesk {
    desk: ApproverDesk<SilentBoardDevice>,
    proxy: SilentBoardProxy,
}

#[derive(Debug)]
struct TimedEnding {
    ended: CommandOutcome,
    waited: Duration,
}

fn open_silent_desk_or_panic() -> SilentDesk {
    let Ok(proxy) = SilentBoardProxy::start() else {
        panic!("the silent board proxy starts");
    };
    let device = SilentBoardDevice::start(&proxy);
    let Ok(device) = device else {
        panic!("the device starts behind the proxy: {device:?}");
    };
    let desk = ApproverDesk::open_with(device);
    let Ok(desk) = desk else {
        panic!("the approver desk opens: {desk:?}");
    };
    SilentDesk { desk, proxy }
}

fn longest_fair_ending() -> Duration {
    RECORD_BOARD_WAIT_LIMIT + SERVER_ANSWER_ALLOWANCE
}

fn end_and_time(
    desk: &ApproverDesk<SilentBoardDevice>,
    ending: PairingEnding,
    code: &Value,
) -> TimedEnding {
    let started_at = Instant::now();
    let ended = desk.end(&desk.approver, ending, code);
    let waited = started_at.elapsed();
    TimedEnding { ended, waited }
}

#[test]
fn test_withdraw_when_published_property_every_ending_answers_in_time() {
    let silent = open_silent_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SILENT_CASES));

    let outcome = runner.run(&pairing_endings(), |ending| {
        let desk = &silent.desk;
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        read_approver_words(&desk.approver, &code).map_err(fail)?;

        let timed = end_and_time(desk, ending, &code);
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;

        prop_assert_eq!(timed.ended, Ok(Value::Null));
        let waited = timed.waited;
        prop_assert!(waited < longest_fair_ending(), "{:?}", waited);
        prop_assert_eq!(join_state, ending.expected_join_state());
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_withdraw_when_published_property_an_ended_code_admits_nobody() {
    let silent = open_silent_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SILENT_CASES));

    let outcome = runner.run(&pairing_endings(), |ending| {
        let desk = &silent.desk;
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        read_approver_words(&desk.approver, &code).map_err(fail)?;
        desk.end(&desk.approver, ending, &code).map_err(fail)?;
        let tunnels_before =
            silent.proxy.count_board_tunnels().map_err(fail)?;

        let late_joiner = desk.join(&joined.session);
        let approved_again = desk.approve(&desk.approver, &code);
        let tunnels_after =
            silent.proxy.count_board_tunnels().map_err(fail)?;

        prop_assert!(late_joiner.is_err(), "{:?}", late_joiner);
        prop_assert!(approved_again.is_err(), "{:?}", approved_again);
        prop_assert_eq!(tunnels_after, tunnels_before);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_withdraw_when_published_property_endings_at_once_answer_in_time() {
    let silent = open_silent_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SILENT_CASES));

    let outcome = runner.run(&pairing_endings(), |ending| {
        let desk = &silent.desk;
        let mut joiners = Vec::new();
        let mut codes = Vec::new();
        for _ in 0..CODES_AT_ONCE {
            let joined = desk.start_and_join().map_err(fail)?;
            let code = joined.session["code"].clone();
            read_approver_words(&desk.approver, &code).map_err(fail)?;
            codes.push(code);
            joiners.push(joined.joiner);
        }

        let codes_left = Mutex::new(codes);
        let ending_task = || desk.end_next(&codes_left, ending);
        let started_at = Instant::now();
        let endings = run_at_once(CODES_AT_ONCE, &ending_task);
        let waited = started_at.elapsed();

        for ended in endings {
            prop_assert_eq!(ended, Ok(Value::Null));
        }
        prop_assert!(waited < longest_fair_ending(), "{:?}", waited);
        for joiner in &joiners {
            let join_state = read_join_state(joiner).map_err(fail)?;
            prop_assert_eq!(join_state, ending.expected_join_state());
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
