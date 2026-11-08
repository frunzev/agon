use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::library_desk::valid_name_strategy;
use crate::project_desk::{
    PROJECT_CASES, add_repository, create_project, find_project_view,
    list_projects, list_repositories, remove_repository, repository_strategy,
    spelling_strategy,
};
use crate::support::folder_checks::prepared_or_panic;
use crate::support::test_device::fail;

const MOST_REPOSITORIES: usize = 3;
const DEFAULT_BRANCH: &str = "main";
const INVALID_PROJECT_NAMES: [&str; 4] = ["", "Billing", "my app", "app_2"];

fn canonical_addresses(repositories: &Value) -> Vec<Value> {
    let listed = repositories.as_array().cloned().unwrap_or_default();
    let mut addresses = Vec::new();
    for repository in listed {
        addresses.push(repository["address"].clone());
    }
    addresses
}

#[test]
fn test_handle_project_command_property_a_created_project_is_listed() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));
    let drawn = (
        valid_name_strategy(),
        vec(repository_strategy(), 0..=MOST_REPOSITORIES),
    );

    let outcome = runner.run(&drawn, |(name, drawn_repositories)| {
        let mut inputs = Vec::new();
        let mut expected_addresses = Vec::new();
        for repository in &drawn_repositories {
            let address = json!(repository.canonical_address());
            if expected_addresses.contains(&address) {
                continue;
            }
            inputs.push(repository.input(DEFAULT_BRANCH));
            expected_addresses.push(address);
        }
        let created =
            create_project(&prepared, &name, &inputs).map_err(fail)?;
        let views =
            list_projects(&prepared, &prepared.workspace_id).map_err(fail)?;
        let repositories =
            list_repositories(&prepared, &created["id"]).map_err(fail)?;

        let view = find_project_view(&views, &created["id"]);
        let listed_project = view.map(|view| view["project"].clone());
        prop_assert_eq!(listed_project, Some(created.clone()));
        prop_assert_eq!(&created["name"], &json!(name));
        prop_assert_eq!(&repositories, &created["repositories"]);
        prop_assert_eq!(
            canonical_addresses(&repositories),
            expected_addresses
        );
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_handle_project_command_property_adding_then_removing_restores() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));
    let drawn = (repository_strategy(), spelling_strategy());

    let outcome = runner.run(&drawn, |(repository, removal_spelling)| {
        let created = create_project(&prepared, "kept", &[]).map_err(fail)?;
        let project_id = created["id"].clone();
        let before =
            list_repositories(&prepared, &project_id).map_err(fail)?;
        let added = add_repository(
            &prepared,
            &project_id,
            &repository.input(DEFAULT_BRANCH),
        )
        .map_err(fail)?;
        let between =
            list_repositories(&prepared, &project_id).map_err(fail)?;
        let removal_address =
            removal_spelling.replace("{path}", &repository.path);
        let removed =
            remove_repository(&prepared, &project_id, &removal_address)
                .map_err(fail)?;
        let after = list_repositories(&prepared, &project_id).map_err(fail)?;

        prop_assert_eq!(
            &added["address"],
            &json!(repository.canonical_address())
        );
        prop_assert_eq!(&between, &json!([added]));
        prop_assert_eq!(&removed, &before);
        prop_assert_eq!(&after, &before);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_handle_project_command_property_invalid_names_save_nothing() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));
    let invalid_name =
        proptest::sample::select(INVALID_PROJECT_NAMES.to_vec());

    let outcome = runner.run(&invalid_name, |name| {
        let before =
            list_projects(&prepared, &prepared.workspace_id).map_err(fail)?;
        let refused = create_project(&prepared, name, &[]);
        let after =
            list_projects(&prepared, &prepared.workspace_id).map_err(fail)?;

        prop_assert!(refused.is_err(), "{:?}", refused);
        prop_assert_eq!(after, before);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_check_repository_property_the_default_branch_is_trimmed() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));
    let drawn = (repository_strategy(), "[ \t]{0,3}", "[a-z][a-z0-9/-]{0,12}");

    let outcome = runner.run(&drawn, |(repository, padding, branch)| {
        let created = create_project(&prepared, "trim", &[]).map_err(fail)?;
        let padded_branch = format!("{padding}{branch}{padding}");
        let added = add_repository(
            &prepared,
            &created["id"],
            &repository.input(&padded_branch),
        )
        .map_err(fail)?;
        let listed =
            list_repositories(&prepared, &created["id"]).map_err(fail)?;

        prop_assert_eq!(&added["default_branch"], &json!(branch));
        prop_assert_eq!(
            &added["agent_access"],
            &json!(repository.agent_access)
        );
        prop_assert_eq!(&listed, &json!([added]));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_check_repository_property_a_blank_default_branch_saves_nothing() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));
    let drawn = (repository_strategy(), "[ \t\n]{0,4}", any::<bool>());

    let outcome = runner.run(&drawn, |(repository, blank_branch, is_new)| {
        let created = create_project(&prepared, "blank", &[]).map_err(fail)?;
        let input = repository.input(&blank_branch);
        let refused = if is_new {
            create_project(&prepared, "blank", &[input])
        } else {
            add_repository(&prepared, &created["id"], &input)
        };
        let listed =
            list_repositories(&prepared, &created["id"]).map_err(fail)?;

        let expected = "the default branch cannot be empty".to_owned();
        prop_assert_eq!(refused, Err(expected));
        prop_assert_eq!(listed, json!([]));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_check_repository_property_every_spelling_names_one_repository() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PROJECT_CASES));
    let drawn = (repository_strategy(), spelling_strategy());

    let outcome = runner.run(&drawn, |(repository, second_spelling)| {
        let created = create_project(&prepared, "twice", &[]).map_err(fail)?;
        add_repository(&prepared, &created["id"], &repository.input("main"))
            .map_err(fail)?;
        let mut second = repository.input("main");
        second["address"] =
            json!(second_spelling.replace("{path}", &repository.path));
        let duplicate = add_repository(&prepared, &created["id"], &second);
        let listed =
            list_repositories(&prepared, &created["id"]).map_err(fail)?;

        let canonical = repository.canonical_address();
        let expected = format!("the project already has {canonical}");
        let message = duplicate.err().unwrap_or_default();
        prop_assert!(message.contains(&expected), "{}", message);
        prop_assert_eq!(canonical_addresses(&listed), vec![json!(canonical)]);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
