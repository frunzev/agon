use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::approver_desk::{
    APPROVED_STATE, PairingEnding, WAITING_STATE, open_desk_or_panic,
    read_approver_words, read_joiner_status, read_joiner_words, start_pairing,
};
use crate::support::pairing_steps::join_at_address;
use crate::support::test_device::{TestDevice, fail, read_text};

const JOIN_CASES: u32 = 2;
const MOST_READS: usize = 3;
const NO_PENDING_JOIN: &str = "no pairing request from this device is waiting";

fn ending_strategy() -> impl Strategy<Value = PairingEnding> {
    prop_oneof![Just(PairingEnding::Cancel), Just(PairingEnding::Reject)]
}

#[test]
fn test_read_join_status_property_without_a_join_nothing_waits() {
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));

    let outcome = runner.run(&(1..=MOST_READS), |read_count| {
        let device = TestDevice::start().map_err(fail)?;
        for _ in 0..read_count {
            let status = read_joiner_status(&device);
            prop_assert_eq!(status, Err(NO_PENDING_JOIN.to_owned()));
        }
        let status = device.run(&json!({ "command": "status" }));
        let status = status.map_err(fail)?;
        prop_assert_eq!(&status["pending_join"], &Value::Null);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_read_join_status_property_waits_without_words_before_the_approver() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));

    let outcome = runner.run(&(1..=MOST_READS), |read_count| {
        let joined = desk.start_and_join().map_err(fail)?;
        for _ in 0..read_count {
            let status = read_joiner_status(&joined.joiner).map_err(fail)?;
            let expected =
                json!({ "state": WAITING_STATE, "fingerprint_words": [] });
            prop_assert_eq!(status, expected);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_read_join_status_property_an_approval_is_reported_once() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));

    let outcome = runner.run(&(1..=MOST_READS), |read_count| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        let approver_words =
            read_approver_words(&desk.approver, &code).map_err(fail)?;
        desk.approve(&desk.approver, &code).map_err(fail)?;
        let approved = read_joiner_status(&joined.joiner).map_err(fail)?;

        prop_assert_eq!(&approved["state"], &json!(APPROVED_STATE));
        prop_assert_eq!(&approved["fingerprint_words"], &approver_words);
        for _ in 0..read_count {
            let again = read_joiner_status(&joined.joiner);
            prop_assert_eq!(again, Err(NO_PENDING_JOIN.to_owned()));
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_ended_join_property_an_ended_join_shows_only_its_state() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));
    let drawn = (ending_strategy(), any::<bool>());

    let outcome = runner.run(&drawn, |(ending, has_read_words)| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        if has_read_words {
            read_approver_words(&desk.approver, &code).map_err(fail)?;
        }
        desk.end(&desk.approver, ending, &code).map_err(fail)?;
        let ended = read_joiner_status(&joined.joiner).map_err(fail)?;

        let expected = json!({
            "state": ending.expected_join_state(),
            "fingerprint_words": [],
        });
        prop_assert_eq!(ended, expected);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_ended_join_property_an_ended_join_is_forgotten() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));

    let outcome = runner.run(&ending_strategy(), |ending| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        desk.end(&desk.approver, ending, &code).map_err(fail)?;
        read_joiner_status(&joined.joiner).map_err(fail)?;
        let again = read_joiner_status(&joined.joiner);
        let status = joined.joiner.run(&json!({ "command": "status" }));

        let status = status.map_err(fail)?;
        prop_assert_eq!(again, Err(NO_PENDING_JOIN.to_owned()));
        prop_assert_eq!(&status["pending_join"], &Value::Null);
        prop_assert_eq!(&status["account"], &Value::Null);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_ended_join_property_the_joiner_can_join_again_after_an_ending() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));

    let outcome = runner.run(&ending_strategy(), |ending| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        desk.end(&desk.approver, ending, &code).map_err(fail)?;
        read_joiner_status(&joined.joiner).map_err(fail)?;
        let second_session = start_pairing(&desk.approver).map_err(fail)?;
        let display_code =
            read_text(&second_session, "/display_code").map_err(fail)?;
        let rejoined = join_at_address(
            &joined.joiner,
            &desk.server.address,
            &display_code,
        );
        let status = read_joiner_status(&joined.joiner).map_err(fail)?;

        prop_assert!(rejoined.is_ok(), "{:?}", rejoined);
        prop_assert_eq!(&status["state"], &json!(WAITING_STATE));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_compute_joiner_words_property_both_sides_show_the_same_words() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));

    let outcome = runner.run(&(1..=MOST_READS), |read_count| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        let approver_words =
            read_approver_words(&desk.approver, &code).map_err(fail)?;

        prop_assert!(!approver_words.as_array().is_none_or(Vec::is_empty));
        for _ in 0..read_count {
            let joiner_words =
                read_joiner_words(&joined.joiner).map_err(fail)?;
            prop_assert_eq!(&joiner_words, &approver_words);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_compute_joiner_words_property_each_pairing_shows_its_own_words() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));

    let outcome = runner.run(&Just(()), |()| {
        let first = desk.start_and_join().map_err(fail)?;
        let second = desk.start_and_join().map_err(fail)?;
        let first_code = first.session["code"].clone();
        let second_code = second.session["code"].clone();
        read_approver_words(&desk.approver, &first_code).map_err(fail)?;
        read_approver_words(&desk.approver, &second_code).map_err(fail)?;
        let first_words = read_joiner_words(&first.joiner).map_err(fail)?;
        let second_words = read_joiner_words(&second.joiner).map_err(fail)?;

        prop_assert_ne!(first_words, second_words);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_compute_joiner_words_property_words_need_the_approver_reveal() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));

    let outcome = runner.run(&(1..=MOST_READS), |read_count| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        let before = read_joiner_words(&joined.joiner).map_err(fail)?;
        for _ in 0..read_count {
            read_approver_words(&desk.approver, &code).map_err(fail)?;
        }
        let after = read_joiner_words(&joined.joiner).map_err(fail)?;

        prop_assert_eq!(before, json!([]));
        prop_assert!(!after.as_array().is_none_or(Vec::is_empty));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
