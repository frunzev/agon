use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::library_desk::FOREIGN_WORKSPACE_ID;
use crate::project_desk::{
    PROJECT_CASES, create_project, find_project_view, list_projects,
    list_repositories, repository_strategy,
};
use crate::support::command_builders::create_task_command;
use crate::support::folder_checks::prepared_or_panic;
use crate::support::runner_access::{
    claim_next_assignment, open_runner, started_task_command, test_runtime,
};
use crate::support::test_device::fail;

const MOST_PROJECTS: usize = 3;
const MOST_TASKS: usize = 3;
const MOST_CLAIMS: usize = 2;
const PROJECT_NAME_START: &str = "project-";
const UNKNOWN_PROJECT_ID: &str = "00000000-0000-4000-8000-00000000dead";

fn project_name(index: usize) -> String {
    format!("{PROJECT_NAME_START}{index}")
}

#[test]
fn test_build_project_views_property_counts_each_projects_tasks() {
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));
    let task_counts = vec(0..=MOST_TASKS, 1..=MOST_PROJECTS);

    let outcome = runner.run(&task_counts, |task_counts| {
        let prepared = prepared_or_panic();
        let mut project_ids = Vec::new();
        for (index, task_count) in task_counts.iter().enumerate() {
            let created = create_project(&prepared, &project_name(index), &[])
                .map_err(fail)?;
            let project_id = created["id"].as_str().unwrap_or_default();
            for _ in 0..*task_count {
                let command = create_task_command(
                    &prepared.workspace_id,
                    project_id,
                    "Count me",
                );
                prepared.device.run(&command).map_err(fail)?;
            }
            project_ids.push(created["id"].clone());
        }
        let views =
            list_projects(&prepared, &prepared.workspace_id).map_err(fail)?;

        for (index, project_id) in project_ids.iter().enumerate() {
            let view = find_project_view(&views, project_id);
            let view = view.unwrap_or(Value::Null);
            prop_assert_eq!(&view["task_count"], &json!(task_counts[index]));
            prop_assert_eq!(&view["running_task_count"], &json!(0));
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_build_project_views_property_counts_started_tasks_as_running() {
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));
    let drawn = (1..=MOST_CLAIMS, 0..=MOST_TASKS, 0..=MOST_CLAIMS);

    let outcome = runner.run(&drawn, |drawn_counts| {
        let (started_count, later_count, claimed_count) = drawn_counts;
        let prepared = prepared_or_panic();
        for _ in 0..started_count {
            let command = started_task_command(&prepared, "Run me");
            prepared.device.run(&command).map_err(fail)?;
        }
        for _ in 0..later_count {
            let command = create_task_command(
                &prepared.workspace_id,
                &prepared.project_id,
                "Later",
            );
            prepared.device.run(&command).map_err(fail)?;
        }
        let runtime = test_runtime().map_err(fail)?;
        let runner_server = open_runner(&prepared).map_err(fail)?;
        for _ in 0..claimed_count.min(started_count) {
            claim_next_assignment(&runner_server, &runtime).map_err(fail)?;
        }
        let views =
            list_projects(&prepared, &prepared.workspace_id).map_err(fail)?;

        let project_id = json!(prepared.project_id);
        let view = find_project_view(&views, &project_id);
        let view = view.unwrap_or(Value::Null);
        let total_count = started_count + later_count;
        prop_assert_eq!(&view["task_count"], &json!(total_count));
        prop_assert_eq!(&view["running_task_count"], &json!(started_count));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_build_project_views_property_lists_only_the_asked_workspace() {
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));

    let outcome = runner.run(&(0..=MOST_PROJECTS), |extra_count| {
        let prepared = prepared_or_panic();
        let mut project_ids = vec![json!(prepared.project_id)];
        for index in 0..extra_count {
            let created = create_project(&prepared, &project_name(index), &[])
                .map_err(fail)?;
            project_ids.push(created["id"].clone());
        }
        let own_views =
            list_projects(&prepared, &prepared.workspace_id).map_err(fail)?;
        let foreign_views =
            list_projects(&prepared, FOREIGN_WORKSPACE_ID).map_err(fail)?;

        prop_assert!(foreign_views.is_empty(), "{:?}", foreign_views);
        prop_assert_eq!(own_views.len(), project_ids.len());
        for view in &own_views {
            let workspace_id = &view["project"]["workspace_id"];
            prop_assert_eq!(workspace_id, &json!(prepared.workspace_id));
            prop_assert!(project_ids.contains(&view["project"]["id"]));
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_find_project_property_an_unknown_project_is_not_found() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));
    let project_id = "[0-9a-f]{8}"
        .prop_map(|tail| format!("00000000-0000-4000-8000-0000{tail}"));

    let outcome = runner.run(&project_id, |project_id| {
        let refused = list_repositories(&prepared, &json!(project_id));

        let expected = format!("project {project_id} was not found");
        prop_assert_eq!(refused, Err(expected));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_find_project_property_each_project_gives_its_own_repositories() {
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));
    let projects = vec(repository_strategy(), 1..=MOST_PROJECTS);

    let outcome = runner.run(&projects, |drawn_repositories| {
        let prepared = prepared_or_panic();
        let mut created_projects = Vec::new();
        for (index, repository) in drawn_repositories.iter().enumerate() {
            let input = repository.input("main");
            let created =
                create_project(&prepared, &project_name(index), &[input])
                    .map_err(fail)?;
            created_projects.push(created);
        }

        for created in &created_projects {
            let repositories =
                list_repositories(&prepared, &created["id"]).map_err(fail)?;
            prop_assert_eq!(&repositories, &created["repositories"]);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_find_project_property_agrees_with_the_project_list() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));

    let outcome = runner.run(&repository_strategy(), |repository| {
        create_project(&prepared, "listed", &[repository.input("main")])
            .map_err(fail)?;
        let views =
            list_projects(&prepared, &prepared.workspace_id).map_err(fail)?;

        for view in &views {
            let project = &view["project"];
            let repositories =
                list_repositories(&prepared, &project["id"]).map_err(fail)?;
            prop_assert_eq!(&repositories, &project["repositories"]);
        }
        let unknown = list_repositories(&prepared, &json!(UNKNOWN_PROJECT_ID));
        prop_assert!(unknown.is_err(), "{:?}", unknown);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
