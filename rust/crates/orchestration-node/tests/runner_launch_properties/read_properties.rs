use orchestration_core::run::{ChatAuthor, ChatMessage};
use orchestration_runner::runner_server::RunnerServer;
use proptest::prelude::*;
use serde_json::json;

use crate::server_desk::{
    DETAILS_PATTERN, NO_ACCOUNT, SERVER_CASES, chat_event,
    open_accountless_runner, server_desk, unknown_run,
};
use crate::support::test_device::fail;

const MOST_MESSAGES: usize = 4;
const CHAT_PATTERN: &str = "[A-Za-z0-9]{1,12}( [A-Za-z0-9]{1,12}){0,2}";
const UNICODE_PATTERN: &str = "[a-z]{1,4}[\u{e9}\u{4e16}\u{1f600} ]{0,6}[a-z]";

fn texts_of(messages: &[ChatMessage]) -> Vec<String> {
    let mut texts = Vec::new();
    for message in messages {
        texts.push(message.text.clone());
    }
    texts
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SERVER_CASES))]

    #[test]
    fn test_read_user_messages_property_skips_what_the_agent_said(
        person_texts in prop::collection::vec(CHAT_PATTERN, 1..MOST_MESSAGES),
        agent_texts in prop::collection::vec(CHAT_PATTERN, 1..MOST_MESSAGES),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&runner, "person chat").map_err(fail)?;
        let run_id = assignment.run.id;
        for (person_text, agent_text) in person_texts.iter().zip(&agent_texts)
        {
            desk.send_chat(run_id, person_text).map_err(fail)?;
            let event = chat_event(ChatAuthor::Agent, agent_text);
            desk.post(&runner, run_id, vec![event]).map_err(fail)?;
        }

        let messages =
            desk.wait(runner.read_user_messages(run_id)).map_err(fail)?;

        let pairs = person_texts.len().min(agent_texts.len());
        prop_assert_eq!(texts_of(&messages), person_texts[..pairs].to_vec());
        for message in &messages {
            prop_assert_eq!(message.author, ChatAuthor::You);
        }
    }

    #[test]
    fn test_read_user_messages_property_an_unknown_run_is_refused(
        number in any::<u128>(),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;

        let run_id = unknown_run(number);
        let messages = desk.wait(runner.read_user_messages(run_id));

        prop_assert!(messages.is_err(), "{:?}", messages);
    }

    #[test]
    fn test_read_user_messages_property_a_quiet_run_has_none(
        details in DETAILS_PATTERN,
        agent_texts in prop::collection::vec(CHAT_PATTERN, 0..MOST_MESSAGES),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&runner, &details).map_err(fail)?;
        for agent_text in &agent_texts {
            let event = chat_event(ChatAuthor::Agent, agent_text);
            desk.post(&runner, assignment.run.id, vec![event])
                .map_err(fail)?;
        }

        let messages = desk
            .wait(runner.read_user_messages(assignment.run.id))
            .map_err(fail)?;

        prop_assert_eq!(messages, Vec::new());
    }

    #[test]
    fn test_read_opened_user_messages_property_opens_every_text_exactly(
        text in UNICODE_PATTERN,
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&runner, "unicode chat").map_err(fail)?;

        desk.send_chat(assignment.run.id, &text).map_err(fail)?;
        let messages = desk
            .wait(runner.read_user_messages(assignment.run.id))
            .map_err(fail)?;

        prop_assert_eq!(texts_of(&messages), vec![text]);
    }

    #[test]
    fn test_read_opened_user_messages_property_keeps_the_sending_order(
        texts in prop::collection::vec(CHAT_PATTERN, 1..MOST_MESSAGES),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&runner, "ordered chat").map_err(fail)?;
        for text in &texts {
            desk.send_chat(assignment.run.id, text).map_err(fail)?;
        }

        let messages = desk
            .wait(runner.read_user_messages(assignment.run.id))
            .map_err(fail)?;

        prop_assert_eq!(texts_of(&messages), texts);
    }

    #[test]
    fn test_read_opened_user_messages_property_needs_an_account(
        number in any::<u128>(),
    ) {
        let (_device, runner) = open_accountless_runner().map_err(fail)?;
        let desk = server_desk().map_err(fail)?;

        let run_id = unknown_run(number);
        let messages = desk.wait(runner.read_user_messages(run_id));

        let reason = messages.map_err(|problem| problem.reason);
        prop_assert_eq!(reason, Err(NO_ACCOUNT.to_owned()));
    }

    #[test]
    fn test_is_run_stopped_property_a_claimed_run_is_not_stopped(
        details in DETAILS_PATTERN,
        repeat_count in 1_usize..3,
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&runner, &details).map_err(fail)?;

        for _ in 0..repeat_count {
            let stopped =
                desk.wait(runner.is_run_stopped(assignment.run.id));
            prop_assert_eq!(stopped.ok(), Some(false));
        }
    }

    #[test]
    fn test_is_run_stopped_property_a_cancelled_run_is_stopped(
        details in DETAILS_PATTERN,
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&runner, &details).map_err(fail)?;

        desk.device()
            .run(&json!({
                "command": "cancel_run",
                "run_id": assignment.run.id.0.to_string(),
            }))
            .map_err(fail)?;
        let stopped = desk.wait(runner.is_run_stopped(assignment.run.id));

        prop_assert_eq!(stopped.ok(), Some(true));
    }

    #[test]
    fn test_is_run_stopped_property_an_unknown_run_is_refused(
        number in any::<u128>(),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;

        let stopped = desk.wait(runner.is_run_stopped(unknown_run(number)));

        prop_assert!(stopped.is_err(), "{:?}", stopped);
    }
}
