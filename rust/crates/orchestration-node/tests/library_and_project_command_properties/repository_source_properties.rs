use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::repository_source_desk::{SourceDesk, open_source_desk};
use crate::support::git_origin::LOCAL_REPOSITORY_ADDRESS;
use crate::support::test_device::fail;

const SOURCE_CASES: u32 = 3;
const LAPTOP_NAME: &str = "air-laptop";
const OTHER_ADDRESS: &str = "local.test/acme/other";
const UUID_TAIL_PATTERN: &str = "[0-9a-f]{8}";

fn uuid_strategy() -> impl Strategy<Value = String> {
    UUID_TAIL_PATTERN
        .prop_map(|tail| format!("00000000-0000-4000-8000-0000{tail}"))
}

fn open_or_panic() -> SourceDesk {
    match open_source_desk() {
        Ok(desk) => desk,
        Err(problem) => panic!("the source desk opens: {problem}"),
    }
}

fn unavailable_without_holders() -> Value {
    json!({ "kind": "unavailable", "holders": [] })
}

#[test]
fn test_require_project_repository_property_an_unknown_project_is_named() {
    let desk = open_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SOURCE_CASES));

    let outcome = runner.run(&uuid_strategy(), |project_id| {
        let refused =
            desk.list_branches(&project_id, LOCAL_REPOSITORY_ADDRESS, None);

        let expected = format!("project {project_id} was not found");
        prop_assert_eq!(refused, Err(expected));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_require_project_repository_property_outside_repositories_refused() {
    let desk = open_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SOURCE_CASES));

    let outcome = runner.run(&"[a-z]{2,8}/[a-z]{2,8}", |path| {
        let address = format!("github.com/{path}");
        let refused = desk.list_branches(&desk.project_id, &address, None);

        let expected =
            format!("the repository {address} is not part of the project");
        prop_assert_eq!(refused, Err(expected));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_require_project_repository_property_a_listed_one_is_looked_up() {
    let desk = open_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SOURCE_CASES));

    let outcome = runner.run(&(1_usize..4), |read_count| {
        for _ in 0..read_count {
            let source = desk
                .list_branches(
                    &desk.project_id,
                    LOCAL_REPOSITORY_ADDRESS,
                    None,
                )
                .map_err(fail)?;
            prop_assert_eq!(source, unavailable_without_holders());
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_open_repository_source_property_a_preference_invents_no_source() {
    let desk = open_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SOURCE_CASES));

    let outcome = runner.run(&uuid_strategy(), |preferred_runner_id| {
        let source = desk
            .list_branches(
                &desk.project_id,
                LOCAL_REPOSITORY_ADDRESS,
                Some(&preferred_runner_id),
            )
            .map_err(fail)?;

        prop_assert_eq!(source, unavailable_without_holders());
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_open_repository_source_property_an_own_copy_lists_its_branches() {
    let mut runner = TestRunner::new(Config::with_cases(SOURCE_CASES));

    let outcome =
        runner.run(&prop::option::of(uuid_strategy()), |preferred| {
            let desk = open_or_panic();
            desk.cache_a_copy(LOCAL_REPOSITORY_ADDRESS).map_err(fail)?;
            let source = desk
                .list_branches(
                    &desk.project_id,
                    LOCAL_REPOSITORY_ADDRESS,
                    preferred.as_deref(),
                )
                .map_err(fail)?;

            prop_assert_eq!(&source["kind"], &json!("available"));
            prop_assert_eq!(&source["branches"], &json!(["main"]));
            prop_assert_eq!(&source["task_branches"], &json!([]));
            Ok(())
        });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_open_repository_source_property_a_forgotten_copy_is_unavailable() {
    let mut runner = TestRunner::new(Config::with_cases(SOURCE_CASES));

    let outcome = runner.run(&(1_usize..3), |round_count| {
        let desk = open_or_panic();
        for _ in 0..round_count {
            desk.cache_a_copy(LOCAL_REPOSITORY_ADDRESS).map_err(fail)?;
            let cached = desk
                .list_branches(
                    &desk.project_id,
                    LOCAL_REPOSITORY_ADDRESS,
                    None,
                )
                .map_err(fail)?;
            desk.forget_the_copy(LOCAL_REPOSITORY_ADDRESS)
                .map_err(fail)?;
            let forgotten = desk
                .list_branches(
                    &desk.project_id,
                    LOCAL_REPOSITORY_ADDRESS,
                    None,
                )
                .map_err(fail)?;

            prop_assert_eq!(&cached["kind"], &json!("available"));
            prop_assert_eq!(forgotten, unavailable_without_holders());
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_find_own_copy_property_the_copy_names_this_device() {
    let mut runner = TestRunner::new(Config::with_cases(SOURCE_CASES));

    let outcome = runner.run(&Just(()), |()| {
        let desk = open_or_panic();
        desk.cache_a_copy(LOCAL_REPOSITORY_ADDRESS).map_err(fail)?;
        let source = desk
            .list_branches(&desk.project_id, LOCAL_REPOSITORY_ADDRESS, None)
            .map_err(fail)?;
        let device_id = desk.read_device_id().map_err(fail)?;

        prop_assert_eq!(&source["runner"]["device_id"], &json!(device_id));
        prop_assert_eq!(&source["runner"]["name"], &json!(LAPTOP_NAME));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_find_own_copy_property_a_copy_of_another_address_does_not_count() {
    let mut runner = TestRunner::new(Config::with_cases(SOURCE_CASES));

    let outcome = runner.run(&Just(()), |()| {
        let desk = open_or_panic();
        desk.cache_a_copy(OTHER_ADDRESS).map_err(fail)?;
        let source = desk
            .list_branches(&desk.project_id, LOCAL_REPOSITORY_ADDRESS, None)
            .map_err(fail)?;

        prop_assert_eq!(source, unavailable_without_holders());
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_find_own_copy_property_a_folder_without_a_record_does_not_count() {
    let mut runner = TestRunner::new(Config::with_cases(SOURCE_CASES));

    let outcome = runner.run(&"[a-z]{3,10}", |stray_name| {
        let desk = open_or_panic();
        let stray = desk.cached_clone(&stray_name);
        std::fs::create_dir_all(stray.join(".git")).map_err(fail)?;
        let source = desk
            .list_branches(&desk.project_id, LOCAL_REPOSITORY_ADDRESS, None)
            .map_err(fail)?;

        prop_assert_eq!(source, unavailable_without_holders());
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_find_runner_device_property_an_unknown_runner_is_named() {
    let desk = open_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(SOURCE_CASES));

    let outcome = runner.run(&"[a-z0-9]{8,20}", |runner_id| {
        let refused = desk.list_files(&runner_id);

        prop_assert_eq!(
            refused,
            Err(format!("runner {runner_id} was not found"))
        );
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_find_runner_device_property_this_device_is_found() {
    let mut runner = TestRunner::new(Config::with_cases(SOURCE_CASES));

    let outcome = runner.run(&Just(()), |()| {
        let desk = open_or_panic();
        desk.cache_a_copy(LOCAL_REPOSITORY_ADDRESS).map_err(fail)?;
        let device_id = desk.read_device_id().map_err(fail)?;
        let listed = desk.list_files(&device_id).map_err(fail)?;

        let entries = listed["entries"].to_string();
        prop_assert!(entries.contains("README.md"), "{}", entries);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_find_runner_device_property_a_revoked_device_is_not_a_runner() {
    let mut runner = TestRunner::new(Config::with_cases(SOURCE_CASES));

    let outcome = runner.run(&Just(()), |()| {
        let desk = open_or_panic();
        let joining =
            crate::support::test_device::TestDevice::start().map_err(fail)?;
        let joined_id = crate::support::pairing_steps::pair_into_workspace(
            &desk.prepared,
            &joining,
        )
        .map_err(fail)?;
        let before = desk.list_files(&joined_id);
        desk.prepared
            .device
            .run(
                &json!({ "command": "revoke_device", "device_id": joined_id }),
            )
            .map_err(fail)?;
        let after = desk.list_files(&joined_id);

        let not_found = format!("runner {joined_id} was not found");
        prop_assert_ne!(before, Err(not_found.clone()));
        prop_assert_eq!(after, Err(not_found));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
