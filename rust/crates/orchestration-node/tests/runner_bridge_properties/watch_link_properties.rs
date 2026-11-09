use chrono::{DateTime, Utc};
use orchestration_node::live_link_messages::ClientMessage;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::scripted_desk::{ScriptedDesk, is_linked_view, open_scripted_desk};
use crate::scripted_runner::Opening;
use crate::support::test_device::{describe, fail};

const WATCH_CASES: u32 = 1;
const LOST_AT_FIELD: &str = "link_lost_at";

fn read_lost_at(shown: &Value) -> Result<DateTime<Utc>, String> {
    serde_json::from_value(shown[LOST_AT_FIELD].clone()).map_err(describe)
}

fn lose_the_link(desk: &ScriptedDesk) -> Result<Value, String> {
    desk.runner.close_every_link();
    desk.wait_until_lost()
}

fn has_chat(messages: &[ClientMessage]) -> bool {
    messages
        .iter()
        .any(|message| matches!(message, ClientMessage::Chat { .. }))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(WATCH_CASES))]

    #[test]
    fn test_is_linked_property_a_linked_run_is_dialed_once(
        watch_count in 2_usize..5,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;

        for _ in 0..watch_count {
            desk.watch().map_err(fail)?;
        }

        prop_assert_eq!(desk.runner.count_watches(), 1);
    }

    #[test]
    fn test_is_linked_property_a_lost_link_is_dialed_again(
        loss_count in 1_usize..3,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;

        let mut views = Vec::new();
        for _ in 0..loss_count {
            lose_the_link(&desk).map_err(fail)?;
            views.push(desk.watch().map_err(fail)?);
        }

        for view in &views {
            prop_assert!(is_linked_view(view), "{}", view);
        }
        prop_assert_eq!(desk.runner.count_watches(), loss_count + 1);
    }

    #[test]
    fn test_is_linked_property_a_stopped_watch_is_dialed_again(
        stop_count in 1_usize..3,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;

        let mut views = Vec::new();
        for _ in 0..stop_count {
            desk.stop_watching().map_err(fail)?;
            views.push(desk.watch().map_err(fail)?);
        }

        for view in &views {
            prop_assert!(is_linked_view(view), "{}", view);
        }
        prop_assert_eq!(desk.runner.count_watches(), stop_count + 1);
    }

    #[test]
    fn test_link_report_property_a_live_link_shows_direct(
        look_count in 1_usize..3,
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;

        let mut shown_runs = Vec::new();
        for _ in 0..look_count {
            shown_runs.push(desk.show_run().map_err(fail)?);
        }

        for shown in &shown_runs {
            prop_assert_eq!(&shown["link"], &json!("direct"));
            prop_assert_eq!(&shown[LOST_AT_FIELD], &Value::Null);
        }
    }

    #[test]
    fn test_link_report_property_a_lost_link_shows_when(
        _seed in any::<u8>(),
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;
        let before_loss = Utc::now();

        let shown = lose_the_link(&desk).map_err(fail)?;
        let after_loss = Utc::now();

        let lost_at = read_lost_at(&shown).map_err(fail)?;
        prop_assert!(before_loss <= lost_at, "{} {}", before_loss, lost_at);
        prop_assert!(lost_at <= after_loss, "{} {}", lost_at, after_loss);
    }

    #[test]
    fn test_link_report_property_a_stopped_watch_falls_back_to_the_run(
        _seed in any::<u8>(),
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;

        desk.stop_watching().map_err(fail)?;
        let shown = desk.show_run().map_err(fail)?;

        prop_assert_eq!(&shown["link"], &shown["run"]["link"]);
        prop_assert_eq!(&shown[LOST_AT_FIELD], &shown["run"][LOST_AT_FIELD]);
    }

    #[test]
    fn test_lose_link_property_a_second_loss_moves_the_lost_time(
        _seed in any::<u8>(),
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;
        let first_loss = lose_the_link(&desk).map_err(fail)?;
        desk.watch().map_err(fail)?;

        let second_loss = lose_the_link(&desk).map_err(fail)?;

        let first_lost_at = read_lost_at(&first_loss).map_err(fail)?;
        let second_lost_at = read_lost_at(&second_loss).map_err(fail)?;
        prop_assert!(first_lost_at < second_lost_at);
    }

    #[test]
    fn test_lose_link_property_a_lost_link_sends_chat_by_the_server(
        text in "[A-Za-z][A-Za-z0-9 ]{0,30}",
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;
        lose_the_link(&desk).map_err(fail)?;

        let sent = desk.send_chat(&text).map_err(fail)?;

        prop_assert_eq!(&sent["text"], &json!(text));
        prop_assert!(!has_chat(&desk.runner.received()));
    }

    #[test]
    fn test_lose_link_property_a_new_link_starts_clean(
        _seed in any::<u8>(),
    ) {
        let desk = open_scripted_desk(Opening::Accept).map_err(fail)?;
        desk.watch().map_err(fail)?;
        lose_the_link(&desk).map_err(fail)?;

        let view = desk.watch().map_err(fail)?;

        prop_assert!(is_linked_view(&view), "{}", view);
        prop_assert_eq!(&view[LOST_AT_FIELD], &Value::Null);
    }
}
