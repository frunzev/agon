use std::time::Instant;

use orchestration_core::identifiers::generate_uuid;
use orchestration_core::run::StepStatus;
use orchestration_node::live_link_messages::RunnerMessage;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::fake_runner::RunnerAnswer;
use crate::scripted_desk::{
    LINK_LIMIT, QUIET_PAUSE, is_linked_view, open_scripted_desk, read_events,
    session_events,
};
use crate::scripted_runner::Opening;
use crate::support::test_device::fail;
use crate::watch_desk::{
    NO_ACTIVE_RUNNER, UNREACHABLE_LINK, open_watch_desk, read_watch_problem,
    watch_claimed_run, watch_run,
};

const WATCH_CASES: u32 = 1;
const MOST_EVENTS: usize = 6;
const REFUSAL_START: &str = "the runner refused the live link: ";
const LOST_AT_FIELD: &str = "link_lost_at";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(WATCH_CASES))]

    #[test]
    fn test_start_property_events_right_after_accepting_arrive(
        event_count in 1..MOST_EVENTS,
    ) {
        let events = session_events("early", event_count);
        let opening = Opening::AcceptThenSend(vec![RunnerMessage::Events {
            events: events.clone(),
        }]);
        let desk = open_scripted_desk(opening).map_err(fail)?;

        let collected = desk.collect_events(event_count).map_err(fail)?;

        prop_assert_eq!(collected, events);
    }

    #[test]
    fn test_start_property_a_link_closed_at_once_is_noticed(
        _seed in any::<u8>(),
    ) {
        let desk = open_scripted_desk(Opening::AcceptThenClose)
            .map_err(fail)?;

        let deadline = Instant::now() + LINK_LIMIT;
        while desk.runner.count_watches() < 2 && Instant::now() < deadline {
            desk.watch().map_err(fail)?;
            std::thread::sleep(QUIET_PAUSE);
        }

        prop_assert!(desk.runner.count_watches() >= 2);
    }

    #[test]
    fn test_start_property_undelivered_events_survive_a_new_link(
        event_count in 1..MOST_EVENTS,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;
        let events = session_events("kept", event_count);
        let message = RunnerMessage::Events {
            events: events.clone(),
        };
        desk.runner.send_to_every_link(&message);
        std::thread::sleep(QUIET_PAUSE);
        desk.runner.close_every_link();
        desk.wait_until_lost().map_err(fail)?;

        let collected = desk.collect_events(event_count).map_err(fail)?;

        prop_assert_eq!(collected, events);
        prop_assert_eq!(desk.runner.count_watches(), 2);
    }

    #[test]
    fn test_stop_property_late_events_are_ignored(
        event_count in 1..MOST_EVENTS,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;
        desk.stop_watching().map_err(fail)?;
        let late = session_events("late", event_count);
        desk.runner
            .send_to_every_link(&RunnerMessage::Events { events: late });
        std::thread::sleep(QUIET_PAUSE);

        let collected = desk.collect_events(1).map_err(fail)?;

        prop_assert_eq!(collected, vec![]);
    }

    #[test]
    fn test_stop_property_stopping_twice_is_harmless(
        stop_count in 2_usize..4,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;

        let mut replies = Vec::new();
        for _ in 0..stop_count {
            replies.push(desk.stop_watching());
        }
        let view = desk.watch().map_err(fail)?;

        for reply in replies {
            prop_assert_eq!(reply, Ok(Value::Null));
        }
        prop_assert!(is_linked_view(&view), "{}", view);
    }

    #[test]
    fn test_stop_property_an_unwatched_run_stops_quietly(
        _seed in any::<u8>(),
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        let unknown_run = generate_uuid().to_string();

        let stopped = desk.stop_watching();
        let stopped_unknown = desk.claimed.prepared.device.run(&json!({
            "command": "stop_watching_run",
            "run_id": unknown_run,
        }));

        prop_assert_eq!(stopped, Ok(Value::Null));
        prop_assert_eq!(stopped_unknown, Ok(Value::Null));
        prop_assert_eq!(desk.runner.count_watches(), 0);
    }

    #[test]
    fn test_record_unreachable_property_a_refusal_names_the_reason(
        reason in "[a-zA-Z0-9 .,]{1,40}",
    ) {
        let refusal = RunnerMessage::Refused { reason: reason.clone() };
        let desk =
            open_watch_desk(RunnerAnswer::Reply(refusal)).map_err(fail)?;

        let view = watch_claimed_run(&desk).map_err(fail)?;
        let again = watch_claimed_run(&desk).map_err(fail)?;

        let expected = format!("{REFUSAL_START}{reason}");
        prop_assert_eq!(read_watch_problem(&view), expected.clone());
        prop_assert_eq!(read_watch_problem(&again), expected);
        prop_assert_eq!(&view["link"], &json!(UNREACHABLE_LINK));
        prop_assert_eq!(&view[LOST_AT_FIELD], &Value::Null);
    }

    #[test]
    fn test_record_unreachable_property_keeps_the_first_lost_time(
        _seed in any::<u8>(),
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;
        desk.runner.close_every_link();
        let lost = desk.wait_until_lost().map_err(fail)?;
        desk.change_step(StepStatus::Done).map_err(fail)?;

        let view = desk.watch().map_err(fail)?;
        let shown = desk.show_run().map_err(fail)?;

        prop_assert_eq!(read_watch_problem(&view), NO_ACTIVE_RUNNER);
        prop_assert_eq!(&shown[LOST_AT_FIELD], &lost[LOST_AT_FIELD]);
        prop_assert_eq!(&view[LOST_AT_FIELD], &lost[LOST_AT_FIELD]);
    }

    #[test]
    fn test_record_unreachable_property_keeps_undelivered_events(
        event_count in 1..MOST_EVENTS,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;
        let events = session_events("unread", event_count);
        let message = RunnerMessage::Events {
            events: events.clone(),
        };
        desk.runner.send_to_every_link(&message);
        std::thread::sleep(QUIET_PAUSE);
        desk.runner.close_every_link();
        desk.wait_until_lost().map_err(fail)?;
        desk.change_step(StepStatus::Done).map_err(fail)?;

        let view = watch_run(&desk.claimed.prepared.device, &desk.run_id())
            .map_err(fail)?;

        prop_assert_eq!(read_watch_problem(&view), NO_ACTIVE_RUNNER);
        prop_assert_eq!(read_events(&view).map_err(fail)?, events);
    }
}
