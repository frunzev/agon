use orchestration_api::work::RunEvent;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::agent_desk::check_on_desk;
use crate::draft_desk::{
    DRAFTED_NAME_PATTERN, cancel_draft, drafted_answer, fail_draft,
    start_draft,
};
use crate::handler_desk::read_reply_problem;
use crate::support::drafting_desk::{
    DraftingDesk, StartedDraft, agent_message,
};
use crate::support::test_device::fail;

const WORKING: &str = "working";
const DONE: &str = "done";
const REASON_PATTERN: &str = "[a-z]{3,10}( [a-z]{2,8}){0,4}";
const CHATTER_PATTERN: &str = "[A-Z][a-z]{2,10}( [a-z]{2,8}){0,3}";
const MOST_CHATTER: usize = 3;
const MOST_POLLS: usize = 3;
const CANCELLED_PROBLEM: &str =
    "the drafting run did not finish: the drafting run was cancelled";
const NO_ANSWER_PROBLEM: &str =
    "the drafting agent answered without a message";
const NO_JSON_PROBLEM: &str = concat!(
    "the drafting agent did not answer with a workflow: ",
    "the answer holds no JSON object"
);

#[test]
fn test_take_draft_answer_property_working_until_the_run_ends() {
    let cases = (vec(CHATTER_PATTERN, 0..=MOST_CHATTER), 1..=MOST_POLLS);
    check_on_desk(&cases, |desk, (chatter, poll_count)| {
        let draft = start_draft(desk).map_err(fail)?;
        let mut events = Vec::new();
        for text in &chatter {
            events.push(agent_message(text));
        }
        desk.post(&draft, events).map_err(fail)?;

        for _ in 0..poll_count {
            let status = desk.status_reply(&draft);
            prop_assert_eq!(&status["ok"], &json!({ "state": WORKING }));
        }

        prop_assert_eq!(desk.count_task_runs(&draft.task_id), Ok(1));
        Ok(())
    });
}

#[test]
fn test_take_draft_answer_property_a_done_draft_deletes_its_task() {
    check_on_desk(&DRAFTED_NAME_PATTERN, |desk, name| {
        let draft = start_draft(desk).map_err(fail)?;
        desk.finish(&draft, &drafted_answer(&draft, &name))
            .map_err(fail)?;

        let status = desk.status_reply(&draft);

        prop_assert_eq!(&status["ok"]["state"], DONE);
        prop_assert_eq!(desk.count_task_runs(&draft.task_id), Ok(0));
        let again = desk.status_reply(&draft);
        let gone = format!("draft task {} was not found", draft.task_id);
        prop_assert_eq!(read_reply_problem(&again), gone.as_str());
        Ok(())
    });
}

#[test]
fn test_take_draft_answer_property_a_cancelled_draft_keeps_its_task() {
    check_on_desk(&(1..=MOST_POLLS), |desk, poll_count| {
        let draft = start_draft(desk).map_err(fail)?;
        cancel_draft(desk, &draft).map_err(fail)?;

        for _ in 0..poll_count {
            let status = desk.status_reply(&draft);
            prop_assert_eq!(read_reply_problem(&status), CANCELLED_PROBLEM);
        }

        prop_assert_eq!(desk.count_task_runs(&draft.task_id), Ok(1));
        Ok(())
    });
}

#[test]
fn test_read_draft_answer_property_a_failed_run_gives_its_reason() {
    check_on_desk(&REASON_PATTERN, |desk, reason| {
        let draft = start_draft(desk).map_err(fail)?;
        fail_draft(desk, &draft, &reason).map_err(fail)?;

        let status = desk.status_reply(&draft);

        let expected = format!("the drafting run did not finish: {reason}");
        prop_assert_eq!(read_reply_problem(&status), expected.as_str());
        prop_assert_eq!(desk.count_task_runs(&draft.task_id), Ok(0));
        Ok(())
    });
}

#[test]
fn test_read_draft_answer_property_a_done_run_saves_the_answer_unsigned() {
    check_on_desk(&DRAFTED_NAME_PATTERN, |desk, name| {
        let draft = start_draft(desk).map_err(fail)?;
        desk.finish(&draft, &drafted_answer(&draft, &name))
            .map_err(fail)?;

        let status = desk.status_reply(&draft);

        let shown = &status["ok"]["workflow"];
        prop_assert_eq!(&shown["workflow"]["name"], &json!(name));
        prop_assert_eq!(&shown["workflow"]["id"], &json!(draft.workflow_id));
        prop_assert_eq!(&shown["signature_state"], "not_signed_yet");
        Ok(())
    });
}

#[test]
fn test_read_draft_answer_property_a_done_run_never_reads_as_cancelled() {
    check_on_desk(&DRAFTED_NAME_PATTERN, |desk, name| {
        let draft = start_draft(desk).map_err(fail)?;
        desk.finish(&draft, &drafted_answer(&draft, &name))
            .map_err(fail)?;

        let status = desk.status_reply(&draft);

        prop_assert!(status.get("ok").is_some(), "{}", status);
        prop_assert_ne!(read_reply_problem(&status), CANCELLED_PROBLEM);
        Ok(())
    });
}

#[test]
fn test_read_final_agent_message_property_only_the_last_answer_counts() {
    let cases = (DRAFTED_NAME_PATTERN, CHATTER_PATTERN, any::<bool>());
    check_on_desk(&cases, |desk, (name, chatter, is_answer_last)| {
        let draft = start_draft(desk).map_err(fail)?;
        let answer = drafted_answer(&draft, &name);
        let mut messages =
            vec![agent_message(&chatter), agent_message(&answer)];
        if !is_answer_last {
            messages.reverse();
        }
        messages.push(RunEvent::Finished);
        desk.post(&draft, messages).map_err(fail)?;

        let status = desk.status_reply(&draft);

        if is_answer_last {
            prop_assert_eq!(&status["ok"]["state"], DONE);
        } else {
            prop_assert_eq!(read_reply_problem(&status), NO_JSON_PROBLEM);
        }
        Ok(())
    });
}

fn send_person_words(
    desk: &DraftingDesk,
    draft: &StartedDraft,
    person_words: &str,
) -> Result<Value, String> {
    desk.prepared.device.run(&json!({
        "command": "send_chat_message",
        "workspace_id": desk.prepared.workspace_id,
        "run_id": draft.run_id.0.to_string(),
        "text": person_words,
    }))
}

#[test]
fn test_read_final_agent_message_property_person_words_are_not_answers() {
    let cases = (DRAFTED_NAME_PATTERN, CHATTER_PATTERN);
    check_on_desk(&cases, |desk, (name, person_words)| {
        let draft = start_draft(desk).map_err(fail)?;
        let answer = agent_message(&drafted_answer(&draft, &name));
        desk.post(&draft, vec![answer]).map_err(fail)?;
        send_person_words(desk, &draft, &person_words).map_err(fail)?;
        desk.post(&draft, vec![RunEvent::Finished]).map_err(fail)?;

        let status = desk.status_reply(&draft);

        prop_assert_eq!(&status["ok"]["state"], DONE);
        let shown_name = &status["ok"]["workflow"]["workflow"]["name"];
        prop_assert_eq!(shown_name, &json!(name));
        Ok(())
    });
}

#[test]
fn test_read_final_agent_message_property_no_agent_words_no_answer() {
    let cases = vec(CHATTER_PATTERN, 0..=MOST_CHATTER);
    check_on_desk(&cases, |desk, person_words| {
        let draft = start_draft(desk).map_err(fail)?;
        for words in &person_words {
            send_person_words(desk, &draft, words).map_err(fail)?;
        }
        desk.post(&draft, vec![RunEvent::Finished]).map_err(fail)?;

        let status = desk.status_reply(&draft);

        prop_assert_eq!(read_reply_problem(&status), NO_ANSWER_PROBLEM);
        prop_assert_eq!(status.get("ok"), None::<&Value>);
        Ok(())
    });
}
