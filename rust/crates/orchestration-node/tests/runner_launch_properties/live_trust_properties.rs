use orchestration_core::identifiers::{ProjectId, RunId};
use orchestration_node::live_link_messages::{
    ClientMessage, FileRequest, RepositoryReference, RunnerMessage,
};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use proptest::prelude::*;
use uuid::Uuid;

use crate::file_host_steps::{own_repository, repository_of};
use crate::live_link_steps::{
    LinkSide, QUIET_PERIOD, ask, close_link, collect_for, link_side,
    read_chat_texts, send_client_message, wait_for_chat, watch,
};
use crate::support::test_device::fail;

const TRUST_CASES: u32 = 2;
const UNTRUSTED_WATCHER: &str =
    "the peer is not a trusted client of this run's workspace";
const UNTRUSTED_READER: &str =
    "the peer is not a trusted client of this project's workspace";
const OTHER_ADDRESS_PATTERN: &str = "github\\.com/[a-z]{1,8}/[a-z]{1,8}";
const BRANCH: &str = "main";

fn unique_text(generated: &str) -> String {
    format!("{} {generated}", Uuid::new_v4())
}

fn chat(text: &str) -> ClientMessage {
    ClientMessage::Chat {
        text: text.to_owned(),
    }
}

fn refusal(reason: &str) -> RunnerMessage {
    RunnerMessage::Refused {
        reason: reason.to_owned(),
    }
}

fn request_of_kind(
    kind: usize,
    repository: RepositoryReference,
) -> FileRequest {
    match kind {
        0 => FileRequest::ListBranches { repository },
        1 => FileRequest::ListFolder {
            repository,
            branch: BRANCH.to_owned(),
            folder: String::new(),
        },
        _ => FileRequest::ReadFile {
            repository,
            branch: BRANCH.to_owned(),
            path: "src/app.ts".to_owned(),
        },
    }
}

fn ask_now(
    side: &LinkSide,
    endpoint: &PeerEndpoint,
    message: &ClientMessage,
) -> Result<RunnerMessage, String> {
    side.runtime.block_on(ask(endpoint, side.host, message))
}

async fn hear_after_joining(
    side: &LinkSide,
    before_text: &str,
    after_text: &str,
) -> Result<Vec<String>, String> {
    let mut speaker = watch(side, side.shared_run).await?;
    send_client_message(&mut speaker, &chat(before_text)).await?;
    wait_for_chat(&mut speaker, before_text).await?;
    let mut listener = watch(side, side.shared_run).await?;
    send_client_message(&mut speaker, &chat(after_text)).await?;
    let heard = wait_for_chat(&mut listener, after_text).await?;
    let later = collect_for(&mut listener, QUIET_PERIOD).await?;
    close_link(speaker).await?;
    close_link(listener).await?;
    let mut texts = Vec::new();
    for message in heard.iter().chain(&later) {
        texts.extend(read_chat_texts(message));
    }
    Ok(texts)
}

async fn hear_after_another_leaves(
    side: &LinkSide,
    text: &str,
) -> Result<(), String> {
    let leaving = watch(side, side.shared_run).await?;
    let mut staying = watch(side, side.shared_run).await?;
    close_link(leaving).await?;
    send_client_message(&mut staying, &chat(text)).await?;
    wait_for_chat(&mut staying, text).await?;
    close_link(staying).await
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(TRUST_CASES))]

    #[test]
    fn test_authorize_watcher_property_a_stranger_hears_the_trust_problem(
        watches_the_lone_run in any::<bool>(),
    ) {
        let side = link_side().map_err(fail)?;
        let run_id = if watches_the_lone_run {
            side.lone_run
        } else {
            side.shared_run
        };

        let reply = ask_now(
            side,
            &side.stranger,
            &ClientMessage::Watch { run_id },
        )
        .map_err(fail)?;

        prop_assert_eq!(reply, refusal(UNTRUSTED_WATCHER));
    }

    #[test]
    fn test_authorize_watcher_property_a_stranger_is_never_accepted(
        number in any::<u128>(),
    ) {
        let side = link_side().map_err(fail)?;
        let run_id = RunId(Uuid::from_u128(number));

        let reply = ask_now(
            side,
            &side.stranger,
            &ClientMessage::Watch { run_id },
        )
        .map_err(fail)?;

        let is_refused = matches!(reply, RunnerMessage::Refused { .. });
        prop_assert!(is_refused, "{:?}", reply);
    }

    #[test]
    fn test_authorize_watcher_property_the_client_watches_every_claim(
        watches_the_lone_run in any::<bool>(),
    ) {
        let side = link_side().map_err(fail)?;
        let run_id = if watches_the_lone_run {
            side.lone_run
        } else {
            side.shared_run
        };

        let reply = ask_now(
            side,
            &side.client,
            &ClientMessage::Watch { run_id },
        )
        .map_err(fail)?;

        prop_assert_eq!(reply, RunnerMessage::Accepted);
    }

    #[test]
    fn test_authorize_file_reader_property_a_stranger_reader_is_refused(
        kind in 0_usize..3,
    ) {
        let side = link_side().map_err(fail)?;
        let repository = own_repository(side.host).map_err(fail)?;
        let request = request_of_kind(kind, repository);

        let reply = ask_now(
            side,
            &side.stranger,
            &ClientMessage::Browse { request },
        )
        .map_err(fail)?;

        prop_assert_eq!(reply, refusal(UNTRUSTED_READER));
    }

    #[test]
    fn test_authorize_file_reader_property_another_repository_is_refused(
        kind in 0_usize..3,
        address in OTHER_ADDRESS_PATTERN,
    ) {
        let side = link_side().map_err(fail)?;
        let repository = repository_of(side.host, &address).map_err(fail)?;
        let request = request_of_kind(kind, repository);

        let reply = ask_now(
            side,
            &side.client,
            &ClientMessage::Browse { request },
        )
        .map_err(fail)?;

        let expected =
            format!("the repository {address} is not part of the project");
        prop_assert_eq!(reply, refusal(&expected));
    }

    #[test]
    fn test_authorize_file_reader_property_an_unknown_project_is_refused(
        kind in 0_usize..3,
        number in any::<u128>(),
    ) {
        let side = link_side().map_err(fail)?;
        let own = own_repository(side.host).map_err(fail)?;
        let project_id = ProjectId(Uuid::from_u128(number));
        prop_assume!(project_id != own.project_id);
        let repository = RepositoryReference {
            project_id,
            address: own.address,
        };
        let request = request_of_kind(kind, repository);

        let reply = ask_now(
            side,
            &side.client,
            &ClientMessage::Browse { request },
        )
        .map_err(fail)?;

        prop_assert_eq!(reply, refusal(UNTRUSTED_READER));
    }

    #[test]
    fn test_subscribe_to_live_updates_property_old_chats_are_not_replayed(
        before in "[a-z]{1,12}",
        after in "[a-z]{1,12}",
    ) {
        let side = link_side().map_err(fail)?;
        let before_text = unique_text(&before);
        let after_text = unique_text(&after);

        let heard = side
            .runtime
            .block_on(hear_after_joining(side, &before_text, &after_text))
            .map_err(fail)?;

        prop_assert!(heard.contains(&after_text), "{:?}", heard);
        prop_assert!(!heard.contains(&before_text), "{:?}", heard);
    }

    #[test]
    fn test_subscribe_to_live_updates_property_a_leaver_keeps_others_fed(
        generated in "\\PC{0,30}",
    ) {
        let side = link_side().map_err(fail)?;
        let text = unique_text(&generated);

        let heard = side
            .runtime
            .block_on(hear_after_another_leaves(side, &text));

        prop_assert_eq!(heard, Ok(()));
    }

    #[test]
    fn test_subscribe_to_live_updates_property_every_chat_is_heard_once(
        generated in prop::collection::vec("[a-z]{1,10}", 1..4),
    ) {
        let side = link_side().map_err(fail)?;
        let mut texts = Vec::new();
        for text in &generated {
            texts.push(unique_text(text));
        }

        let heard = side.runtime.block_on(async {
            let mut link = watch(side, side.shared_run).await?;
            for text in &texts {
                send_client_message(&mut link, &chat(text)).await?;
            }
            let last_text = texts.last().cloned().unwrap_or_default();
            let mut received = wait_for_chat(&mut link, &last_text).await?;
            received.extend(collect_for(&mut link, QUIET_PERIOD).await?);
            close_link(link).await?;
            Ok::<_, String>(received)
        });
        let heard = heard.map_err(fail)?;

        let mut heard_texts = Vec::new();
        for message in &heard {
            for text in read_chat_texts(message) {
                if texts.contains(&text) {
                    heard_texts.push(text);
                }
            }
        }
        prop_assert_eq!(heard_texts, texts);
    }
}
