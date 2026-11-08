use std::collections::BTreeSet;

use chrono::Utc;
use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};

use crate::support::test_device::{TestDevice, fail, read_text};
use crate::task_samples::{
    TaskSample, read_moment, schedule_sample, task_sample,
};
use crate::work_desk::{
    START_LATER, START_NOW, WorkPlace, check_on_workspace, list_task_runs,
    open_work_place,
};

const MOST_COPIES: usize = 4;
const STARTS: [&str; 2] = [START_LATER, START_NOW];

pub fn create_task_from(
    device: &TestDevice,
    place: &WorkPlace,
    sample: &TaskSample,
    start: &str,
) -> Result<Value, String> {
    device.run(&json!({
        "command": "create_task",
        "task": sample.build_arguments(place),
        "start": start,
    }))
}

pub fn list_view(
    device: &TestDevice,
    command_name: &str,
    workspace_id: &str,
) -> Result<Value, String> {
    device.run(&json!({
        "command": command_name,
        "workspace_id": workspace_id,
    }))
}

pub fn list_task_views(view: &Value) -> Vec<Value> {
    view["tasks"].as_array().cloned().unwrap_or_default()
}

pub fn find_listed_task(views: &[Value], task_id: &Value) -> Option<Value> {
    views
        .iter()
        .find(|view| &view["task"]["id"] == task_id)
        .map(|view| view["task"].clone())
}

#[test]
fn test_build_task_property_create_task_keeps_every_argument() {
    check_on_workspace(&task_sample(), |prepared, sample| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let before = Utc::now();

        let created = create_task_from(device, &place, &sample, START_LATER)
            .map_err(fail)?;

        let after = Utc::now();
        prop_assert_eq!(&created["title"], &json!(sample.title));
        prop_assert_eq!(&created["details"], &json!(sample.details));
        prop_assert_eq!(&created["project_id"], &json!(place.project_id));
        prop_assert_eq!(&created["doer"]["agent"], sample.agent);
        prop_assert_eq!(&created["agent_place"], sample.agent_place);
        prop_assert_eq!(
            &created["uses_automatic_skills"],
            sample.uses_automatic_skills
        );
        prop_assert_eq!(
            &created["approval_policy"],
            &json!(sample.approval_policy)
        );
        prop_assert_eq!(&created["schedule"], &Value::Null);
        prop_assert_eq!(&created["status"], "to_do");
        let created_at = read_moment(&created["created_at"]).map_err(fail)?;
        prop_assert!(before <= created_at && created_at <= after);
        Ok(())
    });
}

#[test]
fn test_build_task_property_every_creation_gets_a_fresh_id() {
    let cases = (task_sample(), 2..=MOST_COPIES);
    check_on_workspace(&cases, |prepared, (sample, copies)| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;

        let mut created_ids = BTreeSet::new();
        for _ in 0..copies {
            let created =
                create_task_from(device, &place, &sample, START_LATER)
                    .map_err(fail)?;
            created_ids.insert(read_text(&created, "/id").map_err(fail)?);
        }

        prop_assert_eq!(created_ids.len(), copies);
        let view = list_view(device, "list_tasks", &place.workspace_id)
            .map_err(fail)?;
        let listed = list_task_views(&view);
        prop_assert_eq!(listed.len(), copies);
        Ok(())
    });
}

#[test]
fn test_build_task_property_a_job_keeps_its_schedule() {
    let cases = (task_sample(), schedule_sample());
    check_on_workspace(&cases, |prepared, (sample, schedule)| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;

        let created = device
            .run(&json!({
                "command": "create_job",
                "task": sample.build_arguments(&place),
                "schedule": schedule,
            }))
            .map_err(fail)?;

        prop_assert_eq!(&created["schedule"], &schedule);
        prop_assert_eq!(&created["status"], "to_do");
        let jobs = list_view(device, "list_jobs", &place.workspace_id)
            .map_err(fail)?;
        let job_list = jobs.as_array().cloned().unwrap_or_default();
        prop_assert_eq!(job_list.len(), 1);
        prop_assert_eq!(&job_list[0]["task"], &created);
        let tasks = list_view(device, "list_tasks", &place.workspace_id)
            .map_err(fail)?;
        prop_assert!(list_task_views(&tasks).is_empty());
        let task_id = read_text(&created, "/id").map_err(fail)?;
        let runs = list_task_runs(device, &task_id).map_err(fail)?;
        prop_assert!(runs.is_empty(), "{:?}", runs);
        Ok(())
    });
}

#[test]
fn test_queue_task_property_start_now_opens_exactly_one_run() {
    let cases = (task_sample(), select(STARTS.to_vec()));
    check_on_workspace(&cases, |prepared, (sample, start)| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;

        let created =
            create_task_from(device, &place, &sample, start).map_err(fail)?;

        let task_id = read_text(&created, "/id").map_err(fail)?;
        let runs = list_task_runs(device, &task_id).map_err(fail)?;
        let expected_run_count = usize::from(start == START_NOW);
        prop_assert_eq!(runs.len(), expected_run_count);
        for run in &runs {
            prop_assert_eq!(&run["number"], &json!(1));
            prop_assert_eq!(&run["task_id"], &json!(task_id));
        }
        Ok(())
    });
}

#[test]
fn test_queue_task_property_the_reply_agrees_with_the_stored_task() {
    let cases = (task_sample(), select(STARTS.to_vec()));
    check_on_workspace(&cases, |prepared, (sample, start)| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;

        let created =
            create_task_from(device, &place, &sample, start).map_err(fail)?;

        let view = list_view(device, "list_tasks", &place.workspace_id)
            .map_err(fail)?;
        let listed = find_listed_task(&list_task_views(&view), &created["id"]);
        prop_assert_eq!(listed, Some(created));
        Ok(())
    });
}

#[test]
fn test_queue_task_property_the_server_only_sees_sealed_details() {
    let cases = (task_sample(), "[a-z]{18,24}");
    check_on_workspace(&cases, |prepared, (sample, secret_details)| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let sealed_sample = TaskSample {
            details: secret_details.clone(),
            ..sample
        };

        let created =
            create_task_from(device, &place, &sealed_sample, START_NOW)
                .map_err(fail)?;

        let stored = prepared.server.read_stored_state().map_err(fail)?;
        prop_assert!(!stored.contains(&secret_details));
        let view = list_view(device, "list_tasks", &place.workspace_id)
            .map_err(fail)?;
        let listed = find_listed_task(&list_task_views(&view), &created["id"])
            .ok_or_else(|| fail("the task is listed"))?;
        prop_assert_eq!(&listed["details"], &json!(secret_details));
        Ok(())
    });
}
