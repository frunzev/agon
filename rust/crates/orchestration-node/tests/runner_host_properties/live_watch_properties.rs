use orchestration_node::live_link_messages::{
    ClientMessage, FileRequest, RunnerMessage, decode_link_message,
    encode_link_message,
};
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::file_host_steps::own_repository;
use crate::live_link_steps::{
    LinkSide, QUIET_PERIOD, close_link, collect_for, count_frames_until_end,
    has_chat, link_side, read_chat_texts, send_client_message, send_frame,
    wait_for_chat, watch,
};
use crate::run_view_steps::wait_for_chat_text;
use crate::support::test_device::fail;

const WATCH_CASES: u32 = 2;
const MOST_WATCHERS: usize = 3;
const MOST_CHATS: usize = 4;
const MOST_GARBAGE_BYTES: usize = 48;

fn unique_text(generated: &str) -> String {
    format!("{} {generated}", Uuid::new_v4())
}

fn chat(text: &str) -> ClientMessage {
    ClientMessage::Chat {
        text: text.to_owned(),
    }
}

async fn hear_on_every_watcher(
    side: &LinkSide,
    watcher_count: usize,
    text: &str,
) -> Result<usize, String> {
    let mut links = Vec::new();
    for _ in 0..watcher_count {
        links.push(watch(side, side.shared_run).await?);
    }
    send_client_message(&mut links[0], &chat(text)).await?;
    let mut hearing_count = 0;
    for link in &mut links {
        wait_for_chat(link, text).await?;
        hearing_count += 1;
    }
    for link in links {
        close_link(link).await?;
    }
    Ok(hearing_count)
}

async fn chat_beside_a_quiet_run(
    side: &LinkSide,
    text: &str,
) -> Result<Vec<RunnerMessage>, String> {
    let mut quiet_link = watch(side, side.lone_run).await?;
    let mut chatting_link = watch(side, side.shared_run).await?;
    send_client_message(&mut chatting_link, &chat(text)).await?;
    wait_for_chat(&mut chatting_link, text).await?;
    let quiet_messages = collect_for(&mut quiet_link, QUIET_PERIOD).await?;
    close_link(chatting_link).await?;
    close_link(quiet_link).await?;
    Ok(quiet_messages)
}

async fn chat_in_order(
    side: &LinkSide,
    texts: &[String],
) -> Result<Vec<String>, String> {
    let mut listening_link = watch(side, side.shared_run).await?;
    let mut chatting_link = watch(side, side.shared_run).await?;
    for text in texts {
        send_client_message(&mut chatting_link, &chat(text)).await?;
    }
    let last_text = texts.last().ok_or("no chat was sent")?;
    let heard = wait_for_chat(&mut listening_link, last_text).await?;
    close_link(chatting_link).await?;
    close_link(listening_link).await?;
    let mut heard_texts = Vec::new();
    for message in &heard {
        for heard_text in read_chat_texts(message) {
            if texts.contains(&heard_text) {
                heard_texts.push(heard_text);
            }
        }
    }
    Ok(heard_texts)
}

async fn end_after_frame(
    side: &LinkSide,
    frame: &[u8],
) -> Result<usize, String> {
    let mut link = watch(side, side.shared_run).await?;
    send_frame(&mut link, frame).await?;
    count_frames_until_end(&mut link).await
}

fn build_second_requests(
    side: &LinkSide,
) -> Result<Vec<ClientMessage>, String> {
    let repository = own_repository(side.host)?;
    let browse = ClientMessage::Browse {
        request: FileRequest::ListBranches { repository },
    };
    let watch_again = ClientMessage::Watch {
        run_id: side.shared_run,
    };
    Ok(vec![browse, watch_again])
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(WATCH_CASES))]

    #[test]
    fn test_forward_live_updates_property_every_watcher_hears_a_chat(
        watcher_count in 2..=MOST_WATCHERS,
        generated in "[a-z ]{0,20}",
    ) {
        let side = link_side().map_err(fail)?;
        let text = unique_text(&generated);

        let hearing_count = side
            .runtime
            .block_on(hear_on_every_watcher(side, watcher_count, &text))
            .map_err(fail)?;

        prop_assert_eq!(hearing_count, watcher_count);
    }

    #[test]
    fn test_forward_live_updates_property_other_runs_stay_quiet(
        generated in "[a-z ]{0,20}",
    ) {
        let side = link_side().map_err(fail)?;
        let _turn = side.take_lone_run_turn();
        let text = unique_text(&generated);

        let quiet_messages = side
            .runtime
            .block_on(chat_beside_a_quiet_run(side, &text))
            .map_err(fail)?;

        for message in &quiet_messages {
            prop_assert!(!has_chat(message, &text), "{:?}", message);
        }
    }

    #[test]
    fn test_forward_live_updates_property_chats_arrive_in_order(
        generated in vec("[a-z]{0,8}", 2..=MOST_CHATS),
    ) {
        let side = link_side().map_err(fail)?;
        let mut texts = Vec::new();
        for piece in &generated {
            texts.push(unique_text(piece));
        }

        let heard_texts = side
            .runtime
            .block_on(chat_in_order(side, &texts))
            .map_err(fail)?;

        prop_assert_eq!(heard_texts, texts);
    }

    #[test]
    fn test_relay_watcher_chat_property_a_chat_reaches_the_history(
        generated in "\\PC{0,30}",
    ) {
        let side = link_side().map_err(fail)?;
        let text = unique_text(&generated);

        side.runtime
            .block_on(async {
                let mut link = watch(side, side.shared_run).await?;
                send_client_message(&mut link, &chat(&text)).await?;
                wait_for_chat(&mut link, &text).await?;
                close_link(link).await
            })
            .map_err(fail)?;
        let stored = wait_for_chat_text(side.host, side.shared_run, &text);

        prop_assert_eq!(stored, Ok(()));
    }

    #[test]
    fn test_relay_watcher_chat_property_a_second_request_ends_the_watch(
        is_browse in any::<bool>(),
    ) {
        let side = link_side().map_err(fail)?;
        let requests = build_second_requests(side).map_err(fail)?;
        let request = if is_browse { &requests[0] } else { &requests[1] };
        let frame = encode_link_message(request).map_err(fail)?;

        let ended = side.runtime.block_on(end_after_frame(side, &frame));

        prop_assert!(ended.is_ok(), "{:?}", ended);
    }

    #[test]
    fn test_relay_watcher_chat_property_garbage_ends_the_watch(
        bytes in vec(any::<u8>(), 0..MOST_GARBAGE_BYTES).prop_filter(
            "undecodable",
            |bytes| decode_link_message::<ClientMessage>(bytes).is_err(),
        ),
    ) {
        let side = link_side().map_err(fail)?;

        let ended = side.runtime.block_on(end_after_frame(side, &bytes));

        prop_assert!(ended.is_ok(), "{:?}", ended);
    }
}
