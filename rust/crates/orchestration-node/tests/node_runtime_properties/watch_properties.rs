use std::time::{Duration, Instant};

use orchestration_api::work::RunEvent;
use orchestration_core::identifiers::RunId;
use orchestration_core::repository_files::RepositoryBranches;
use orchestration_core::run::StepStatus;
use orchestration_node::live_link_messages::{
    ClientMessage, FileAnswer, RunnerMessage,
};
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::fake_runner::RunnerAnswer;
use crate::support::test_device::fail;
use crate::watch_desk::{
    NO_ACTIVE_RUNNER, UNREACHABLE_LINK, change_claimed_step,
    open_unclaimed_desk, open_watch_desk, read_watch_problem,
    watch_claimed_run, watch_run,
};

const WATCH_CASES: u32 = 2;
const MOST_WATCHES: usize = 3;
const LINK_ANSWER_LIMIT: Duration = Duration::from_secs(5);
const LATE_ANSWER_SLACK: Duration = Duration::from_secs(10);
const LATE_ANSWER_PROBLEM: &str =
    "the runner did not answer the live link in time";
const REFUSAL_START: &str = "the runner refused the live link: ";
const CLOSED_LINK_REASON: &str = "the runner closed the link";
const EARLY_EVENTS_PROBLEM: &str = "the live link message could not be read: \
     the runner sent events before accepting";

fn finished_status_strategy() -> impl Strategy<Value = StepStatus> {
    prop::sample::select(vec![
        StepStatus::Done,
        StepStatus::Failed,
        StepStatus::Skipped,
    ])
}

fn early_answer_strategy() -> impl Strategy<Value = RunnerMessage> {
    prop_oneof![
        Just(RunnerMessage::Events { events: Vec::new() }),
        Just(RunnerMessage::Events {
            events: vec![RunEvent::Finished],
        }),
        Just(RunnerMessage::Answered {
            answer: FileAnswer::Branches {
                branches: RepositoryBranches::default(),
            },
        }),
    ]
}

fn watched_run_ids(messages: &[ClientMessage]) -> Vec<RunId> {
    let mut run_ids = Vec::new();
    for message in messages {
        if let ClientMessage::Watch { run_id } = message {
            run_ids.push(*run_id);
        }
    }
    run_ids
}

fn accepting_answer() -> RunnerAnswer {
    RunnerAnswer::Reply(RunnerMessage::Accepted)
}

fn is_linked(view: &Value) -> bool {
    view["link"] != json!(UNREACHABLE_LINK) && view["problem"].is_null()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(WATCH_CASES))]

    #[test]
    fn test_connect_to_runner_property_links_once_while_linked(
        watch_count in 1..=MOST_WATCHES,
    ) {
        let desk = open_watch_desk(accepting_answer()).map_err(fail)?;

        let mut views = Vec::new();
        for _ in 0..watch_count {
            views.push(watch_claimed_run(&desk).map_err(fail)?);
        }

        for view in &views {
            prop_assert!(is_linked(view), "{}", view);
        }
        let run_id = desk.claimed.assignment.run.id;
        let received = desk.fake_runner.received();
        prop_assert_eq!(watched_run_ids(&received), vec![run_id]);
        prop_assert_eq!(received.len(), 1);
    }

    #[test]
    fn test_open_watch_property_a_refusal_carries_the_reason(
        reason in "[a-zA-Z0-9 .,]{1,40}",
    ) {
        let refusal = RunnerMessage::Refused { reason: reason.clone() };
        let desk =
            open_watch_desk(RunnerAnswer::Reply(refusal)).map_err(fail)?;

        let view = watch_claimed_run(&desk).map_err(fail)?;

        prop_assert_eq!(&view["link"], &json!(UNREACHABLE_LINK));
        let expected = format!("{REFUSAL_START}{reason}");
        prop_assert_eq!(read_watch_problem(&view), expected);
        prop_assert_eq!(desk.fake_runner.received().len(), 1);
    }

    #[test]
    fn test_open_watch_property_a_closed_link_is_a_refusal(
        watch_count in 1..=MOST_WATCHES,
    ) {
        let desk = open_watch_desk(RunnerAnswer::CloseTheLink)
            .map_err(fail)?;

        let mut problems = Vec::new();
        for _ in 0..watch_count {
            let view = watch_claimed_run(&desk).map_err(fail)?;
            problems.push(read_watch_problem(&view));
        }

        let expected = format!("{REFUSAL_START}{CLOSED_LINK_REASON}");
        for problem in &problems {
            prop_assert_eq!(problem, &expected);
        }
        prop_assert_eq!(desk.fake_runner.received().len(), watch_count);
    }

    #[test]
    fn test_open_watch_property_answers_before_accepting_are_malformed(
        early_answer in early_answer_strategy(),
    ) {
        let desk = open_watch_desk(RunnerAnswer::Reply(early_answer))
            .map_err(fail)?;

        let view = watch_claimed_run(&desk).map_err(fail)?;

        prop_assert_eq!(&view["link"], &json!(UNREACHABLE_LINK));
        prop_assert_eq!(read_watch_problem(&view), EARLY_EVENTS_PROBLEM);
    }

    #[test]
    fn test_find_active_runner_property_a_finished_step_has_no_runner(
        finished_status in finished_status_strategy(),
    ) {
        let desk = open_watch_desk(accepting_answer()).map_err(fail)?;
        change_claimed_step(&desk, finished_status).map_err(fail)?;

        let view = watch_claimed_run(&desk).map_err(fail)?;

        prop_assert_eq!(read_watch_problem(&view), NO_ACTIVE_RUNNER);
        prop_assert!(desk.fake_runner.received().is_empty());
    }

    #[test]
    fn test_find_active_runner_property_waiting_for_approval_keeps_it(
        watch_count in 1..=MOST_WATCHES,
    ) {
        let desk = open_watch_desk(accepting_answer()).map_err(fail)?;
        change_claimed_step(&desk, StepStatus::WaitingForApproval)
            .map_err(fail)?;

        let mut views = Vec::new();
        for _ in 0..watch_count {
            views.push(watch_claimed_run(&desk).map_err(fail)?);
        }

        for view in &views {
            prop_assert!(is_linked(view), "{}", view);
        }
        let run_id = desk.claimed.assignment.run.id;
        let received = desk.fake_runner.received();
        prop_assert_eq!(watched_run_ids(&received), vec![run_id]);
    }

    #[test]
    fn test_find_active_runner_property_an_unclaimed_run_has_no_runner(
        watch_count in 1..=MOST_WATCHES,
    ) {
        let desk = open_unclaimed_desk(accepting_answer()).map_err(fail)?;

        let mut problems = Vec::new();
        for _ in 0..watch_count {
            let view =
                watch_run(&desk.prepared.device, &desk.run_id).map_err(fail)?;
            problems.push(read_watch_problem(&view));
        }

        for problem in &problems {
            prop_assert_eq!(problem, NO_ACTIVE_RUNNER);
        }
        prop_assert!(desk.fake_runner.received().is_empty());
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(1))]

    #[test]
    fn test_connect_to_runner_property_a_silent_runner_times_out_in_bounds(
        _seed in any::<u8>(),
    ) {
        let desk = open_watch_desk(RunnerAnswer::StaySilent).map_err(fail)?;

        let watching_started = Instant::now();
        let view = watch_claimed_run(&desk).map_err(fail)?;
        let waited = watching_started.elapsed();

        prop_assert_eq!(read_watch_problem(&view), LATE_ANSWER_PROBLEM);
        prop_assert!(waited >= LINK_ANSWER_LIMIT, "{:?}", waited);
        let longest_wait = LINK_ANSWER_LIMIT + LATE_ANSWER_SLACK;
        prop_assert!(waited < longest_wait, "{:?}", waited);
        prop_assert_eq!(desk.fake_runner.received().len(), 1);
    }
}
