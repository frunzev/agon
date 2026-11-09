use std::thread;

use orchestration_node::live_link_messages::RunnerMessage;
use proptest::prelude::*;

use crate::scripted_desk::{
    QUIET_PAUSE, ScriptedDesk, is_linked_view, open_scripted_desk,
    session_events,
};
use crate::scripted_runner::Opening;
use crate::support::test_device::fail;

const WATCH_CASES: u32 = 1;
const MOST_EVENTS: usize = 6;
const PARALLEL_WATCHERS: usize = 3;

fn watch_in_parallel(desk: &ScriptedDesk) -> Result<(), TestCaseError> {
    let replies = thread::scope(|scope| {
        let mut watching = Vec::new();
        for _ in 0..PARALLEL_WATCHERS {
            watching.push(scope.spawn(|| desk.watch()));
        }
        let mut replies = Vec::new();
        for watcher in watching {
            let reply = watcher.join();
            replies.push(reply.unwrap_or_else(|_| Err("panicked".into())));
        }
        replies
    });
    for reply in replies {
        reply.map_err(fail)?;
    }
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(WATCH_CASES))]

    #[test]
    fn test_is_read_by_current_task_property_one_reader_per_run(
        event_count in 1..MOST_EVENTS,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        watch_in_parallel(&desk)?;
        let first = session_events("first", event_count);
        let second = session_events("second", event_count);

        let first_message = RunnerMessage::Events { events: first.clone() };
        desk.runner.send_to_every_link(&first_message);
        let second_message = RunnerMessage::Events {
            events: second.clone(),
        };
        desk.runner.send_to_every_link(&second_message);
        let collected =
            desk.collect_events(first.len() + second.len()).map_err(fail)?;

        prop_assert_eq!(collected, [first, second].concat());
    }

    #[test]
    fn test_is_read_by_current_task_property_dropped_links_keep_the_watch(
        _seed in any::<u8>(),
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        watch_in_parallel(&desk)?;

        thread::sleep(QUIET_PAUSE);
        let shown = desk.show_run().map_err(fail)?;
        let view = desk.watch().map_err(fail)?;

        prop_assert_eq!(&shown["link"], &serde_json::json!("direct"));
        prop_assert!(is_linked_view(&view), "{}", view);
    }

    #[test]
    fn test_is_read_by_current_task_property_a_new_link_reads_alone(
        event_count in 1..MOST_EVENTS,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        watch_in_parallel(&desk)?;
        desk.runner.close_every_link();
        desk.wait_until_lost().map_err(fail)?;
        desk.watch().map_err(fail)?;
        let events = session_events("relinked", event_count);

        let message = RunnerMessage::Events {
            events: events.clone(),
        };
        desk.runner.send_to_every_link(&message);
        let collected = desk.collect_events(events.len()).map_err(fail)?;

        prop_assert_eq!(collected, events);
    }
}
