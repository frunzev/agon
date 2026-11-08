use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::approver_desk::{
    APPROVED_STATE, PairingEnding, WAITING_STATE, WORDS_NOT_READY,
    open_desk_or_panic, read_approver_words, read_join_state, read_request,
    start_pairing,
};
use crate::meddling_server::JoiningRewrite;
use crate::support::test_device::fail;

const PAIRING_CASES: u32 = 2;
const MOST_READS: usize = 3;
const NOBODY_JOINED: &str = "nobody has entered the pairing code yet";

fn ending_strategy() -> impl Strategy<Value = PairingEnding> {
    prop_oneof![Just(PairingEnding::Cancel), Just(PairingEnding::Reject)]
}

#[test]
fn test_read_pairing_request_property_shows_the_session_before_a_join() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PAIRING_CASES));

    let outcome = runner.run(&any::<bool>(), |uses_display_code| {
        let session = start_pairing(&desk.approver).map_err(fail)?;
        let asked_code = if uses_display_code {
            session["display_code"].clone()
        } else {
            session["code"].clone()
        };
        let request =
            read_request(&desk.approver, &asked_code).map_err(fail)?;

        prop_assert_eq!(&request["joining"], &Value::Null);
        for field in ["code", "display_code", "started_at", "expires_at"] {
            prop_assert_eq!(&request[field], &session[field], "{}", field);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_read_pairing_request_property_repeated_reads_show_one_screen() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PAIRING_CASES));

    let outcome = runner.run(&(2..=MOST_READS), |read_count| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        let first = read_request(&desk.approver, &code).map_err(fail)?;

        for _ in 1..read_count {
            let again = read_request(&desk.approver, &code).map_err(fail)?;
            prop_assert_eq!(&again, &first);
        }
        prop_assert!(first["joining"].is_object(), "{}", first);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_approve_pairing_property_the_joiner_ends_approved() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PAIRING_CASES));

    let outcome = runner.run(&(1..=MOST_READS), |read_count| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        for _ in 0..read_count {
            read_request(&desk.approver, &code).map_err(fail)?;
        }
        let approved = desk.approve(&desk.approver, &code);
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;
        let again = desk.approve(&desk.approver, &code);

        prop_assert_eq!(approved, Ok(Value::Null));
        prop_assert_eq!(join_state, json!(APPROVED_STATE));
        prop_assert!(again.is_err(), "{:?}", again);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_approve_pairing_property_nobody_joined_nothing_to_approve() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PAIRING_CASES));

    let outcome = runner.run(&(1..=MOST_READS), |attempt_count| {
        let session = start_pairing(&desk.approver).map_err(fail)?;
        for _ in 0..attempt_count {
            let refused = desk.approve(&desk.approver, &session["code"]);
            prop_assert_eq!(refused, Err(NOBODY_JOINED.to_owned()));
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_approve_pairing_property_waits_for_the_joiner_nonce() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PAIRING_CASES));

    let outcome = runner.run(&(1..=MOST_READS), |attempt_count| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        desk.server
            .rewrite_joining(Some(JoiningRewrite::HiddenJoinerNonce));
        let mut refusals = Vec::new();
        for _ in 0..attempt_count {
            refusals.push(desk.approve(&desk.approver, &code));
        }
        let hidden_request = read_request(&desk.approver, &code);
        desk.reset_meddling();
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;

        for refusal in refusals {
            prop_assert_eq!(refusal, Err(WORDS_NOT_READY.to_owned()));
        }
        let hidden_request = hidden_request.map_err(fail)?;
        prop_assert_eq!(&hidden_request["joining"], &Value::Null);
        prop_assert_eq!(join_state, json!(WAITING_STATE));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_agree_on_transcript_property_the_nonce_is_revealed_once() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PAIRING_CASES));

    let outcome = runner.run(&(1..=MOST_READS), |read_count| {
        desk.reset_meddling();
        let reveals_before = desk.server.list_revealed_nonces().len();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        for _ in 0..read_count {
            read_request(&desk.approver, &code).map_err(fail)?;
        }
        desk.approve(&desk.approver, &code).map_err(fail)?;

        let reveals_after = desk.server.list_revealed_nonces().len();
        prop_assert_eq!(reveals_after - reveals_before, 1);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_agree_on_transcript_property_no_reveal_without_the_joiner_nonce() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PAIRING_CASES));

    let outcome = runner.run(&(1..=MOST_READS), |read_count| {
        desk.reset_meddling();
        let reveals_before = desk.server.list_revealed_nonces().len();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        desk.server
            .rewrite_joining(Some(JoiningRewrite::HiddenJoinerNonce));
        let mut screens = Vec::new();
        for _ in 0..read_count {
            screens.push(read_request(&desk.approver, &code));
        }
        let reveals_after = desk.server.list_revealed_nonces().len();
        desk.reset_meddling();

        for screen in screens {
            let screen = screen.map_err(fail)?;
            prop_assert_eq!(&screen["joining"], &Value::Null);
        }
        prop_assert_eq!(reveals_after, reveals_before);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_agree_on_transcript_property_each_pairing_reveals_a_fresh_nonce() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PAIRING_CASES));

    let outcome = runner.run(&(2..=MOST_READS), |pairing_count| {
        desk.reset_meddling();
        let reveals_before = desk.server.list_revealed_nonces().len();
        for _ in 0..pairing_count {
            let joined = desk.start_and_join().map_err(fail)?;
            let code = joined.session["code"].clone();
            read_request(&desk.approver, &code).map_err(fail)?;
        }
        let revealed = desk.server.list_revealed_nonces();

        let case_reveals = &revealed[reveals_before..];
        prop_assert_eq!(case_reveals.len(), pairing_count);
        for (index, nonce) in case_reveals.iter().enumerate() {
            prop_assert!(!case_reveals[..index].contains(nonce));
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_end_pairing_here_property_an_ended_code_cannot_be_approved() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PAIRING_CASES));

    let outcome = runner.run(&ending_strategy(), |ending| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        read_approver_words(&desk.approver, &code).map_err(fail)?;
        desk.end(&desk.approver, ending, &code).map_err(fail)?;
        let approved = desk.approve(&desk.approver, &code);
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;

        prop_assert!(approved.is_err(), "{:?}", approved);
        prop_assert_eq!(join_state, ending.expected_join_state());
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_end_pairing_here_property_ending_one_code_keeps_the_others() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PAIRING_CASES));

    let outcome = runner.run(&ending_strategy(), |ending| {
        let ended = desk.start_and_join().map_err(fail)?;
        let kept = desk.start_and_join().map_err(fail)?;
        let ended_code = ended.session["code"].clone();
        let kept_code = kept.session["code"].clone();
        let kept_words =
            read_approver_words(&desk.approver, &kept_code).map_err(fail)?;
        desk.end(&desk.approver, ending, &ended_code)
            .map_err(fail)?;
        let words_after =
            read_approver_words(&desk.approver, &kept_code).map_err(fail)?;
        let approved = desk.approve(&desk.approver, &kept_code);

        prop_assert_eq!(words_after, kept_words);
        prop_assert_eq!(approved, Ok(Value::Null));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
