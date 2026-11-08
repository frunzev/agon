use orchestration_security::pairing::FINGERPRINT_WORD_COUNT;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::json;

use crate::approver_desk::{
    TRANSCRIPT_CHANGED, WAITING_STATE, changing_rewrites, open_desk_or_panic,
    read_join_state, read_joiner_words, read_request,
};
use crate::meddling_server::JoiningRewrite;
use crate::support::pairing_steps::JOINING_NAME;
use crate::support::test_device::fail;

const SCREEN_CASES: u32 = 2;
const MOST_READS: usize = 3;
const JOINING_ROLE: &str = "client";

#[test]
fn test_require_unchanged_join_property_a_changed_join_is_refused() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SCREEN_CASES));

    let outcome = runner.run(&changing_rewrites(), |rewrite| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        read_request(&desk.approver, &code).map_err(fail)?;
        desk.server.rewrite_joining(Some(rewrite));
        let changed_read = read_request(&desk.approver, &code);
        let changed_approval = desk.approve(&desk.approver, &code);
        desk.reset_meddling();
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;

        let refusal = Err(TRANSCRIPT_CHANGED.to_owned());
        prop_assert_eq!(changed_read, refusal.clone());
        prop_assert_eq!(changed_approval, refusal);
        prop_assert_eq!(join_state, json!(WAITING_STATE));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_require_unchanged_join_property_an_unchanged_join_reads_again() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SCREEN_CASES));

    let outcome = runner.run(&(2..=MOST_READS), |read_count| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();

        let mut screens = Vec::new();
        for _ in 0..read_count {
            screens.push(read_request(&desk.approver, &code).map_err(fail)?);
        }
        for screen in &screens {
            prop_assert_eq!(&screen["joining"], &screens[0]["joining"]);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_require_unchanged_join_property_the_change_check_survives_a_reset() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SCREEN_CASES));

    let outcome = runner.run(&changing_rewrites(), |rewrite| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        let first = read_request(&desk.approver, &code).map_err(fail)?;
        desk.server.rewrite_joining(Some(rewrite));
        read_request(&desk.approver, &code).ok();
        desk.reset_meddling();
        let restored = read_request(&desk.approver, &code).map_err(fail)?;
        let approved = desk.approve(&desk.approver, &code);

        prop_assert_eq!(&restored["joining"], &first["joining"]);
        prop_assert!(approved.is_ok(), "{:?}", approved);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_joiner_keys_of_property_the_shown_key_is_the_joiners_own() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SCREEN_CASES));

    let outcome = runner.run(&Just(()), |()| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        let screen = read_request(&desk.approver, &code).map_err(fail)?;
        let identity = joined.joiner.load_identity().map_err(fail)?;

        let own_key = identity.public_identity().sealing_public_key;
        prop_assert_eq!(
            &screen["joining"]["sealing_public_key"],
            &json!(own_key)
        );
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_joiner_keys_of_property_each_key_alone_counts() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SCREEN_CASES));
    let key_rewrite = prop_oneof![
        Just(JoiningRewrite::SigningKey),
        Just(JoiningRewrite::SealingKey),
    ];

    let outcome = runner.run(&key_rewrite, |rewrite| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        read_request(&desk.approver, &code).map_err(fail)?;
        desk.server.rewrite_joining(Some(rewrite));
        let changed = read_request(&desk.approver, &code);
        desk.reset_meddling();

        prop_assert_eq!(changed, Err(TRANSCRIPT_CHANGED.to_owned()));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_joiner_keys_of_property_a_key_swapped_before_the_words_is_shown() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SCREEN_CASES));

    let outcome = runner.run(&Just(JoiningRewrite::SealingKey), |rewrite| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        desk.server.rewrite_joining(Some(rewrite));
        let screen = read_request(&desk.approver, &code).map_err(fail)?;
        desk.reset_meddling();
        let identity = joined.joiner.load_identity().map_err(fail)?;
        let approver_words = screen["joining"]["fingerprint_words"].clone();
        let joiner_words = read_joiner_words(&joined.joiner).map_err(fail)?;

        let own_key = json!(identity.public_identity().sealing_public_key);
        prop_assert_ne!(&screen["joining"]["sealing_public_key"], &own_key);
        prop_assert_ne!(approver_words, joiner_words);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_describe_joining_property_names_the_joining_device() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SCREEN_CASES));

    let outcome = runner.run(&Just(()), |()| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        let screen = read_request(&desk.approver, &code).map_err(fail)?;

        let joining = &screen["joining"];
        prop_assert_eq!(&joining["name"], &json!(JOINING_NAME));
        prop_assert_eq!(&joining["role"], &json!(JOINING_ROLE));
        prop_assert!(joining["kind"].is_string(), "{}", joining);
        prop_assert!(joining["key_kind"].is_string(), "{}", joining);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_describe_joining_property_shows_a_fixed_number_of_words() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SCREEN_CASES));

    let outcome = runner.run(&Just(()), |()| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        let screen = read_request(&desk.approver, &code).map_err(fail)?;

        let words = screen["joining"]["fingerprint_words"]
            .as_array()
            .cloned()
            .unwrap_or_default();
        prop_assert_eq!(words.len(), FINGERPRINT_WORD_COUNT, "{:?}", words);
        for word in &words {
            let text = word.as_str().unwrap_or_default();
            prop_assert!(!text.is_empty(), "{:?}", words);
            prop_assert!(text.chars().all(char::is_alphabetic), "{}", text);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_describe_joining_property_the_screen_fields_are_complete() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SCREEN_CASES));

    let outcome = runner.run(&Just(()), |()| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        let screen = read_request(&desk.approver, &code).map_err(fail)?;

        let joining =
            screen["joining"].as_object().cloned().unwrap_or_default();
        let mut field_names: Vec<&str> =
            joining.keys().map(String::as_str).collect();
        field_names.sort_unstable();
        let expected = vec![
            "fingerprint_words",
            "key_kind",
            "kind",
            "name",
            "role",
            "sealing_public_key",
        ];
        prop_assert_eq!(field_names, expected);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
