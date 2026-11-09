use orchestration_core::identifiers::RunId;
use orchestration_node::live_link_messages::{
    ClientMessage, FileAnswer, FileRequest, RunnerMessage, decode_link_message,
};
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::file_host_fixture::MAIN_BRANCH;
use crate::file_host_steps::own_repository;
use crate::live_link_steps::{
    LinkSide, ask, close_link, count_frames_until_end, link_side, open_link,
    receive_message, send_client_message, send_frame, watch,
};
use crate::support::test_device::{describe, fail};

const PEER_CASES: u32 = 3;
const MOST_LINKS: usize = 5;
const MOST_SILENT_LINKS: usize = 3;
const MOST_GARBAGE_BYTES: usize = 64;
const MALFORMED_START: &str = "the live link message could not be read: ";
const CHAT_FIRST_REASON: &str = "the live link message could not be read: \
     the first message must ask to watch a run or to see files";

fn unclaimed_watch(number: u128) -> ClientMessage {
    ClientMessage::Watch {
        run_id: RunId(Uuid::from_u128(number)),
    }
}

fn unclaimed_refusal(number: u128) -> RunnerMessage {
    let run_text = Uuid::from_u128(number).to_string();
    RunnerMessage::Refused {
        reason: format!("claimed run {run_text} was not found"),
    }
}

fn is_undecodable(bytes: &[u8]) -> bool {
    decode_link_message::<ClientMessage>(bytes).is_err()
}

async fn ask_each_in_turn(
    side: &LinkSide,
    numbers: &[u128],
) -> Result<Vec<RunnerMessage>, String> {
    let mut replies = Vec::new();
    for number in numbers {
        let message = unclaimed_watch(*number);
        replies.push(ask(&side.client, side.host, &message).await?);
    }
    Ok(replies)
}

async fn ask_all_at_once(
    side: &'static LinkSide,
    numbers: &[u128],
) -> Result<Vec<RunnerMessage>, String> {
    let mut askings = Vec::new();
    for number in numbers {
        let message = unclaimed_watch(*number);
        let asking =
            async move { ask(&side.client, side.host, &message).await };
        askings.push(tokio::spawn(asking));
    }
    let mut replies = Vec::new();
    for asking in askings {
        replies.push(asking.await.map_err(describe)??);
    }
    Ok(replies)
}

async fn open_silent_links(
    side: &LinkSide,
    silent_count: usize,
) -> Result<(), String> {
    for _ in 0..silent_count {
        let link = open_link(&side.client, side.host).await?;
        close_link(link).await?;
    }
    Ok(())
}

async fn ask_twice_in_one_link(
    side: &LinkSide,
    first: &ClientMessage,
    second: &ClientMessage,
) -> Result<(RunnerMessage, usize), String> {
    let mut link = open_link(&side.client, side.host).await?;
    send_client_message(&mut link, first).await?;
    send_client_message(&mut link, second).await?;
    let reply = receive_message(&mut link).await?;
    let later_frames = count_frames_until_end(&mut link).await?;
    Ok((reply, later_frames))
}

async fn send_garbage(
    side: &LinkSide,
    bytes: &[u8],
) -> Result<RunnerMessage, String> {
    let mut link = open_link(&side.client, side.host).await?;
    send_frame(&mut link, bytes).await?;
    receive_message(&mut link).await
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PEER_CASES))]

    #[test]
    fn test_start_live_host_property_answers_links_one_after_another(
        numbers in vec(any::<u128>(), 2..=MOST_LINKS),
    ) {
        let side = link_side().map_err(fail)?;

        let replies = side
            .runtime
            .block_on(ask_each_in_turn(side, &numbers))
            .map_err(fail)?;

        prop_assert_eq!(replies.len(), numbers.len());
        for (reply, number) in replies.iter().zip(&numbers) {
            prop_assert_eq!(reply, &unclaimed_refusal(*number));
        }
    }

    #[test]
    fn test_start_live_host_property_answers_links_at_once(
        numbers in vec(any::<u128>(), 2..=MOST_LINKS),
    ) {
        let side = link_side().map_err(fail)?;

        let replies = side
            .runtime
            .block_on(ask_all_at_once(side, &numbers))
            .map_err(fail)?;

        prop_assert_eq!(replies.len(), numbers.len());
        for (reply, number) in replies.iter().zip(&numbers) {
            prop_assert_eq!(reply, &unclaimed_refusal(*number));
        }
    }

    #[test]
    fn test_start_live_host_property_silent_links_do_not_stop_it(
        silent_count in 1..=MOST_SILENT_LINKS,
        number in any::<u128>(),
    ) {
        let side = link_side().map_err(fail)?;

        side.runtime
            .block_on(open_silent_links(side, silent_count))
            .map_err(fail)?;
        let reply = side
            .runtime
            .block_on(ask(&side.client, side.host, &unclaimed_watch(number)))
            .map_err(fail)?;

        prop_assert_eq!(reply, unclaimed_refusal(number));
    }

    #[test]
    fn test_serve_peer_property_a_chat_first_is_refused(
        text in "\\PC{0,40}",
    ) {
        let side = link_side().map_err(fail)?;
        let chat = ClientMessage::Chat { text };

        let reply = side
            .runtime
            .block_on(ask(&side.client, side.host, &chat))
            .map_err(fail)?;

        let expected = RunnerMessage::Refused {
            reason: CHAT_FIRST_REASON.to_owned(),
        };
        prop_assert_eq!(reply, expected);
    }

    #[test]
    fn test_serve_peer_property_a_client_browse_is_answered(
        ask_count in 1_usize..3,
    ) {
        let side = link_side().map_err(fail)?;
        let repository = own_repository(side.host).map_err(fail)?;
        let browse = ClientMessage::Browse {
            request: FileRequest::ListBranches { repository },
        };

        for _ in 0..ask_count {
            let reply = side
                .runtime
                .block_on(ask(&side.client, side.host, &browse))
                .map_err(fail)?;

            let RunnerMessage::Answered {
                answer: FileAnswer::Branches { branches },
            } = reply
            else {
                return Err(fail(format!("not branches: {reply:?}")));
            };
            let main_branch = MAIN_BRANCH.to_owned();
            prop_assert!(
                branches.branches.contains(&main_branch),
                "{:?}",
                branches
            );
        }
    }

    #[test]
    fn test_serve_peer_property_a_client_watch_is_accepted(
        watch_count in 1_usize..3,
    ) {
        let side = link_side().map_err(fail)?;

        let watched = side.runtime.block_on(async {
            let mut links = Vec::new();
            for _ in 0..watch_count {
                links.push(watch(side, side.shared_run).await?);
            }
            for link in links {
                close_link(link).await?;
            }
            Ok::<(), String>(())
        });

        prop_assert_eq!(watched, Ok(()));
    }

    #[test]
    fn test_read_first_message_property_undecodable_frames_are_refused(
        bytes in vec(any::<u8>(), 0..MOST_GARBAGE_BYTES)
            .prop_filter("undecodable", |bytes| is_undecodable(bytes)),
    ) {
        let side = link_side().map_err(fail)?;

        let reply = side
            .runtime
            .block_on(send_garbage(side, &bytes))
            .map_err(fail)?;

        let RunnerMessage::Refused { reason } = reply else {
            return Err(fail(format!("not refused: {reply:?}")));
        };
        prop_assert!(reason.starts_with(MALFORMED_START), "{}", reason);
    }

    #[test]
    fn test_read_first_message_property_a_watch_names_its_run(
        number in any::<u128>(),
    ) {
        let side = link_side().map_err(fail)?;
        let watch_request = unclaimed_watch(number);

        let reply = side
            .runtime
            .block_on(ask(&side.client, side.host, &watch_request))
            .map_err(fail)?;

        prop_assert_eq!(reply, unclaimed_refusal(number));
    }

    #[test]
    fn test_read_first_message_property_only_the_first_frame_decides(
        number in any::<u128>(),
        text in "\\PC{0,20}",
    ) {
        let side = link_side().map_err(fail)?;
        let first = unclaimed_watch(number);
        let second = ClientMessage::Chat { text };

        let (reply, later_frames) = side
            .runtime
            .block_on(ask_twice_in_one_link(side, &first, &second))
            .map_err(fail)?;

        prop_assert_eq!(reply, unclaimed_refusal(number));
        prop_assert_eq!(later_frames, 0);
    }
}
