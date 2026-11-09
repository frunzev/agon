use std::time::Duration;

use orchestration_core::identifiers::RunId;
use orchestration_node::live_link_messages::{
    ClientMessage, FileRequest, RunnerMessage,
};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use proptest::prelude::*;
use uuid::Uuid;

use crate::file_host_steps::own_repository;
use crate::live_link_steps::{
    LinkSide, close_link, count_frames_until_end, has_chat, link_side,
    open_link, receive_message, send_client_message, wait_for_chat, watch,
};
use crate::support::test_device::fail;

const REFUSAL_CASES: u32 = 3;
const LONGEST_READ_DELAY_MILLISECONDS: u64 = 1500;
const UNTRUSTED_WATCHER_REASON: &str =
    "the peer is not a trusted client of this run's workspace";
const UNTRUSTED_READER_REASON: &str =
    "the peer is not a trusted client of this project's workspace";

#[derive(Clone, Debug)]
enum OneShotRequest {
    StrangerWatch,
    StrangerBrowse,
    ChatFirst(String),
    UnclaimedWatch(u128),
    ClientBrowse,
}

fn refusing_request_strategy() -> impl Strategy<Value = OneShotRequest> {
    prop_oneof![
        Just(OneShotRequest::StrangerWatch),
        Just(OneShotRequest::StrangerBrowse),
        "\\PC{0,20}".prop_map(OneShotRequest::ChatFirst),
        any::<u128>().prop_map(OneShotRequest::UnclaimedWatch),
    ]
}

fn one_shot_request_strategy() -> impl Strategy<Value = OneShotRequest> {
    prop_oneof![
        refusing_request_strategy(),
        Just(OneShotRequest::ClientBrowse),
    ]
}

fn choose_endpoint<'side>(
    side: &'side LinkSide,
    request: &OneShotRequest,
) -> &'side PeerEndpoint {
    match request {
        OneShotRequest::StrangerWatch | OneShotRequest::StrangerBrowse => {
            &side.stranger
        }
        _ => &side.client,
    }
}

fn build_branch_browse(side: &LinkSide) -> Result<ClientMessage, String> {
    let repository = own_repository(side.host)?;
    let request = FileRequest::ListBranches { repository };
    Ok(ClientMessage::Browse { request })
}

fn build_message(
    side: &LinkSide,
    request: &OneShotRequest,
) -> Result<ClientMessage, String> {
    match request {
        OneShotRequest::StrangerWatch => Ok(ClientMessage::Watch {
            run_id: side.shared_run,
        }),
        OneShotRequest::StrangerBrowse | OneShotRequest::ClientBrowse => {
            build_branch_browse(side)
        }
        OneShotRequest::ChatFirst(text) => {
            Ok(ClientMessage::Chat { text: text.clone() })
        }
        OneShotRequest::UnclaimedWatch(number) => Ok(ClientMessage::Watch {
            run_id: RunId(Uuid::from_u128(*number)),
        }),
    }
}

async fn ask_and_count_the_rest(
    side: &LinkSide,
    request: &OneShotRequest,
    read_delay: Duration,
) -> Result<(RunnerMessage, usize), String> {
    let message = build_message(side, request)?;
    let endpoint = choose_endpoint(side, request);
    let mut link = open_link(endpoint, side.host).await?;
    send_client_message(&mut link, &message).await?;
    tokio::time::sleep(read_delay).await;
    let reply = receive_message(&mut link).await?;
    let later_frames = count_frames_until_end(&mut link).await?;
    Ok((reply, later_frames))
}

fn ask_now(
    side: &LinkSide,
    request: &OneShotRequest,
) -> Result<(RunnerMessage, usize), String> {
    let asking = ask_and_count_the_rest(side, request, Duration::ZERO);
    side.runtime.block_on(asking)
}

async fn chat_and_hear_it(
    side: &LinkSide,
    text: &str,
) -> Result<Vec<RunnerMessage>, String> {
    let mut link = watch(side, side.shared_run).await?;
    let chat = ClientMessage::Chat {
        text: text.to_owned(),
    };
    send_client_message(&mut link, &chat).await?;
    let heard = wait_for_chat(&mut link, text).await?;
    close_link(link).await?;
    Ok(heard)
}

fn unique_text(generated: &str) -> String {
    format!("{} {generated}", Uuid::new_v4())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REFUSAL_CASES))]

    #[test]
    fn test_refuse_property_a_stranger_watcher_hears_the_trust_problem(
        ask_count in 1_usize..3,
    ) {
        let side = link_side().map_err(fail)?;

        for _ in 0..ask_count {
            let (reply, _later_frames) =
                ask_now(side, &OneShotRequest::StrangerWatch).map_err(fail)?;

            let expected = RunnerMessage::Refused {
                reason: UNTRUSTED_WATCHER_REASON.to_owned(),
            };
            prop_assert_eq!(reply, expected);
        }
    }

    #[test]
    fn test_refuse_property_a_stranger_reader_hears_the_trust_problem(
        ask_count in 1_usize..3,
    ) {
        let side = link_side().map_err(fail)?;

        for _ in 0..ask_count {
            let (reply, _later_frames) =
                ask_now(side, &OneShotRequest::StrangerBrowse)
                    .map_err(fail)?;

            let expected = RunnerMessage::Refused {
                reason: UNTRUSTED_READER_REASON.to_owned(),
            };
            prop_assert_eq!(reply, expected);
        }
    }

    #[test]
    fn test_refuse_property_nothing_follows_a_refusal(
        request in refusing_request_strategy(),
    ) {
        let side = link_side().map_err(fail)?;

        let (reply, later_frames) = ask_now(side, &request).map_err(fail)?;

        let is_refused = matches!(reply, RunnerMessage::Refused { .. });
        prop_assert!(is_refused, "{:?}", reply);
        prop_assert_eq!(later_frames, 0);
    }

    #[test]
    fn test_finish_with_property_an_answer_ends_the_link(
        ask_count in 1_usize..3,
    ) {
        let side = link_side().map_err(fail)?;

        for _ in 0..ask_count {
            let (reply, later_frames) =
                ask_now(side, &OneShotRequest::ClientBrowse).map_err(fail)?;

            let is_answered = matches!(reply, RunnerMessage::Answered { .. });
            prop_assert!(is_answered, "{:?}", reply);
            prop_assert_eq!(later_frames, 0);
        }
    }

    #[test]
    fn test_finish_with_property_every_one_shot_request_ends_after_one(
        request in one_shot_request_strategy(),
    ) {
        let side = link_side().map_err(fail)?;

        let (reply, later_frames) = ask_now(side, &request).map_err(fail)?;

        let is_final = matches!(
            reply,
            RunnerMessage::Refused { .. } | RunnerMessage::Answered { .. }
        );
        prop_assert!(is_final, "{:?}", reply);
        prop_assert_eq!(later_frames, 0);
    }

    #[test]
    fn test_finish_with_property_a_late_reader_still_gets_the_reply(
        request in one_shot_request_strategy(),
        delay_milliseconds in 0..=LONGEST_READ_DELAY_MILLISECONDS,
    ) {
        let side = link_side().map_err(fail)?;
        let read_delay = Duration::from_millis(delay_milliseconds);

        let asking = ask_and_count_the_rest(side, &request, read_delay);
        let (reply, later_frames) =
            side.runtime.block_on(asking).map_err(fail)?;

        let is_accepted = reply == RunnerMessage::Accepted;
        prop_assert!(!is_accepted, "{:?}", reply);
        prop_assert_eq!(later_frames, 0);
    }

    #[test]
    fn test_send_message_property_a_watcher_first_hears_accepted(
        watch_count in 1_usize..4,
    ) {
        let side = link_side().map_err(fail)?;

        let watched = side.runtime.block_on(async {
            for _ in 0..watch_count {
                let link = watch(side, side.shared_run).await?;
                close_link(link).await?;
            }
            Ok::<(), String>(())
        });

        prop_assert_eq!(watched, Ok(()));
    }

    #[test]
    fn test_send_message_property_every_frame_to_a_watcher_is_events(
        generated in "[a-z ]{0,20}",
    ) {
        let side = link_side().map_err(fail)?;
        let text = unique_text(&generated);

        let heard = side
            .runtime
            .block_on(chat_and_hear_it(side, &text))
            .map_err(fail)?;

        for message in &heard {
            let is_events = matches!(message, RunnerMessage::Events { .. });
            prop_assert!(is_events, "{:?}", message);
        }
    }

    #[test]
    fn test_send_message_property_chat_text_survives_the_link(
        generated in "\\PC{0,40}",
    ) {
        let side = link_side().map_err(fail)?;
        let text = unique_text(&generated);

        let heard = side
            .runtime
            .block_on(chat_and_hear_it(side, &text))
            .map_err(fail)?;

        let last_heard = heard.last();
        let carries_the_text =
            last_heard.is_some_and(|message| has_chat(message, &text));
        prop_assert!(carries_the_text, "{:?}", last_heard);
    }
}
