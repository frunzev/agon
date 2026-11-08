use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::json;

use crate::support::drafting_desk::open_desk_or_panic;
use crate::support::item_drafting_desk::{
    draft_item_command, drafted_kind_strategy, drafted_task_answer,
    fail_item_draft, finish_item_draft, item_draft_status, start_item_draft,
};
use crate::support::test_device::{fail, read_success};

const DRAFT_CASES: u32 = 4;
const DRAFTER_KIND: &str = "claude_code";
const WORKING_STATE: &str = "working";
const BLANK_PATTERN: &str = "[ \t\n]{0,4}";
const REQUEST_PATTERN: &str = "[A-Za-z][A-Za-z ,.]{0,30}";
const REMOTE_FOLDER_ADDRESS: &str = "github.com/acme/app";
const TITLE_PATTERN: &str = "[A-Z][a-z]{0,10}( [a-z]{1,8}){0,2}";

#[test]
fn test_handle_item_draft_command_property_names_the_task_and_drafter() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DRAFT_CASES));
    let drawn = (drafted_kind_strategy(), REQUEST_PATTERN);

    let outcome = runner.run(&drawn, |(kind, request)| {
        let command = draft_item_command(&desk.prepared, kind, &request);
        let first = desk.prepared.device.run(&command).map_err(fail)?;
        let second = desk.prepared.device.run(&command).map_err(fail)?;
        desk.claim_drafting_run().map_err(fail)?;
        desk.claim_drafting_run().map_err(fail)?;

        let fields = first.as_object().cloned().unwrap_or_default();
        prop_assert_eq!(fields.len(), 2, "{}", first);
        prop_assert_eq!(&first["drafter"], &json!(DRAFTER_KIND));
        prop_assert!(first["task_id"].is_string(), "{}", first);
        prop_assert_ne!(&first["task_id"], &second["task_id"]);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_handle_item_draft_command_property_working_until_the_run_ends() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DRAFT_CASES));
    let drawn = (drafted_kind_strategy(), 1_usize..4);

    let outcome = runner.run(&drawn, |(kind, read_count)| {
        let command = draft_item_command(&desk.prepared, kind, "Draft it");
        let draft = start_item_draft(&desk, &command).map_err(fail)?;

        for _ in 0..read_count {
            let status = item_draft_status(&desk, &draft);
            prop_assert_eq!(
                status,
                json!({ "ok": { "state": WORKING_STATE } })
            );
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_handle_item_draft_command_property_an_ended_draft_never_works_again() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DRAFT_CASES));

    let outcome = runner.run(&any::<bool>(), |is_failed| {
        let command = draft_item_command(&desk.prepared, "task", "Ship 2.4");
        let draft = start_item_draft(&desk, &command).map_err(fail)?;
        if is_failed {
            fail_item_draft(&desk, &draft, "the agent gave up")
                .map_err(fail)?;
        } else {
            let answer = drafted_task_answer(&desk.prepared.project_id);
            let final_message = format!("```json\n{answer}\n```");
            finish_item_draft(&desk, &draft, &final_message).map_err(fail)?;
        }
        let first = item_draft_status(&desk, &draft);
        let second = item_draft_status(&desk, &draft);

        let working = json!({ "ok": { "state": WORKING_STATE } });
        let gone = format!("draft task {} was not found", draft.task_id);
        prop_assert_ne!(&first, &working);
        prop_assert_eq!(read_success(&second), Err(gone));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_queue_drafting_task_property_a_blank_request_queues_nothing() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DRAFT_CASES));
    let drawn = (drafted_kind_strategy(), BLANK_PATTERN, any::<bool>());

    let outcome = runner.run(&drawn, |(kind, blank, is_note)| {
        let mut command = draft_item_command(&desk.prepared, kind, &blank);
        let mut expected = "the request cannot be empty";
        if is_note {
            command = draft_item_command(&desk.prepared, kind, "Draft it");
            command["change"] = json!({ "draft": {}, "note": blank });
            expected = "the change note cannot be empty";
        }
        let refused = desk.prepared.device.run(&command);
        let queued = desk.claim_drafting_run();

        prop_assert_eq!(refused, Err(expected.to_owned()));
        prop_assert!(queued.is_err(), "{:?}", queued);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_queue_drafting_task_property_the_task_names_its_kind_and_request() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DRAFT_CASES));
    let drawn = (drafted_kind_strategy(), REQUEST_PATTERN);

    let outcome = runner.run(&drawn, |(kind, request)| {
        let command = draft_item_command(&desk.prepared, kind, &request);
        let drafting = desk.prepared.device.run(&command).map_err(fail)?;
        let assignment = desk.claim_drafting_run().map_err(fail)?;

        let task = &assignment.task;
        let task_id = json!(task.id.0.to_string());
        prop_assert_eq!(&drafting["task_id"], &task_id);
        prop_assert_eq!(&task.title, &format!("Draft new {kind}"));
        prop_assert!(task.details.contains(&request), "{}", task.details);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_queue_drafting_task_property_folders_belong_to_projects_only() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DRAFT_CASES));
    let kind = drafted_kind_strategy()
        .prop_filter("not a project", |kind| *kind != "project");

    let outcome = runner.run(&kind, |kind| {
        let mut command = draft_item_command(&desk.prepared, kind, "Draft it");
        command["chosen_folders"] = json!([{
            "address": REMOTE_FOLDER_ADDRESS,
            "default_branch": "main",
        }]);
        let refused = desk.prepared.device.run(&command);

        let message = refused.err().unwrap_or_default();
        prop_assert!(message.contains(kind), "{}", message);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_read_item_draft_property_a_finished_task_draft_keeps_its_title() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DRAFT_CASES));

    let outcome = runner.run(&TITLE_PATTERN, |title| {
        let command = draft_item_command(&desk.prepared, "task", "Draft it");
        let draft = start_item_draft(&desk, &command).map_err(fail)?;
        let mut answer = drafted_task_answer(&desk.prepared.project_id);
        answer["title"] = json!(title);
        let final_message = format!("Here:\n```json\n{answer}\n```");
        finish_item_draft(&desk, &draft, &final_message).map_err(fail)?;
        let status = read_success(&item_draft_status(&desk, &draft));

        let status = status.map_err(fail)?;
        prop_assert_eq!(&status["state"], &json!("done"));
        prop_assert_eq!(&status["draft"]["title"], &json!(title));
        prop_assert_eq!(&status["draft"]["kind"], &json!("task"));
        prop_assert_eq!(&status["problems"], &json!([]));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_read_item_draft_property_an_answer_without_json_names_its_kind() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DRAFT_CASES));
    let drawn = (drafted_kind_strategy(), "[a-z ]{1,30}");

    let outcome = runner.run(&drawn, |(kind, final_message)| {
        let command = draft_item_command(&desk.prepared, kind, "Draft it");
        let draft = start_item_draft(&desk, &command).map_err(fail)?;
        finish_item_draft(&desk, &draft, &final_message).map_err(fail)?;
        let status = read_success(&item_draft_status(&desk, &draft));

        let expected_start =
            format!("the drafting agent did not answer with a {kind}: ");
        let message = status.err().unwrap_or_default();
        prop_assert!(message.starts_with(&expected_start), "{}", message);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_read_item_draft_property_a_failed_run_names_its_reason() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(DRAFT_CASES));
    let drawn = (drafted_kind_strategy(), "[a-z][a-z ]{0,20}");

    let outcome = runner.run(&drawn, |(kind, reason)| {
        let command = draft_item_command(&desk.prepared, kind, "Draft it");
        let draft = start_item_draft(&desk, &command).map_err(fail)?;
        fail_item_draft(&desk, &draft, &reason).map_err(fail)?;
        let status = read_success(&item_draft_status(&desk, &draft));

        let message = status.err().unwrap_or_default();
        prop_assert!(message.contains(&reason), "{}", message);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
