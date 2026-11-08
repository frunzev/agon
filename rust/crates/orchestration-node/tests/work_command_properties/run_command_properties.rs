use proptest::prelude::*;
use serde_json::{Value, json};

use crate::handler_desk::{NOT_FOUND_START, read_problem, uuid_text_strategy};
use crate::support::test_device::{fail, read_text};
use crate::work_desk::{
    DETAILS_PATTERN, check_on_workspace, list_task_runs, open_work_place,
    run_on_run, start_one_run,
};

const MOST_TASKS: usize = 3;
const FINISHED_REFUSAL: &str = "the run has already finished";
const RETRY_REFUSAL: &str = "only a failed or cancelled run can be retried";
const RUN_COMMANDS_ON_ONE_RUN: [&str; 3] =
    ["show_run", "cancel_run", "retry_run"];
const FINISHED_STATUSES: [&str; 3] = ["done", "failed", "cancelled"];

fn read_status(run: &Value) -> Result<String, String> {
    read_text(run, "/status")
}

#[test]
fn test_handle_run_command_property_list_runs_holds_only_its_task() {
    let cases = (1..=MOST_TASKS, uuid_text_strategy());
    check_on_workspace(&cases, |prepared, (task_count, unknown_task)| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let mut task_ids = Vec::new();
        for _ in 0..task_count {
            let (task_id, _) =
                start_one_run(device, &place, "work").map_err(fail)?;
            task_ids.push(task_id);
        }

        for task_id in &task_ids {
            let runs = list_task_runs(device, task_id).map_err(fail)?;
            prop_assert_eq!(runs.len(), 1);
            prop_assert_eq!(&runs[0]["task_id"], &json!(task_id));
            prop_assert_eq!(&runs[0]["number"], &json!(1));
        }
        let unknown_runs =
            list_task_runs(device, &unknown_task).map_err(fail)?;
        prop_assert!(unknown_runs.is_empty(), "{:?}", unknown_runs);
        Ok(())
    });
}

#[test]
fn test_handle_run_command_property_retry_reopens_the_same_run() {
    check_on_workspace(&DETAILS_PATTERN, |prepared, details| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let (task_id, run_id) =
            start_one_run(device, &place, &details).map_err(fail)?;

        let cancelled = run_on_run(device, "cancel_run", &run_id);
        let retried = run_on_run(device, "retry_run", &run_id);

        prop_assert_eq!(cancelled, Ok(Value::Null));
        prop_assert_eq!(retried, Ok(Value::Null));
        let runs = list_task_runs(device, &task_id).map_err(fail)?;
        prop_assert_eq!(runs.len(), 1);
        prop_assert_eq!(&runs[0]["id"], &json!(run_id));
        prop_assert_eq!(&runs[0]["number"], &json!(1));
        let status = read_status(&runs[0]).map_err(fail)?;
        prop_assert!(!FINISHED_STATUSES.contains(&status.as_str()));
        Ok(())
    });
}

#[test]
fn test_handle_run_command_property_refusals_carry_the_server_reason() {
    check_on_workspace(&DETAILS_PATTERN, |prepared, details| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let (task_id, run_id) =
            start_one_run(device, &place, &details).map_err(fail)?;

        let early_retry =
            read_problem(run_on_run(device, "retry_run", &run_id));
        run_on_run(device, "cancel_run", &run_id).map_err(fail)?;
        let late_cancel =
            read_problem(run_on_run(device, "cancel_run", &run_id));

        prop_assert!(early_retry.contains(RETRY_REFUSAL), "{}", early_retry);
        prop_assert!(early_retry.contains("409"), "{}", early_retry);
        prop_assert!(
            late_cancel.contains(FINISHED_REFUSAL),
            "{}",
            late_cancel
        );
        let runs = list_task_runs(device, &task_id).map_err(fail)?;
        prop_assert_eq!(read_status(&runs[0]).map_err(fail)?, "cancelled");
        Ok(())
    });
}

#[test]
fn test_handle_run_command_property_show_run_progress_matches_the_run() {
    check_on_workspace(&DETAILS_PATTERN, |prepared, details| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let (_, run_id) =
            start_one_run(device, &place, &details).map_err(fail)?;

        let view = run_on_run(device, "show_run", &run_id).map_err(fail)?;

        let run = &view["run"];
        let progress = &view["progress"];
        let step_count = run["steps"].as_array().map_or(0, Vec::len);
        prop_assert_eq!(&progress["run_id"], &json!(run_id));
        prop_assert_eq!(&progress["number"], &run["number"]);
        prop_assert_eq!(&progress["status"], &run["status"]);
        prop_assert_eq!(&progress["step_count"], &json!(step_count));
        prop_assert_eq!(&view["link"], &run["link"]);
        prop_assert_eq!(&view["link_lost_at"], &run["link_lost_at"]);
        Ok(())
    });
}

#[test]
fn test_handle_run_command_property_an_unknown_run_is_not_found() {
    let cases = (uuid_text_strategy(), 0..RUN_COMMANDS_ON_ONE_RUN.len());
    check_on_workspace(&cases, |prepared, (run_id, chosen)| {
        let command_name = RUN_COMMANDS_ON_ONE_RUN[chosen];

        let problem =
            read_problem(run_on_run(&prepared.device, command_name, &run_id));

        prop_assert!(problem.starts_with(NOT_FOUND_START), "{}", problem);
        prop_assert!(problem.contains("the run"), "{}", problem);
        Ok(())
    });
}
