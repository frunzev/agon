use orchestration_node::live_link_messages::ClientMessage;
use orchestration_p2p::peer_link::PeerLink;
use proptest::prelude::*;
use uuid::Uuid;

use crate::live_link_steps::{
    LinkSide, close_link, link_side, send_client_message, wait_for_chat, watch,
};
use crate::support::test_device::fail;

const FEED_CASES: u32 = 2;
const MOST_WATCHERS: usize = 4;
const MOST_ROUNDS: usize = 3;

fn unique_text(generated: &str) -> String {
    format!("{} {generated}", Uuid::new_v4())
}

fn chat(text: &str) -> ClientMessage {
    ClientMessage::Chat {
        text: text.to_owned(),
    }
}

async fn open_watchers(
    side: &LinkSide,
    watcher_count: usize,
) -> Result<Vec<PeerLink>, String> {
    let mut links = Vec::new();
    for _ in 0..watcher_count {
        links.push(watch(side, side.shared_run).await?);
    }
    Ok(links)
}

async fn close_all(links: Vec<PeerLink>) -> Result<(), String> {
    for link in links {
        close_link(link).await?;
    }
    Ok(())
}

async fn every_watcher_hears(
    side: &LinkSide,
    watcher_count: usize,
    text: &str,
) -> Result<usize, String> {
    let mut links = open_watchers(side, watcher_count).await?;
    send_client_message(&mut links[0], &chat(text)).await?;
    let mut hearing_count = 0;
    for link in &mut links {
        wait_for_chat(link, text).await?;
        hearing_count += 1;
    }
    close_all(links).await?;
    Ok(hearing_count)
}

async fn hear_after_rounds_of_leavers(
    side: &LinkSide,
    rounds: usize,
    text: &str,
) -> Result<(), String> {
    let mut staying = watch(side, side.shared_run).await?;
    for round in 0..rounds {
        let leavers = open_watchers(side, round + 1).await?;
        close_all(leavers).await?;
    }
    send_client_message(&mut staying, &chat(text)).await?;
    wait_for_chat(&mut staying, text).await?;
    close_link(staying).await
}

async fn hear_after_dropped_watchers(
    side: &LinkSide,
    dropped_count: usize,
    text: &str,
) -> Result<(), String> {
    let dropped = open_watchers(side, dropped_count).await?;
    drop(dropped);
    let mut speaker = watch(side, side.shared_run).await?;
    send_client_message(&mut speaker, &chat(text)).await?;
    wait_for_chat(&mut speaker, text).await?;
    close_link(speaker).await
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FEED_CASES))]

    #[test]
    fn test_lock_live_watchers_property_every_watcher_hears_a_chat(
        watcher_count in 2..=MOST_WATCHERS,
        generated in "[a-z ]{0,20}",
    ) {
        let side = link_side().map_err(fail)?;
        let text = unique_text(&generated);

        let heard = side
            .runtime
            .block_on(every_watcher_hears(side, watcher_count, &text));

        prop_assert_eq!(heard, Ok(watcher_count));
    }

    #[test]
    fn test_lock_live_watchers_property_leavers_never_starve_a_stayer(
        rounds in 1..=MOST_ROUNDS,
        generated in "[a-z ]{0,20}",
    ) {
        let side = link_side().map_err(fail)?;
        let text = unique_text(&generated);

        let heard = side
            .runtime
            .block_on(hear_after_rounds_of_leavers(side, rounds, &text));

        prop_assert_eq!(heard, Ok(()));
    }

    #[test]
    fn test_lock_live_watchers_property_dropped_links_never_block_posts(
        dropped_count in 1..=MOST_WATCHERS,
        generated in "[a-z ]{0,20}",
    ) {
        let side = link_side().map_err(fail)?;
        let text = unique_text(&generated);

        let heard = side
            .runtime
            .block_on(hear_after_dropped_watchers(side, dropped_count, &text));

        prop_assert_eq!(heard, Ok(()));
    }
}
