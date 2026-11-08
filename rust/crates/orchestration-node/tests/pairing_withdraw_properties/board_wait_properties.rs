use std::future::pending;
use std::time::Duration;

use orchestration_node::code_rendezvous::{
    RECORD_BOARD_WAIT_LIMIT, wait_for_record_board,
};
use orchestration_node::node_error::NodeError;
use orchestration_p2p::peer_error::PeerError;
use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use tokio::runtime::Builder;
use tokio::time::{Instant, sleep};

use crate::support::test_device::fail;

const WAIT_CASES: u32 = 64;
const MOST_SILENT_WAITS: usize = 4;
const LONGEST_LATENESS_MILLISECONDS: u64 = 120_000;
const PAUSED_CLOCK_TICK: Duration = Duration::from_millis(1);
const SILENCE_START: &str = "the code could not be published or looked up: \
                             the public record board could not be \
                             reached: no answer within ";
const SECONDS_END: &str = " seconds";

type BoardOutcome = Result<u64, NodeError>;

#[derive(Debug)]
struct TimedOutcome {
    outcome: BoardOutcome,
    waited: Duration,
}

fn wait_on_paused_clock(
    board_work: impl Future<Output = BoardOutcome>,
) -> Result<TimedOutcome, TestCaseError> {
    let runtime = Builder::new_current_thread()
        .enable_time()
        .start_paused(true)
        .build()
        .map_err(fail)?;
    let timed_outcome = runtime.block_on(async {
        let started_at = Instant::now();
        let outcome = wait_for_record_board(board_work).await;
        let waited = started_at.elapsed();
        TimedOutcome { outcome, waited }
    });
    Ok(timed_outcome)
}

async fn answer_after(delay: Duration, answer: BoardOutcome) -> BoardOutcome {
    sleep(delay).await;
    answer
}

fn is_silent_board(outcome: &BoardOutcome) -> bool {
    matches!(
        outcome,
        Err(NodeError::Rendezvous(PeerError::RecordBoardUnreachable(_)))
    )
}

fn is_about(waited: Duration, expected: Duration) -> bool {
    waited >= expected && waited <= expected + PAUSED_CLOCK_TICK
}

fn wait_limit_milliseconds() -> u64 {
    let limit_milliseconds = RECORD_BOARD_WAIT_LIMIT.as_millis();
    u64::try_from(limit_milliseconds).unwrap_or(u64::MAX)
}

fn lateness_strategy() -> impl Strategy<Value = Duration> {
    let milliseconds = 1..=LONGEST_LATENESS_MILLISECONDS;
    milliseconds.prop_map(Duration::from_millis)
}

fn early_delay_strategy() -> impl Strategy<Value = Duration> {
    let milliseconds = 0..wait_limit_milliseconds();
    milliseconds.prop_map(Duration::from_millis)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(WAIT_CASES))]

    #[test]
    fn test_wait_for_record_board_property_a_silent_board_ends_at_the_limit(
        silent_wait_count in 1..=MOST_SILENT_WAITS,
    ) {
        for _ in 0..silent_wait_count {
            let silent_board = pending::<BoardOutcome>();
            let timed = wait_on_paused_clock(silent_board)?;

            prop_assert!(is_silent_board(&timed.outcome), "{:?}", timed);
            prop_assert!(
                is_about(timed.waited, RECORD_BOARD_WAIT_LIMIT),
                "{:?}",
                timed.waited
            );
        }
    }

    #[test]
    fn test_wait_for_record_board_property_a_late_answer_is_never_awaited(
        lateness in lateness_strategy(),
        late_answer in any::<u64>(),
    ) {
        let answer_delay = RECORD_BOARD_WAIT_LIMIT + lateness;
        let late_board = answer_after(answer_delay, Ok(late_answer));

        let timed = wait_on_paused_clock(late_board)?;

        prop_assert!(is_silent_board(&timed.outcome), "{:?}", timed);
        prop_assert!(timed.waited < answer_delay, "{:?}", timed.waited);
        prop_assert!(
            is_about(timed.waited, RECORD_BOARD_WAIT_LIMIT),
            "{:?}",
            timed.waited
        );
    }

    #[test]
    fn test_wait_for_record_board_property_an_early_answer_passes_through(
        answer_delay in early_delay_strategy(),
        early_answer in any::<u64>(),
    ) {
        let early_board = answer_after(answer_delay, Ok(early_answer));

        let timed = wait_on_paused_clock(early_board)?;

        let answered = timed.outcome.map_err(fail)?;
        prop_assert_eq!(answered, early_answer);
        prop_assert!(
            is_about(timed.waited, answer_delay),
            "{:?}",
            timed.waited
        );
    }

    #[test]
    fn test_wait_for_record_board_property_an_early_refusal_passes_through(
        answer_delay in early_delay_strategy(),
        refused_status in 100_u16..600,
    ) {
        let refusal = PeerError::RecordRefused(refused_status);
        let refused = Err(NodeError::Rendezvous(refusal));
        let refusing_board = answer_after(answer_delay, refused);

        let timed = wait_on_paused_clock(refusing_board)?;

        let is_same_refusal = matches!(
            timed.outcome,
            Err(NodeError::Rendezvous(PeerError::RecordRefused(status)))
                if status == refused_status
        );
        prop_assert!(is_same_refusal, "{:?}", timed);
        prop_assert!(
            is_about(timed.waited, answer_delay),
            "{:?}",
            timed.waited
        );
    }

    #[test]
    fn test_wait_for_record_board_property_the_silence_names_the_limit(
        lateness in lateness_strategy(),
    ) {
        let answer_delay = RECORD_BOARD_WAIT_LIMIT + lateness;
        let late_board = answer_after(answer_delay, Ok(0));

        let timed = wait_on_paused_clock(late_board)?;

        let Err(silence) = timed.outcome else {
            return Err(fail("a late board was waited for"));
        };
        let limit_seconds = RECORD_BOARD_WAIT_LIMIT.as_secs();
        let expected_silence =
            format!("{SILENCE_START}{limit_seconds}{SECONDS_END}");
        prop_assert!(limit_seconds >= 1);
        prop_assert_eq!(silence.to_string(), expected_silence);
    }
}
