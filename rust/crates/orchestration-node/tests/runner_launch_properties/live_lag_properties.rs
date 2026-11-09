use std::sync::LazyLock;

use orchestration_core::identifiers::RunId;
use orchestration_node::live_link_messages::{ClientMessage, RunnerMessage};
use proptest::prelude::*;
use proptest::sample::Index;
use uuid::Uuid;

use crate::live_link_steps::{
    LinkSide, close_link, link_side, read_chat_texts, send_client_message,
    wait_for_chat, watch,
};
use crate::run_view_steps::finish_new_run;
use crate::support::test_device::fail;

const LAG_CASES: u32 = 4;
const FILLER_CHAT_COUNT: usize = 2;
const FILLER_CHAT_BYTES: usize = 1024 * 1024;
const SMALL_CHAT_COUNT: usize = 280;

#[derive(Debug)]
struct Flood {
    texts: Vec<String>,
    paused_heard: Vec<String>,
    reader_heard: Vec<String>,
}

static FLOOD: LazyLock<Result<Flood, String>> = LazyLock::new(run_flood);

fn build_flood_texts() -> Vec<String> {
    let flood_mark = Uuid::new_v4();
    let filler = "f".repeat(FILLER_CHAT_BYTES);
    let mut texts = Vec::new();
    for index in 0..FILLER_CHAT_COUNT {
        texts.push(format!("{flood_mark} filler {index} {filler}"));
    }
    for index in 0..SMALL_CHAT_COUNT {
        texts.push(format!("{flood_mark} small {index}"));
    }
    texts
}

fn chat(text: &str) -> ClientMessage {
    ClientMessage::Chat {
        text: text.to_owned(),
    }
}

fn keep_flood_texts(heard: &[RunnerMessage], texts: &[String]) -> Vec<String> {
    let mut flood_texts = Vec::new();
    for message in heard {
        for text in read_chat_texts(message) {
            if texts.contains(&text) {
                flood_texts.push(text);
            }
        }
    }
    flood_texts
}

async fn flood_a_paused_watcher(
    side: &LinkSide,
    run_id: RunId,
    texts: Vec<String>,
) -> Result<Flood, String> {
    let mut paused = watch(side, run_id).await?;
    let mut reader = watch(side, run_id).await?;
    for text in &texts {
        send_client_message(&mut reader, &chat(text)).await?;
    }
    let last_text = texts.last().cloned().unwrap_or_default();
    let reader_messages = wait_for_chat(&mut reader, &last_text).await?;
    let paused_messages = wait_for_chat(&mut paused, &last_text).await?;
    close_link(reader).await?;
    close_link(paused).await?;
    Ok(Flood {
        paused_heard: keep_flood_texts(&paused_messages, &texts),
        reader_heard: keep_flood_texts(&reader_messages, &texts),
        texts,
    })
}

fn run_flood() -> Result<Flood, String> {
    let side = link_side()?;
    let run_id = finish_new_run(side.host)?;
    let texts = build_flood_texts();
    side.runtime
        .block_on(flood_a_paused_watcher(side, run_id, texts))
}

fn flood() -> Result<&'static Flood, TestCaseError> {
    FLOOD.as_ref().map_err(fail)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LAG_CASES))]

    #[test]
    fn test_forward_live_updates_property_a_paused_watcher_misses_nothing(
        position in any::<Index>(),
    ) {
        let flood = flood()?;
        let index = position.index(flood.texts.len());

        prop_assert_eq!(flood.paused_heard.len(), flood.texts.len());
        let heard = flood.paused_heard.get(index);
        prop_assert!(heard == flood.texts.get(index));
    }

    #[test]
    fn test_forward_live_updates_property_paused_and_reading_hear_alike(
        position in any::<Index>(),
    ) {
        let flood = flood()?;
        let index = position.index(flood.texts.len());

        prop_assert_eq!(flood.paused_heard.len(), flood.reader_heard.len());
        let heard = flood.paused_heard.get(index);
        prop_assert!(heard == flood.reader_heard.get(index));
    }

    #[test]
    fn test_forward_live_updates_property_a_paused_watcher_hears_each_once(
        position in any::<Index>(),
    ) {
        let flood = flood()?;
        let index = position.index(flood.texts.len());
        let expected = &flood.texts[index];

        let mut hearing_count = 0;
        for heard in &flood.paused_heard {
            if heard == expected {
                hearing_count += 1;
            }
        }
        prop_assert_eq!(hearing_count, 1);
    }
}
