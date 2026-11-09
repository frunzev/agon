use std::thread;

use orchestration_core::repository_files::RepositoryBranches;
use orchestration_node::live_link_messages::{
    ClientMessage, FileAnswer, RunnerMessage,
};
use proptest::prelude::*;
use serde_json::Value;

use crate::scripted_desk::{
    LINK_LIMIT, QUIET_PAUSE, ScriptedDesk, is_linked_view, open_scripted_desk,
    session_events,
};
use crate::scripted_runner::Opening;
use crate::support::test_device::fail;
use crate::support::waiting::wait_for;

const WATCH_CASES: u32 = 1;
const MOST_EVENTS: usize = 6;
const MOST_MESSAGES: usize = 4;
const PARALLEL_WATCHERS: usize = 3;
const CHAT_PATTERN: &str =
    "[A-Za-z\u{e9}\u{4e16}][A-Za-z0-9 \u{e9}\u{4e16}]{0,24}";
const UNREADABLE_FRAME: &[u8] = b"{ not a runner message";

fn chat_texts(messages: &[ClientMessage]) -> Vec<String> {
    let mut texts = Vec::new();
    for message in messages {
        if let ClientMessage::Chat { text } = message {
            texts.push(text.clone());
        }
    }
    texts
}

fn wait_for_chats(
    desk: &ScriptedDesk,
    chat_count: usize,
) -> Result<Vec<String>, String> {
    wait_for(LINK_LIMIT, "the chat to reach the runner", || {
        let texts = chat_texts(&desk.runner.received());
        Ok((texts.len() >= chat_count).then_some(texts))
    })
}

fn watch_in_parallel(desk: &ScriptedDesk) -> Vec<Result<Value, String>> {
    thread::scope(|scope| {
        let mut watching = Vec::new();
        for _ in 0..PARALLEL_WATCHERS {
            watching.push(scope.spawn(|| desk.watch()));
        }
        let mut replies = Vec::new();
        for watcher in watching {
            let reply = watcher.join();
            replies.push(reply.unwrap_or_else(|_| Err("panicked".to_owned())));
        }
        replies
    })
}

fn files_answer() -> RunnerMessage {
    RunnerMessage::Answered {
        answer: FileAnswer::Branches {
            branches: RepositoryBranches::default(),
        },
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(WATCH_CASES))]

    #[test]
    fn test_send_chat_property_a_linked_run_sends_over_the_link(
        text in CHAT_PATTERN,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;

        desk.send_chat(&text).map_err(fail)?;
        let texts = wait_for_chats(&desk, 1).map_err(fail)?;

        prop_assert_eq!(texts, vec![text]);
    }

    #[test]
    fn test_send_chat_property_an_unwatched_run_goes_by_the_server(
        text in CHAT_PATTERN,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;

        let sent = desk.send_chat(&text);
        std::thread::sleep(QUIET_PAUSE);

        prop_assert!(sent.is_ok(), "{:?}", sent);
        prop_assert_eq!(desk.runner.received(), vec![]);
    }

    #[test]
    fn test_send_chat_property_messages_arrive_once_in_order(
        texts in prop::collection::vec(CHAT_PATTERN, 1..MOST_MESSAGES),
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;

        for text in &texts {
            desk.send_chat(text).map_err(fail)?;
        }
        let arrived = wait_for_chats(&desk, texts.len()).map_err(fail)?;
        std::thread::sleep(QUIET_PAUSE);

        prop_assert_eq!(arrived, texts.clone());
        prop_assert_eq!(chat_texts(&desk.runner.received()), texts);
    }

    #[test]
    fn test_read_host_messages_property_a_refusal_ends_the_link(
        reason in "[a-zA-Z0-9 .,]{1,40}",
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;

        desk.runner.send_to_every_link(&RunnerMessage::Refused { reason });
        desk.wait_until_lost().map_err(fail)?;
        let view = desk.watch().map_err(fail)?;

        prop_assert!(is_linked_view(&view), "{}", view);
        prop_assert_eq!(desk.runner.count_watches(), 2);
    }

    #[test]
    fn test_read_host_messages_property_files_during_a_watch_end_it(
        _seed in any::<u8>(),
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;

        desk.runner.send_to_every_link(&files_answer());
        let lost = desk.wait_until_lost();

        prop_assert!(lost.is_ok(), "{:?}", lost);
    }

    #[test]
    fn test_read_host_messages_property_an_unreadable_frame_ends_it(
        extra_bytes in prop::collection::vec(any::<u8>(), 0..8),
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;
        let frame = [UNREADABLE_FRAME, &extra_bytes].concat();

        desk.runner.send_frame_to_every_link(&frame);
        let lost = desk.wait_until_lost();

        prop_assert!(lost.is_ok(), "{:?}", lost);
    }

    #[test]
    fn test_lock_table_property_parallel_watches_deliver_events_once(
        event_count in 1..MOST_EVENTS,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        for reply in watch_in_parallel(&desk) {
            reply.map_err(fail)?;
        }
        let events = session_events("parallel", event_count);

        let message = RunnerMessage::Events {
            events: events.clone(),
        };
        desk.runner.send_to_every_link(&message);
        let collected = desk.collect_events(event_count).map_err(fail)?;

        prop_assert_eq!(collected, events);
    }

    #[test]
    fn test_lock_table_property_parallel_watches_end_linked(
        text in CHAT_PATTERN,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        let replies = watch_in_parallel(&desk);

        let view = desk.watch().map_err(fail)?;
        desk.send_chat(&text).map_err(fail)?;
        let texts = wait_for_chats(&desk, 1).map_err(fail)?;

        for reply in replies {
            prop_assert!(reply.is_ok(), "{:?}", reply);
        }
        prop_assert!(is_linked_view(&view), "{}", view);
        prop_assert_eq!(texts, vec![text]);
    }

    #[test]
    fn test_lock_table_property_parallel_stops_and_watches_stay_defined(
        round_count in 1_usize..3,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;

        let replies = thread::scope(|scope| {
            let mut running = Vec::new();
            for _ in 0..round_count {
                running.push(scope.spawn(|| desk.watch()));
                running.push(scope.spawn(|| desk.stop_watching()));
            }
            let mut replies = Vec::new();
            for handle in running {
                let reply = handle.join();
                replies.push(reply.unwrap_or_else(|_| Err("panicked".into())));
            }
            replies
        });
        let view = desk.watch().map_err(fail)?;

        for reply in replies {
            prop_assert!(reply.is_ok(), "{:?}", reply);
        }
        prop_assert!(is_linked_view(&view), "{}", view);
    }
}
