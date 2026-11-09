use orchestration_api::work::RunEvent;
use orchestration_core::run::StepStatus;
use orchestration_node::live_link_messages::RunnerMessage;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::fake_runner::RunnerAnswer;
use crate::scripted_desk::{
    is_linked_view, open_scripted_desk, read_events, session_events,
};
use crate::scripted_runner::Opening;
use crate::support::test_device::fail;
use crate::watch_desk::{
    NO_ACTIVE_RUNNER, UNREACHABLE_LINK, open_unclaimed_desk,
    read_watch_problem, watch_run,
};

const WATCH_CASES: u32 = 1;
const MOST_EVENTS: usize = 6;
const MOST_BATCHES: usize = 4;
const LARGE_BATCH: usize = 60;

fn events_message(events: Vec<RunEvent>) -> RunnerMessage {
    RunnerMessage::Events { events }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(WATCH_CASES))]

    #[test]
    fn test_take_view_property_each_event_is_delivered_once(
        event_count in 1..MOST_EVENTS,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;
        let events = session_events("once", event_count);

        desk.runner.send_to_every_link(&events_message(events.clone()));
        let collected = desk.collect_events(event_count).map_err(fail)?;

        prop_assert_eq!(collected, events);
    }

    #[test]
    fn test_take_view_property_a_second_look_has_nothing_new(
        event_count in 1..MOST_EVENTS,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;
        let events = session_events("again", event_count);
        desk.runner.send_to_every_link(&events_message(events));
        desk.collect_events(event_count).map_err(fail)?;

        let second_look = desk.watch().map_err(fail)?;

        prop_assert_eq!(read_events(&second_look).map_err(fail)?, vec![]);
        prop_assert!(is_linked_view(&second_look), "{}", second_look);
    }

    #[test]
    fn test_take_view_property_shows_the_live_link(
        watch_count in 1_usize..4,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;

        let mut views = Vec::new();
        for _ in 0..watch_count {
            views.push(desk.watch().map_err(fail)?);
        }

        for view in &views {
            prop_assert_eq!(&view["link"], &json!("direct"));
            prop_assert_eq!(&view["problem"], &Value::Null);
            prop_assert_eq!(&view["link_lost_at"], &Value::Null);
        }
    }

    #[test]
    fn test_append_events_property_batches_keep_their_order(
        batch_sizes in prop::collection::vec(1..MOST_EVENTS, 1..MOST_BATCHES),
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;

        let mut expected = Vec::new();
        for (position, batch_size) in batch_sizes.iter().enumerate() {
            let prefix = format!("batch{position}");
            let batch = session_events(&prefix, *batch_size);
            expected.extend(batch.clone());
            desk.runner.send_to_every_link(&events_message(batch));
        }
        let collected = desk.collect_events(expected.len()).map_err(fail)?;

        prop_assert_eq!(collected, expected);
    }

    #[test]
    fn test_append_events_property_an_empty_batch_adds_nothing(
        event_count in 1..MOST_EVENTS,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;
        let events = session_events("after-empty", event_count);

        desk.runner.send_to_every_link(&events_message(Vec::new()));
        desk.runner.send_to_every_link(&events_message(events.clone()));
        let collected = desk.collect_events(event_count).map_err(fail)?;

        prop_assert_eq!(collected, events);
    }

    #[test]
    fn test_append_events_property_a_large_batch_arrives_whole(
        extra_count in 0..MOST_EVENTS,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;
        let events = session_events("large", LARGE_BATCH + extra_count);

        desk.runner.send_to_every_link(&events_message(events.clone()));
        let collected = desk.collect_events(events.len()).map_err(fail)?;

        prop_assert_eq!(collected, events);
    }

    #[test]
    fn test_unreachable_property_an_unclaimed_run_shows_nothing(
        watch_count in 1_usize..3,
    ) {
        let accepting = RunnerAnswer::Reply(RunnerMessage::Accepted);
        let desk = open_unclaimed_desk(accepting).map_err(fail)?;

        let mut views = Vec::new();
        for _ in 0..watch_count {
            views.push(
                watch_run(&desk.prepared.device, &desk.run_id)
                    .map_err(fail)?,
            );
        }

        for view in &views {
            prop_assert_eq!(&view["link"], &json!(UNREACHABLE_LINK));
            prop_assert_eq!(&view["events"], &json!([]));
            prop_assert_eq!(&view["link_lost_at"], &Value::Null);
            prop_assert_eq!(read_watch_problem(view), NO_ACTIVE_RUNNER);
        }
    }

    #[test]
    fn test_unreachable_property_show_run_never_invents_a_lost_time(
        watch_count in 1_usize..3,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.change_step(StepStatus::Done).map_err(fail)?;

        for _ in 0..watch_count {
            desk.watch().map_err(fail)?;
        }
        let shown = desk.show_run().map_err(fail)?;

        prop_assert_eq!(&shown["link"], &json!(UNREACHABLE_LINK));
        prop_assert_eq!(&shown["link_lost_at"], &Value::Null);
        prop_assert_eq!(desk.runner.count_watches(), 0);
    }

    #[test]
    fn test_unreachable_property_a_failed_first_watch_has_no_events(
        finished_status in prop::sample::select(vec![
            StepStatus::Done,
            StepStatus::Failed,
            StepStatus::Skipped,
        ]),
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.change_step(finished_status).map_err(fail)?;

        let view = desk.watch().map_err(fail)?;

        prop_assert_eq!(&view["link"], &json!(UNREACHABLE_LINK));
        prop_assert_eq!(&view["events"], &json!([]));
        prop_assert_eq!(read_watch_problem(&view), NO_ACTIVE_RUNNER);
    }
}
