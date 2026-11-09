use std::time::Duration;

use orchestration_core::identifiers::RunId;
use orchestration_node::live_link_messages::{
    ClientMessage, RunnerMessage, decode_link_message,
};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use orchestration_p2p::peer_link::PeerLink;
use proptest::prelude::*;
use tokio::time::{Instant, timeout};
use uuid::Uuid;

use crate::live_link_steps::{
    LinkSide, REPLY_LIMIT, ask, link_side, open_link, receive_message,
    send_client_message,
};
use crate::support::test_device::{describe, fail};

const FIRST_MESSAGE_CASES: u32 = 2;
const MOST_SILENT_LINKS: usize = 3;
const LONGEST_TIMELY_PAUSE_MILLISECONDS: u64 = 3000;
const CLOSED_EARLY_REASON: &str =
    "the peer closed the live link before asking for anything";
const SILENT_REASON: &str =
    "the peer asked for nothing on the live link in time";
const LINK_STAYED_OPEN: &str = "the runner kept a silent link open";
const RUNNER_HUNG_UP: &str = "the runner hung up without a reason";

fn unclaimed_watch(number: u128) -> ClientMessage {
    ClientMessage::Watch {
        run_id: RunId(Uuid::from_u128(number)),
    }
}

fn unclaimed_refusal(number: u128) -> RunnerMessage {
    RunnerMessage::Refused {
        reason: format!(
            "claimed run {} was not found",
            Uuid::from_u128(number)
        ),
    }
}

fn refusal(reason: &str) -> RunnerMessage {
    RunnerMessage::Refused {
        reason: reason.to_owned(),
    }
}

async fn hear_the_end_of_a_silent_link(
    mut link: PeerLink,
) -> Result<Vec<RunnerMessage>, String> {
    let deadline = Instant::now() + REPLY_LIMIT;
    let mut heard = Vec::new();
    loop {
        let remaining = deadline.saturating_duration_since(Instant::now());
        let receiving = link.receiver.receive_frame();
        let Ok(received) = timeout(remaining, receiving).await else {
            return Err(LINK_STAYED_OPEN.to_owned());
        };
        match received {
            Ok(Some(frame)) => {
                heard.push(decode_link_message(&frame).map_err(describe)?);
            }
            Ok(None) | Err(_) => return Ok(heard),
        }
    }
}

async fn open_silent_links(
    side: &LinkSide,
    silent_count: usize,
) -> Result<Vec<Vec<RunnerMessage>>, String> {
    let mut links = Vec::new();
    for _ in 0..silent_count {
        links.push(open_link(&side.client, side.host).await?);
    }
    let mut endings = Vec::new();
    for link in links {
        endings.push(tokio::spawn(hear_the_end_of_a_silent_link(link)));
    }
    let mut heard = Vec::new();
    for ending in endings {
        heard.push(ending.await.map_err(describe)??);
    }
    Ok(heard)
}

async fn close_before_asking(
    side: &LinkSide,
    endpoint: &PeerEndpoint,
) -> Result<RunnerMessage, String> {
    let link = open_link(endpoint, side.host).await?;
    let PeerLink {
        sender,
        mut receiver,
    } = link;
    drop(sender);
    let receiving = receiver.receive_frame();
    let received = timeout(REPLY_LIMIT, receiving).await.map_err(describe)?;
    let frame = received.map_err(describe)?;
    let frame = frame.ok_or_else(|| RUNNER_HUNG_UP.to_owned())?;
    decode_link_message(&frame).map_err(describe)
}

async fn ask_after_pause(
    side: &LinkSide,
    pause: Duration,
    number: u128,
) -> Result<RunnerMessage, String> {
    let mut link = open_link(&side.client, side.host).await?;
    tokio::time::sleep(pause).await;
    send_client_message(&mut link, &unclaimed_watch(number)).await?;
    receive_message(&mut link).await
}

fn is_silence_ending(heard: &[RunnerMessage]) -> bool {
    heard.is_empty() || heard == [refusal(SILENT_REASON)]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FIRST_MESSAGE_CASES))]

    #[test]
    fn test_read_first_message_property_a_silent_peer_is_let_go(
        silent_count in 1..=MOST_SILENT_LINKS,
    ) {
        let side = link_side().map_err(fail)?;

        let heard = side
            .runtime
            .block_on(open_silent_links(side, silent_count))
            .map_err(fail)?;

        prop_assert_eq!(heard.len(), silent_count);
        for ending in &heard {
            prop_assert!(is_silence_ending(ending), "{:?}", ending);
        }
    }

    #[test]
    fn test_read_first_message_property_a_timely_ask_is_still_served(
        pause_milliseconds in 0..=LONGEST_TIMELY_PAUSE_MILLISECONDS,
        number in any::<u128>(),
    ) {
        let side = link_side().map_err(fail)?;
        let pause = Duration::from_millis(pause_milliseconds);

        let reply = side
            .runtime
            .block_on(ask_after_pause(side, pause, number))
            .map_err(fail)?;

        prop_assert_eq!(reply, unclaimed_refusal(number));
    }

    #[test]
    fn test_read_first_message_property_silence_never_blocks_others(
        silent_count in 1..=MOST_SILENT_LINKS,
        number in any::<u128>(),
    ) {
        let side = link_side().map_err(fail)?;
        let watch_request = unclaimed_watch(number);

        let replies = side.runtime.block_on(async {
            let silence = open_silent_links(side, silent_count);
            let asking = ask(&side.client, side.host, &watch_request);
            tokio::join!(silence, asking)
        });

        let (silence_endings, reply) = replies;
        prop_assert!(silence_endings.is_ok(), "{:?}", silence_endings);
        prop_assert_eq!(reply.map_err(fail)?, unclaimed_refusal(number));
    }

    #[test]
    fn test_read_first_message_property_a_link_closed_early_hears_why(
        attempt_count in 1_usize..3,
    ) {
        let side = link_side().map_err(fail)?;

        for _ in 0..attempt_count {
            let reply = side
                .runtime
                .block_on(close_before_asking(side, &side.client))
                .map_err(fail)?;
            prop_assert_eq!(reply, refusal(CLOSED_EARLY_REASON));
        }
    }

    #[test]
    fn test_read_first_message_property_a_stranger_closing_hears_the_same(
        attempt_count in 1_usize..3,
    ) {
        let side = link_side().map_err(fail)?;

        for _ in 0..attempt_count {
            let reply = side
                .runtime
                .block_on(close_before_asking(side, &side.stranger))
                .map_err(fail)?;
            prop_assert_eq!(reply, refusal(CLOSED_EARLY_REASON));
        }
    }

    #[test]
    fn test_read_first_message_property_early_closes_never_stop_the_host(
        closed_count in 1_usize..4,
        number in any::<u128>(),
    ) {
        let side = link_side().map_err(fail)?;

        let reply = side.runtime.block_on(async {
            for _ in 0..closed_count {
                close_before_asking(side, &side.client).await?;
            }
            ask(&side.client, side.host, &unclaimed_watch(number)).await
        });

        prop_assert_eq!(reply.map_err(fail)?, unclaimed_refusal(number));
    }
}
