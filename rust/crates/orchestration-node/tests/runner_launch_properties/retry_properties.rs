use std::collections::VecDeque;
use std::future::ready;
use std::time::Duration;

use orchestration_node::node_error::NodeError;
use orchestration_node::runner_bridge::{
    FIRST_RETRY_DELAY, LONGEST_RETRY_DELAY, is_transient_failure,
    next_retry_delay, retry_transient,
};
use proptest::prelude::*;
use proptest::strategy::LazyJust;
use tokio::time::Instant;

use crate::support::test_device::fail;

const NOT_ACTIVE_STATUS: u16 = 421;
const MOST_FAILURES: usize = 16;
const MOST_DELAY_MILLISECONDS: u64 = 120_000;
const STEPS_TO_THE_CAP: usize = 6;
const ANSWER: u32 = 7;

type ScriptedAnswer = Result<u32, NodeError>;

fn server_error() -> impl Strategy<Value = NodeError> {
    (500_u16..600).prop_map(|status| NodeError::ServerRejected {
        status,
        message: "the server broke".to_owned(),
    })
}

fn not_active_answer() -> NodeError {
    NodeError::ServerRejected {
        status: NOT_ACTIVE_STATUS,
        message: "this app server is a backup".to_owned(),
    }
}

fn transient_failure() -> impl Strategy<Value = NodeError> {
    prop_oneof![
        "\\PC{0,20}".prop_map(NodeError::ServerUnreachable),
        server_error(),
        LazyJust::new(not_active_answer),
    ]
}

fn transient_failures() -> impl Strategy<Value = Vec<NodeError>> {
    prop::collection::vec(transient_failure(), 0..MOST_FAILURES)
}

fn permanent_failure() -> impl Strategy<Value = NodeError> {
    prop_oneof![
        (400_u16..500)
            .prop_filter("not the backup answer", |status| {
                *status != NOT_ACTIVE_STATUS
            })
            .prop_map(|status| NodeError::ServerRejected {
                status,
                message: "the request was refused".to_owned(),
            }),
        (100_u16..400).prop_map(|status| NodeError::ServerRejected {
            status,
            message: "an odd answer".to_owned(),
        }),
        "\\PC{0,20}".prop_map(NodeError::UntrustedDecision),
        "\\PC{0,20}".prop_map(NodeError::UnexpectedAnswer),
        LazyJust::new(|| NodeError::NoAccount),
        LazyJust::new(|| NodeError::UntrustedPeer),
    ]
}

fn record_pauses(
    script: Vec<ScriptedAnswer>,
) -> Result<(ScriptedAnswer, Vec<Duration>), TestCaseError> {
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_time()
        .start_paused(true)
        .build()
        .map_err(fail)?;
    let mut answers: VecDeque<ScriptedAnswer> = script.into();
    let mut attempt_moments = Vec::new();

    let outcome = runtime.block_on(retry_transient(|| {
        attempt_moments.push(Instant::now());
        let answer = answers.pop_front().unwrap_or(Ok(ANSWER));
        ready(answer)
    }));

    let mut pauses = Vec::new();
    for pair in attempt_moments.windows(2) {
        pauses.push(pair[1].duration_since(pair[0]));
    }
    Ok((outcome, pauses))
}

proptest! {
    #[test]
    fn test_is_transient_failure_property_lost_links_and_crashes_retry(
        failure in prop_oneof![
            "\\PC{0,20}".prop_map(NodeError::ServerUnreachable),
            server_error(),
        ],
    ) {
        prop_assert!(is_transient_failure(&failure), "{}", failure);
    }

    #[test]
    fn test_is_transient_failure_property_refusals_are_permanent(
        failure in permanent_failure(),
    ) {
        prop_assert!(!is_transient_failure(&failure), "{}", failure);
    }

    #[test]
    fn test_is_transient_failure_property_a_backup_server_answer_retries(
        message in "\\PC{0,30}",
    ) {
        let backup_answer = NodeError::ServerRejected {
            status: NOT_ACTIVE_STATUS,
            message,
        };

        prop_assert!(is_transient_failure(&backup_answer));
    }

    #[test]
    fn test_next_retry_delay_property_never_shrinks_and_stays_capped(
        milliseconds in 0..MOST_DELAY_MILLISECONDS,
    ) {
        let delay = Duration::from_millis(milliseconds);

        let next_delay = next_retry_delay(delay);

        prop_assert!(next_delay <= LONGEST_RETRY_DELAY);
        prop_assert!(next_delay >= delay.min(LONGEST_RETRY_DELAY));
    }

    #[test]
    fn test_next_retry_delay_property_settles_on_the_longest_delay(
        extra_steps in 0_usize..20,
        huge_seconds in any::<u64>(),
    ) {
        let mut delay = FIRST_RETRY_DELAY;
        for _ in 0..STEPS_TO_THE_CAP + extra_steps {
            delay = next_retry_delay(delay);
        }
        let huge_delay = Duration::from_secs(huge_seconds);

        prop_assert_eq!(delay, LONGEST_RETRY_DELAY);
        prop_assert_eq!(next_retry_delay(delay), LONGEST_RETRY_DELAY);
        prop_assert_eq!(next_retry_delay(huge_delay), LONGEST_RETRY_DELAY);
    }

    #[test]
    fn test_retry_transient_property_pauses_grow_within_the_limits(
        failures in transient_failures(),
    ) {
        let failure_count = failures.len();
        let script: Vec<ScriptedAnswer> =
            failures.into_iter().map(Err).collect();

        let (outcome, pauses) = record_pauses(script)?;

        prop_assert_eq!(outcome.ok(), Some(ANSWER));
        prop_assert_eq!(pauses.len(), failure_count);
        if let Some(first_pause) = pauses.first() {
            prop_assert_eq!(*first_pause, FIRST_RETRY_DELAY);
        }
        for pair in pauses.windows(2) {
            prop_assert!(pair[0] <= pair[1], "{:?}", pauses);
        }
        for pause in &pauses {
            prop_assert!(*pause <= LONGEST_RETRY_DELAY, "{:?}", pauses);
        }
    }

    #[test]
    fn test_retry_transient_property_a_permanent_refusal_is_never_retried(
        failures in transient_failures(),
        refusal in permanent_failure(),
    ) {
        let failure_count = failures.len();
        let refusal_text = refusal.to_string();
        let mut script: Vec<ScriptedAnswer> =
            failures.into_iter().map(Err).collect();
        script.push(Err(refusal));

        let (outcome, pauses) = record_pauses(script)?;

        let outcome_text = outcome.map_err(|problem| problem.to_string());
        prop_assert_eq!(outcome_text, Err(refusal_text));
        prop_assert_eq!(pauses.len(), failure_count);
    }
}
