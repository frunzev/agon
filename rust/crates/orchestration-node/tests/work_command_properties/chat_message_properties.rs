use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::handler_desk::{
    POST_METHOD, count_requests_to, read_problem, uuid_text_strategy,
};
use crate::support::test_device::{TestDevice, fail};
use crate::work_desk::{check_on_workspace, open_work_place, start_one_run};

const MESSAGE_PATTERN: &str = " {0,2}[a-z]{6,12}( [a-z0-9]{1,8}){0,3} {0,2}";
const BLANK_PATTERN: &str = "[ \t\n]{0,6}";
const MOST_MESSAGES: usize = 3;
const PERSON_AUTHOR: &str = "you";
const RUNS_PATH: &str = "/runs/";
const EMPTY_MESSAGE_PROBLEM: &str = "the message cannot be empty";
const MISSING_KEY_START: &str = "this device holds no key for workspace";

fn send_message(
    device: &TestDevice,
    workspace_id: &str,
    run_id: &str,
    text: &str,
) -> Result<Value, String> {
    device.run(&json!({
        "command": "send_chat_message",
        "workspace_id": workspace_id,
        "run_id": run_id,
        "text": text,
    }))
}

fn list_person_messages(
    device: &TestDevice,
    run_id: &str,
) -> Result<Vec<String>, String> {
    let view =
        device.run(&json!({ "command": "show_run", "run_id": run_id }))?;
    let chat = view["run"]["chat"].as_array().cloned().unwrap_or_default();
    let mut texts = Vec::new();
    for message in chat {
        if message["author"] == PERSON_AUTHOR {
            let text = message["text"].as_str().unwrap_or_default();
            texts.push(text.to_owned());
        }
    }
    Ok(texts)
}

#[test]
fn test_send_over_live_link_property_without_a_link_the_server_keeps_it() {
    let cases = vec(MESSAGE_PATTERN, 1..=MOST_MESSAGES);
    check_on_workspace(&cases, |prepared, texts| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let (_, run_id) =
            start_one_run(device, &place, "work").map_err(fail)?;

        for text in &texts {
            let sent =
                send_message(device, &place.workspace_id, &run_id, text)
                    .map_err(fail)?;
            prop_assert_eq!(&sent["author"], PERSON_AUTHOR);
            prop_assert_eq!(&sent["text"], &json!(text));
            prop_assert_eq!(&sent["is_error"], false);
            prop_assert_eq!(&sent["waiting_to_send"], false);
        }

        let kept = list_person_messages(device, &run_id).map_err(fail)?;
        prop_assert_eq!(kept, texts);
        Ok(())
    });
}

#[test]
fn test_send_over_live_link_property_a_blank_message_reaches_nobody() {
    check_on_workspace(&BLANK_PATTERN, |prepared, blank_text| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let (_, run_id) =
            start_one_run(device, &place, "work").map_err(fail)?;
        let posts_before =
            count_requests_to(&prepared.server, POST_METHOD, RUNS_PATH);

        let problem = read_problem(send_message(
            device,
            &place.workspace_id,
            &run_id,
            &blank_text,
        ));

        prop_assert_eq!(problem, EMPTY_MESSAGE_PROBLEM);
        let posts_after =
            count_requests_to(&prepared.server, POST_METHOD, RUNS_PATH);
        prop_assert_eq!(posts_after, posts_before);
        let kept = list_person_messages(device, &run_id).map_err(fail)?;
        prop_assert!(kept.is_empty(), "{:?}", kept);
        Ok(())
    });
}

#[test]
fn test_send_over_live_link_property_the_server_only_sees_ciphertext() {
    check_on_workspace(&"[a-z]{16,24}", |prepared, secret_text| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let (_, run_id) =
            start_one_run(device, &place, "work").map_err(fail)?;

        send_message(device, &place.workspace_id, &run_id, &secret_text)
            .map_err(fail)?;

        let stored = prepared.server.read_stored_state().map_err(fail)?;
        prop_assert!(!stored.contains(&secret_text));
        let kept = list_person_messages(device, &run_id).map_err(fail)?;
        prop_assert_eq!(kept, vec![secret_text]);
        Ok(())
    });
}

#[test]
fn test_handle_run_command_property_a_message_needs_the_workspace_key() {
    let cases = (uuid_text_strategy(), MESSAGE_PATTERN);
    check_on_workspace(&cases, |prepared, (foreign_workspace, text)| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let (_, run_id) =
            start_one_run(device, &place, "work").map_err(fail)?;

        let problem = read_problem(send_message(
            device,
            &foreign_workspace,
            &run_id,
            &text,
        ));

        prop_assert!(problem.starts_with(MISSING_KEY_START), "{}", problem);
        let kept = list_person_messages(device, &run_id).map_err(fail)?;
        prop_assert!(kept.is_empty(), "{:?}", kept);
        Ok(())
    });
}
