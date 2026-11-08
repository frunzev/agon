use chrono::Utc;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};

use crate::support::command_builders::PROJECT_NAME;
use crate::support::test_device::{TestDevice, fail, read_text};
use crate::task_creation_properties::{list_task_views, list_view};
use crate::task_listing_properties::start_task;
use crate::task_samples::{
    measure_schedule_period, read_moment, schedule_sample,
};
use crate::work_desk::{
    START_LATER, START_NOW, WorkPlace, check_on_workspace, create_task,
    open_work_place, run_on_run, start_one_run, task_command,
};

const MOST_TASKS: usize = 4;
const MOST_RUNS: usize = 3;
const MOST_JOBS: usize = 3;
const NO_TASKS_TEXT: &str = "No tasks yet";
const CANCELLED_START: &str = "cancelled";
const TASK_STARTS: [&str; 3] = [START_LATER, START_NOW, CANCELLED_START];
const SUMMARY_LABELS: [(&str, &str); 4] = [
    ("running", "running"),
    ("waiting_for_approval", "waiting for approval"),
    ("failed", "failed"),
    ("to_do", "to do"),
];

fn create_in_state(
    device: &TestDevice,
    place: &WorkPlace,
    start: &str,
) -> Result<(), String> {
    if start == CANCELLED_START {
        let (_, run_id) = start_one_run(device, place, "work")?;
        run_on_run(device, "cancel_run", &run_id)?;
        return Ok(());
    }
    create_task(device, place, "work", start)?;
    Ok(())
}

fn create_job(
    device: &TestDevice,
    place: &WorkPlace,
    schedule: &Value,
) -> Result<Value, String> {
    let sample_task = task_command(place, "Nightly", "work", START_LATER);
    device.run(&json!({
        "command": "create_job",
        "task": sample_task["task"],
        "schedule": schedule,
    }))
}

fn count_status(views: &[Value], status: &str) -> usize {
    let mut count = 0;
    for view in views {
        if view["task"]["status"] == status {
            count += 1;
        }
    }
    count
}

#[test]
fn test_build_tasks_view_property_summary_counts_the_listed_tasks() {
    let cases = vec(select(TASK_STARTS.to_vec()), 0..=MOST_TASKS);
    check_on_workspace(&cases, |prepared, starts| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        for start in &starts {
            create_in_state(device, &place, start).map_err(fail)?;
        }

        let view = list_view(device, "list_tasks", &place.workspace_id)
            .map_err(fail)?;

        let views = list_task_views(&view);
        prop_assert_eq!(views.len(), starts.len());
        let summary_text = view["summary_text"].as_str().unwrap_or_default();
        for (field, label) in SUMMARY_LABELS {
            let listed_count = count_status(&views, field);
            prop_assert_eq!(&view["summary"][field], &json!(listed_count));
            let part = format!("{listed_count} {label}");
            prop_assert_eq!(
                summary_text.contains(&part),
                listed_count > 0,
                "{}",
                summary_text
            );
        }
        prop_assert_eq!(summary_text == NO_TASKS_TEXT, starts.is_empty());
        Ok(())
    });
}

#[test]
fn test_build_tasks_view_property_latest_run_has_the_highest_number() {
    check_on_workspace(&(0..=MOST_RUNS), |prepared, run_count| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let task_id =
            create_task(device, &place, "work", START_LATER).map_err(fail)?;
        let mut last_run = Value::Null;
        for _ in 0..run_count {
            last_run = start_task(device, &task_id).map_err(fail)?;
            let run_id = read_text(&last_run, "/id").map_err(fail)?;
            run_on_run(device, "cancel_run", &run_id).map_err(fail)?;
        }

        let view = list_view(device, "list_tasks", &place.workspace_id)
            .map_err(fail)?;

        let latest_run = &list_task_views(&view)[0]["latest_run"];
        if run_count == 0 {
            prop_assert_eq!(latest_run, &Value::Null);
        } else {
            prop_assert_eq!(&latest_run["run_id"], &last_run["id"]);
            prop_assert_eq!(&latest_run["number"], &json!(run_count));
            prop_assert_eq!(&latest_run["status"], CANCELLED_START);
        }
        Ok(())
    });
}

#[test]
fn test_build_tasks_view_property_jobs_are_left_out() {
    let cases = (0..=MOST_TASKS, schedule_sample());
    check_on_workspace(&cases, |prepared, (task_count, schedule)| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        create_job(device, &place, &schedule).map_err(fail)?;
        for _ in 0..task_count {
            create_task(device, &place, "work", START_LATER).map_err(fail)?;
        }

        let view = list_view(device, "list_tasks", &place.workspace_id)
            .map_err(fail)?;

        let views = list_task_views(&view);
        prop_assert_eq!(views.len(), task_count);
        prop_assert_eq!(&view["summary"]["to_do"], &json!(task_count));
        for task_view in &views {
            prop_assert_eq!(&task_view["task"]["schedule"], &Value::Null);
        }
        Ok(())
    });
}

#[test]
fn test_build_job_views_property_next_run_falls_within_one_period() {
    check_on_workspace(&schedule_sample(), |prepared, schedule| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        create_job(device, &place, &schedule).map_err(fail)?;
        let before = Utc::now();

        let jobs = list_view(device, "list_jobs", &place.workspace_id)
            .map_err(fail)?;

        let after = Utc::now();
        let next_run_at =
            read_moment(&jobs[0]["next_run_at"]).map_err(fail)?;
        let period = measure_schedule_period(&schedule);
        prop_assert!(
            before < next_run_at,
            "{} not after {}",
            next_run_at,
            before
        );
        prop_assert!(next_run_at <= after + period, "{}", next_run_at);
        Ok(())
    });
}

#[test]
fn test_build_job_views_property_lists_every_job_and_nothing_else() {
    let cases = vec(schedule_sample(), 0..=MOST_JOBS);
    check_on_workspace(&cases, |prepared, schedules| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        create_task(device, &place, "work", START_LATER).map_err(fail)?;
        let mut created_jobs = Vec::new();
        for schedule in &schedules {
            created_jobs
                .push(create_job(device, &place, schedule).map_err(fail)?);
        }

        let jobs = list_view(device, "list_jobs", &place.workspace_id)
            .map_err(fail)?;

        let job_views = jobs.as_array().cloned().unwrap_or_default();
        prop_assert_eq!(job_views.len(), schedules.len());
        for created_job in &created_jobs {
            let listed = job_views
                .iter()
                .find(|job_view| job_view["task"]["id"] == created_job["id"])
                .ok_or_else(|| fail("the job is listed"))?;
            prop_assert_eq!(&listed["task"], created_job);
            prop_assert_eq!(&listed["project_name"], PROJECT_NAME);
            let description = listed["schedule_description"].as_str();
            prop_assert!(description.is_some_and(|text| !text.is_empty()));
        }
        Ok(())
    });
}

#[test]
fn test_build_job_views_property_latest_run_follows_the_job_runs() {
    let cases = (schedule_sample(), 0..=MOST_RUNS);
    check_on_workspace(&cases, |prepared, (schedule, run_count)| {
        let device = &prepared.device;
        let place = open_work_place(device).map_err(fail)?;
        let job = create_job(device, &place, &schedule).map_err(fail)?;
        let job_id = read_text(&job, "/id").map_err(fail)?;
        let mut last_run = Value::Null;
        for _ in 0..run_count {
            last_run = start_task(device, &job_id).map_err(fail)?;
            let run_id = read_text(&last_run, "/id").map_err(fail)?;
            run_on_run(device, "cancel_run", &run_id).map_err(fail)?;
        }

        let jobs = list_view(device, "list_jobs", &place.workspace_id)
            .map_err(fail)?;

        let latest_run = &jobs[0]["latest_run"];
        if run_count == 0 {
            prop_assert_eq!(latest_run, &Value::Null);
        } else {
            prop_assert_eq!(&latest_run["run_id"], &last_run["id"]);
            prop_assert_eq!(&latest_run["number"], &json!(run_count));
        }
        Ok(())
    });
}
