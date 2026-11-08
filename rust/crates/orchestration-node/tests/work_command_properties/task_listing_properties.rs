use std::collections::BTreeSet;

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::handler_desk::{read_problem, uuid_text_strategy};
use crate::support::command_builders::PROJECT_NAME;
use crate::support::test_device::{TestDevice, fail, read_text};
use crate::task_creation_properties::{list_task_views, list_view};
use crate::work_desk::{
    START_LATER, check_on_workspace, create_task, list_task_runs,
    open_work_place, run_on_run,
};

const MOST_TASKS: usize = 3;
const MOST_RUNS: usize = 3;
const ALREADY_RUNNING: &str = "the task is already running";
const CONFLICT_STATUS: &str = "409";
const SUMMARY_COUNT_FIELDS: [&str; 5] =
    ["to_do", "running", "waiting_for_approval", "failed", "done"];

pub fn start_task(
    device: &TestDevice,
    task_id: &str,
) -> Result<Value, String> {
    device.run(&json!({ "command": "start_task", "task_id": task_id }))
}

fn read_listed_ids(views: &[Value]) -> Result<BTreeSet<String>, String> {
    let mut listed_ids = BTreeSet::new();
    for view in views {
        listed_ids.insert(read_text(view, "/task/id")?);
    }
    Ok(listed_ids)
}

#[test]
fn test_list_workspace_tasks_property_only_tasks_of_this_workspace() {
    let cases = (1..=MOST_TASKS, 1..=MOST_TASKS);
    check_on_workspace(&cases, |prepared, (home_count, other_count)| {
        let device = &prepared.device;
        let home = open_work_place(device).map_err(fail)?;
        let elsewhere = open_work_place(device).map_err(fail)?;
        let mut home_ids = BTreeSet::new();
        for _ in 0..home_count {
            let task_id = create_task(device, &home, "work", START_LATER)
                .map_err(fail)?;
            home_ids.insert(task_id);
        }
        for _ in 0..other_count {
            create_task(device, &elsewhere, "work", START_LATER)
                .map_err(fail)?;
        }

        let view = list_view(device, "list_tasks", &home.workspace_id)
            .map_err(fail)?;

        let views = list_task_views(&view);
        prop_assert_eq!(read_listed_ids(&views).map_err(fail)?, home_ids);
        for task_view in &views {
            prop_assert_eq!(&task_view["project_name"], PROJECT_NAME);
        }
        Ok(())
    });
}

#[test]
fn test_list_workspace_tasks_property_drafting_tasks_stay_hidden() {
    check_on_workspace(&"[A-Z][a-z ]{4,20}", |prepared, description| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;

        let drafting = device
            .run(&json!({
                "command": "draft_workflow",
                "workspace_id": place.workspace_id,
                "description": description,
            }))
            .map_err(fail)?;

        let drafting_task = read_text(&drafting, "/task_id").map_err(fail)?;
        let runs = list_task_runs(device, &drafting_task).map_err(fail)?;
        prop_assert_eq!(runs.len(), 1);
        let tasks = list_view(device, "list_tasks", &place.workspace_id)
            .map_err(fail)?;
        prop_assert!(list_task_views(&tasks).is_empty());
        let jobs = list_view(device, "list_jobs", &place.workspace_id)
            .map_err(fail)?;
        prop_assert_eq!(jobs, json!([]));
        Ok(())
    });
}

#[test]
fn test_list_workspace_tasks_property_an_unknown_workspace_lists_nothing() {
    check_on_workspace(
        &uuid_text_strategy(),
        |prepared, unknown_workspace| {
            let device = &prepared.device;
            let place = open_work_place(device).map_err(fail)?;
            create_task(device, &place, "work", START_LATER).map_err(fail)?;

            let view = list_view(device, "list_tasks", &unknown_workspace)
                .map_err(fail)?;

            prop_assert!(list_task_views(&view).is_empty());
            for field in SUMMARY_COUNT_FIELDS {
                prop_assert_eq!(&view["summary"][field], &json!(0));
            }
            Ok(())
        },
    );
}

#[test]
fn test_handle_task_command_property_start_task_numbers_runs_per_task() {
    check_on_workspace(&(1..=MOST_RUNS), |prepared, run_count| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let task_id =
            create_task(device, &place, "work", START_LATER).map_err(fail)?;
        let other_task =
            create_task(device, &place, "work", START_LATER).map_err(fail)?;

        for expected_number in 1..=run_count {
            let run = start_task(device, &task_id).map_err(fail)?;
            prop_assert_eq!(&run["number"], &json!(expected_number));
            let run_id = read_text(&run, "/id").map_err(fail)?;
            run_on_run(device, "cancel_run", &run_id).map_err(fail)?;
        }
        let other_run = start_task(device, &other_task).map_err(fail)?;

        prop_assert_eq!(&other_run["number"], &json!(1));
        let runs = list_task_runs(device, &task_id).map_err(fail)?;
        let mut numbers = Vec::new();
        for run in &runs {
            numbers.push(run["number"].clone());
        }
        let mut expected_numbers = Vec::new();
        for number in 1..=run_count {
            expected_numbers.push(json!(number));
        }
        prop_assert_eq!(numbers, expected_numbers);
        Ok(())
    });
}

#[test]
fn test_handle_task_command_property_one_active_run_per_task() {
    check_on_workspace(&(2..=MOST_RUNS), |prepared, attempts| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let task_id =
            create_task(device, &place, "work", START_LATER).map_err(fail)?;
        start_task(device, &task_id).map_err(fail)?;

        for _ in 1..attempts {
            let problem = read_problem(start_task(device, &task_id));
            prop_assert!(problem.contains(ALREADY_RUNNING), "{}", problem);
            prop_assert!(problem.contains(CONFLICT_STATUS), "{}", problem);
        }

        let runs = list_task_runs(device, &task_id).map_err(fail)?;
        prop_assert_eq!(runs.len(), 1);
        Ok(())
    });
}

#[test]
fn test_handle_task_command_property_start_task_reply_is_the_listed_run() {
    check_on_workspace(&"[a-z]{4,12}", |prepared, details| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let task_id = create_task(device, &place, &details, START_LATER)
            .map_err(fail)?;

        let started = start_task(device, &task_id).map_err(fail)?;

        let runs = list_task_runs(device, &task_id).map_err(fail)?;
        prop_assert_eq!(runs.len(), 1);
        prop_assert_eq!(&started, &runs[0]);
        prop_assert_eq!(&started["task_id"], &json!(task_id));
        Ok(())
    });
}
