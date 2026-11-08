use orchestration_security::pairing::{
    FINGERPRINT_WORD_COUNT, FINGERPRINT_WORD_LIST,
};
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::pairing_steps::{
    StartedJoin, approve_into_first_workspace, read_both_words, start_join,
};
use crate::support::test_device::fail;
use crate::work_desk::CheckOutcome;

const PAIRING_CASES: u32 = 3;
const MOST_READS: usize = 3;

fn check_joins<Check>(check: Check)
where
    Check: Fn(&StartedJoin, usize) -> CheckOutcome,
{
    let mut runner = TestRunner::new(Config::with_cases(PAIRING_CASES));
    let outcome = runner.run(&(1..=MOST_READS), |read_count| {
        let started = start_join().map_err(fail)?;
        check(&started, read_count)
    });
    assert!(outcome.is_ok(), "{outcome:?}");
}

fn read_word_list(words: &Value) -> Vec<String> {
    let mut word_list = Vec::new();
    for word in words.as_array().cloned().unwrap_or_default() {
        word_list.push(word.as_str().unwrap_or_default().to_owned());
    }
    word_list
}

fn read_shown_words(started: &StartedJoin) -> Result<(Value, Value), String> {
    let shown = read_both_words(
        &started.prepared.device,
        &started.joining_device,
        &started.session,
    )?;
    Ok((shown.approver_words, shown.joiner_words))
}

#[test]
fn test_list_fingerprint_words_property_both_sides_show_the_same_words() {
    check_joins(|started, read_count| {
        for _ in 0..read_count {
            let (approver_words, joiner_words) =
                read_shown_words(started).map_err(fail)?;
            prop_assert_eq!(&approver_words, &joiner_words);
            let word_list = read_word_list(&approver_words);
            prop_assert_eq!(word_list.len(), FINGERPRINT_WORD_COUNT);
        }
        Ok(())
    });
}

#[test]
fn test_list_fingerprint_words_property_every_word_is_from_the_list() {
    check_joins(|started, read_count| {
        for _ in 0..read_count {
            let (approver_words, _) =
                read_shown_words(started).map_err(fail)?;
            for word in read_word_list(&approver_words) {
                prop_assert!(
                    FINGERPRINT_WORD_LIST.contains(&word.as_str()),
                    "{}",
                    word
                );
            }
        }
        Ok(())
    });
}

#[test]
fn test_list_fingerprint_words_property_approval_keeps_the_words() {
    check_joins(|started, read_count| {
        let (approver_words, _) = read_shown_words(started).map_err(fail)?;
        for _ in 1..read_count {
            let (again, _) = read_shown_words(started).map_err(fail)?;
            prop_assert_eq!(&again, &approver_words);
        }
        let account = started
            .prepared
            .device
            .run(&json!({ "command": "status" }))
            .map_err(fail)?;
        approve_into_first_workspace(
            &started.prepared.device,
            &started.session,
            &account["account"],
        )
        .map_err(fail)?;

        let approved = started
            .joining_device
            .run(&json!({ "command": "join_status" }))
            .map_err(fail)?;

        prop_assert_eq!(&approved["state"], "approved");
        prop_assert_eq!(&approved["fingerprint_words"], &approver_words);
        Ok(())
    });
}
