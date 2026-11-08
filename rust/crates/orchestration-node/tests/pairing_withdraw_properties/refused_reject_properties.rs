use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::approver_desk::{
    ApproverDesk, DESK_CASES, NOT_STARTED_HERE, PairingEnding, REJECTED_STATE,
    open_desk_or_panic, read_approver_words, read_join_state,
    read_joiner_words, read_request, read_status_problem, start_pairing,
};
use crate::command_device::crossing_relay_choices;
use crate::meddling_server::{EndingAnswer, REFUSED_ENDING_MESSAGE};
use crate::support::test_device::fail;

const MOST_READS: usize = 2;
const NO_PEER_ENDPOINT: &str = "this node has no peer endpoint";

fn refusable_endings() -> impl Strategy<Value = PairingEnding> {
    prop_oneof![Just(PairingEnding::Reject), Just(PairingEnding::Cancel)]
}

#[test]
fn test_end_pairing_property_a_refused_ending_forgets_the_code() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));
    let refusals = (refusable_endings(), 0..=MOST_READS);

    let outcome = runner.run(&refusals, |(ending, reads_before)| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        for _ in 0..reads_before {
            read_request(&desk.approver, &code).map_err(fail)?;
        }

        desk.server.answer_endings(EndingAnswer::Refused);
        let refused = desk.end(&desk.approver, ending, &code);
        desk.reset_meddling();
        let read_after = read_request(&desk.approver, &code);
        let approved_after = desk.approve(&desk.approver, &code);

        let refusal = refused.err().unwrap_or_default();
        prop_assert!(refusal.contains(REFUSED_ENDING_MESSAGE), "{}", refusal);
        prop_assert_eq!(read_after, Err(NOT_STARTED_HERE.to_owned()));
        prop_assert_eq!(approved_after, Err(NOT_STARTED_HERE.to_owned()));
        Ok(())
    });

    desk.reset_meddling();
    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_end_pairing_property_a_refused_reject_keeps_other_codes() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&any::<bool>(), |rejects_the_older| {
        desk.reset_meddling();
        let older = desk.start_and_join().map_err(fail)?;
        let newer = desk.start_and_join().map_err(fail)?;
        let (refused, kept) = if rejects_the_older {
            (older, newer)
        } else {
            (newer, older)
        };

        desk.server.answer_endings(EndingAnswer::Refused);
        let refused_code = refused.session["code"].clone();
        let rejected =
            desk.end(&desk.approver, PairingEnding::Reject, &refused_code);
        desk.reset_meddling();
        let kept_code = kept.session["code"].clone();
        let kept_words =
            read_approver_words(&desk.approver, &kept_code).map_err(fail)?;
        let joiner_words = read_joiner_words(&kept.joiner).map_err(fail)?;
        let approved_kept = desk.approve(&desk.approver, &kept_code);

        prop_assert!(rejected.is_err(), "{:?}", rejected);
        prop_assert_eq!(kept_words, joiner_words);
        prop_assert_eq!(approved_kept, Ok(Value::Null));
        Ok(())
    });

    desk.reset_meddling();
    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_end_pairing_property_a_refused_reject_can_be_retried() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DESK_CASES));

    let outcome = runner.run(&(1..=MOST_READS), |refusal_count| {
        desk.reset_meddling();
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();

        desk.server.answer_endings(EndingAnswer::Refused);
        for _ in 0..refusal_count {
            let refused =
                desk.end(&desk.approver, PairingEnding::Reject, &code);
            prop_assert!(refused.is_err(), "{:?}", refused);
        }
        desk.reset_meddling();
        let retried = desk.end(&desk.approver, PairingEnding::Reject, &code);
        let join_state = read_join_state(&joined.joiner).map_err(fail)?;

        prop_assert_eq!(retried, Ok(Value::Null));
        prop_assert_eq!(join_state, json!(REJECTED_STATE));
        Ok(())
    });

    desk.reset_meddling();
    assert!(outcome.is_ok(), "{outcome:?}");
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DESK_CASES))]

    #[test]
    fn test_end_pairing_property_a_refused_reject_clears_the_problem(
        peer_relay in crossing_relay_choices(),
        ending in refusable_endings(),
    ) {
        let desk = ApproverDesk::open_bare(peer_relay).map_err(fail)?;
        let session = start_pairing(&desk.approver).map_err(fail)?;
        let problem_before =
            read_status_problem(&desk.approver).map_err(fail)?;

        desk.server.answer_endings(EndingAnswer::Refused);
        let refused = desk.end(&desk.approver, ending, &session["code"]);
        desk.reset_meddling();
        let problem_after =
            read_status_problem(&desk.approver).map_err(fail)?;

        prop_assert_eq!(problem_before, json!(NO_PEER_ENDPOINT));
        prop_assert!(refused.is_err(), "{:?}", refused);
        prop_assert_eq!(problem_after, Value::Null);
    }
}
