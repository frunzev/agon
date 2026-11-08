use proptest::prelude::*;
use serde_json::{Value, json};

use crate::handler_desk::{
    NOT_FOUND_START, POST_METHOD, count_requests_to, read_problem,
    uuid_text_strategy,
};
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;
use crate::task_creation_properties::{
    create_task_from, find_listed_task, list_task_views, list_view,
};
use crate::task_samples::{TaskSample, schedule_sample, task_sample};
use crate::work_desk::{
    START_LATER, WorkPlace, check_on_workspace, open_work_place,
};

const BLANK_PATTERN: &str = "[ \t\n]{0,6}";
const TASKS_PATH: &str = "/tasks";
const PUT_METHOD: &str = "PUT";
const BLANK_TITLE_PROBLEM: &str = "the task title cannot be empty";
const MINUTES_PER_HOUR: u32 = 60;
const LATEST_MINUTE: u32 = 200;

fn count_task_writes(server: &TestServer) -> usize {
    count_requests_to(server, POST_METHOD, TASKS_PATH)
        + count_requests_to(server, PUT_METHOD, TASKS_PATH)
}

fn update_task(
    device: &TestDevice,
    task_id: &Value,
    place: &WorkPlace,
    sample: &TaskSample,
) -> Result<Value, String> {
    device.run(&json!({
        "command": "update_task",
        "task_id": task_id,
        "task": sample.build_arguments(place),
    }))
}

fn listed_tasks(
    device: &TestDevice,
    place: &WorkPlace,
) -> Result<Vec<Value>, String> {
    let view = list_view(device, "list_tasks", &place.workspace_id)?;
    Ok(list_task_views(&view))
}

#[test]
fn test_prepare_task_upload_property_a_blank_title_reaches_nobody() {
    let cases = (task_sample(), BLANK_PATTERN);
    check_on_workspace(&cases, |prepared, (sample, blank_title)| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let created = create_task_from(device, &place, &sample, START_LATER)
            .map_err(fail)?;
        let writes_before = count_task_writes(&prepared.server);
        let blank_sample = TaskSample {
            title: blank_title,
            ..sample
        };

        let created_problem = read_problem(create_task_from(
            device,
            &place,
            &blank_sample,
            START_LATER,
        ));
        let update_problem = read_problem(update_task(
            device,
            &created["id"],
            &place,
            &blank_sample,
        ));

        prop_assert_eq!(created_problem, BLANK_TITLE_PROBLEM);
        prop_assert_eq!(update_problem, BLANK_TITLE_PROBLEM);
        prop_assert_eq!(count_task_writes(&prepared.server), writes_before);
        let listed = listed_tasks(device, &place).map_err(fail)?;
        prop_assert_eq!(listed.len(), 1);
        prop_assert_eq!(&listed[0]["task"], &created);
        Ok(())
    });
}

#[test]
fn test_prepare_task_upload_property_a_project_elsewhere_is_refused() {
    check_on_workspace(&task_sample(), |prepared, sample| {
        let device = &prepared.device;
        let home = open_work_place(device).map_err(fail)?;
        let elsewhere = open_work_place(device).map_err(fail)?;
        let crossed = WorkPlace {
            workspace_id: home.workspace_id.clone(),
            project_id: elsewhere.project_id.clone(),
        };

        let problem = read_problem(create_task_from(
            device,
            &crossed,
            &sample,
            START_LATER,
        ));

        let expected = format!(
            "project {} is not part of workspace {}",
            elsewhere.project_id, home.workspace_id
        );
        prop_assert_eq!(problem, expected);
        prop_assert!(listed_tasks(device, &home).map_err(fail)?.is_empty());
        prop_assert!(
            listed_tasks(device, &elsewhere).map_err(fail)?.is_empty()
        );
        Ok(())
    });
}

#[test]
fn test_prepare_task_upload_property_an_unknown_project_is_not_found() {
    let cases = (task_sample(), uuid_text_strategy());
    check_on_workspace(&cases, |prepared, (sample, unknown_project)| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let lost = WorkPlace {
            workspace_id: place.workspace_id.clone(),
            project_id: unknown_project.clone(),
        };

        let problem = read_problem(create_task_from(
            device,
            &lost,
            &sample,
            START_LATER,
        ));

        let expected = format!("project {unknown_project} was not found");
        prop_assert_eq!(problem, expected);
        prop_assert!(listed_tasks(device, &place).map_err(fail)?.is_empty());
        Ok(())
    });
}

#[test]
fn test_replace_task_property_update_keeps_id_and_creation_time() {
    let cases = (task_sample(), task_sample());
    check_on_workspace(&cases, |prepared, (first, second)| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let created = create_task_from(device, &place, &first, START_LATER)
            .map_err(fail)?;

        let updated = update_task(device, &created["id"], &place, &second)
            .map_err(fail)?;

        prop_assert_eq!(&updated["id"], &created["id"]);
        prop_assert_eq!(&updated["created_at"], &created["created_at"]);
        prop_assert_eq!(&updated["status"], &created["status"]);
        prop_assert_eq!(&updated["title"], &json!(second.title));
        prop_assert_eq!(&updated["details"], &json!(second.details));
        prop_assert_eq!(&updated["agent_place"], second.agent_place);
        let listed = listed_tasks(device, &place).map_err(fail)?;
        let stored = find_listed_task(&listed, &created["id"]);
        prop_assert_eq!(stored, Some(updated));
        Ok(())
    });
}

#[test]
fn test_replace_task_property_an_unknown_task_is_not_found() {
    let cases = (task_sample(), uuid_text_strategy());
    check_on_workspace(&cases, |prepared, (sample, unknown_task)| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;

        let problem = read_problem(update_task(
            device,
            &json!(unknown_task),
            &place,
            &sample,
        ));

        prop_assert!(problem.starts_with(NOT_FOUND_START), "{}", problem);
        prop_assert!(problem.contains("the task"), "{}", problem);
        prop_assert!(listed_tasks(device, &place).map_err(fail)?.is_empty());
        Ok(())
    });
}

#[test]
fn test_replace_task_property_update_job_checks_the_schedule_first() {
    let cases = (
        task_sample(),
        schedule_sample(),
        MINUTES_PER_HOUR..LATEST_MINUTE,
    );
    check_on_workspace(&cases, |prepared, (sample, schedule, bad_minute)| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let job = device
            .run(&json!({
                "command": "create_job",
                "task": sample.build_arguments(&place),
                "schedule": schedule,
            }))
            .map_err(fail)?;
        let writes_before = count_task_writes(&prepared.server);

        let problem = read_problem(device.run(&json!({
            "command": "update_job",
            "task_id": job["id"],
            "task": sample.build_arguments(&place),
            "schedule": { "every": "hour", "minute": bad_minute },
        })));

        let expected = format!("minute {bad_minute} is not between 0 and 59");
        prop_assert!(problem.contains(&expected), "{}", problem);
        prop_assert_eq!(count_task_writes(&prepared.server), writes_before);
        let jobs = list_view(device, "list_jobs", &place.workspace_id)
            .map_err(fail)?;
        prop_assert_eq!(&jobs[0]["task"], &job);
        Ok(())
    });
}
