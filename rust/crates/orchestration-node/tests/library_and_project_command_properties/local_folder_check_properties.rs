use std::fs;

use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::json;

use crate::folder_desk::{
    FOLDER_CASES, branch_strategy, create_folder_project,
    create_temporary_folder, folder_name_strategy, render_local_address,
};
use crate::project_desk::{repository_strategy, spelling_strategy};
use crate::support::folder_checks::{check_folder, prepared_or_panic};
use crate::support::git_folders::{GIT_FOLDER_NAME, create_named_git_folder};
use crate::support::git_origin::run_git;
use crate::support::item_drafting_desk::read_device_id;
use crate::support::test_device::fail;

const OTHER_DEVICE_ID: &str = "another-device-0001";
const ANOTHER_COMPUTER_END: &str = "is on another computer, so add it there";
const FILE_TEXT: &str = "not a folder";
const PADDINGS: [&str; 3] = ["", "/", " "];

fn describe_missing(path: &str) -> String {
    format!("the folder {path} does not exist or this app cannot open it")
}

#[test]
fn test_read_checked_out_branch_property_names_the_checked_out_branch() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));
    let drawn = (folder_name_strategy(), branch_strategy());

    let outcome = runner.run(&drawn, |(folder_name, branch)| {
        let root = create_temporary_folder().map_err(fail)?;
        let checkout =
            create_named_git_folder(root.path(), &folder_name, &branch)
                .map_err(fail)?;
        let checkout_text = checkout.display().to_string();
        let checked = check_folder(&prepared, &checkout_text).map_err(fail)?;

        prop_assert_eq!(&checked["default_branch"], &json!(branch));
        prop_assert_eq!(&checked["has_started_git"], &json!(false));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_read_checked_out_branch_property_follows_a_branch_switch() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));
    let drawn = (branch_strategy(), branch_strategy());

    let outcome = runner.run(&drawn, |(first_branch, second_branch)| {
        prop_assume!(first_branch != second_branch);
        let root = create_temporary_folder().map_err(fail)?;
        let checkout =
            create_named_git_folder(root.path(), "app", &first_branch)
                .map_err(fail)?;
        let checkout_text = checkout.display().to_string();
        let before = check_folder(&prepared, &checkout_text).map_err(fail)?;
        run_git(&checkout, &["checkout", "--quiet", "-b", &second_branch])
            .map_err(fail)?;
        let after = check_folder(&prepared, &checkout_text).map_err(fail)?;

        prop_assert_eq!(&before["default_branch"], &json!(first_branch));
        prop_assert_eq!(&after["default_branch"], &json!(second_branch));
        prop_assert_eq!(&before["address"], &after["address"]);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_require_folder_property_a_missing_folder_is_named() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));

    let outcome = runner.run(&folder_name_strategy(), |folder_name| {
        let root = create_temporary_folder().map_err(fail)?;
        let missing = root.path().join(&folder_name).join("inside");
        let missing_text = missing.display().to_string();
        let refused = check_folder(&prepared, &missing_text);

        prop_assert_eq!(refused, Err(describe_missing(&missing_text)));
        prop_assert!(!missing.exists());
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_require_folder_property_a_file_is_not_a_folder() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));

    let outcome = runner.run(&folder_name_strategy(), |file_name| {
        let root = create_temporary_folder().map_err(fail)?;
        let file = root.path().join(&file_name);
        fs::write(&file, FILE_TEXT).map_err(fail)?;
        let file_text = file.display().to_string();
        let refused = check_folder(&prepared, &file_text);

        prop_assert_eq!(refused, Err(describe_missing(&file_text)));
        prop_assert_eq!(
            fs::read_to_string(&file).ok(),
            Some(FILE_TEXT.into())
        );
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_require_folder_property_a_new_folder_needs_its_parent() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));
    let drawn = (folder_name_strategy(), folder_name_strategy());

    let outcome = runner.run(&drawn, |(parent_name, folder_name)| {
        let root = create_temporary_folder().map_err(fail)?;
        let parent = root.path().join(&parent_name);
        let parent_text = parent.display().to_string();
        let refused = prepared.device.run(&json!({
            "command": "create_local_folder",
            "parent": parent_text,
            "name": folder_name,
        }));

        prop_assert_eq!(refused, Err(describe_missing(&parent_text)));
        prop_assert!(!parent.exists());
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_require_git_checkout_property_a_folder_without_git_is_refused() {
    let prepared = prepared_or_panic();
    let device_id = read_device_id(&prepared.device).unwrap_or_default();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));

    let outcome = runner.run(&folder_name_strategy(), |folder_name| {
        let root = create_temporary_folder().map_err(fail)?;
        let checkout =
            create_named_git_folder(root.path(), &folder_name, "main")
                .map_err(fail)?;
        fs::remove_dir_all(checkout.join(GIT_FOLDER_NAME)).map_err(fail)?;
        let address = render_local_address(&device_id, &checkout);
        let refused = create_folder_project(&prepared, &address);
        let gone = root.path().join(format!("{folder_name}-gone"));
        let gone_address = render_local_address(&device_id, &gone);
        let gone_refusal = create_folder_project(&prepared, &gone_address);

        let checkout_text = checkout.display();
        let expected =
            format!("the folder {checkout_text} is not a git repository");
        prop_assert_eq!(refused, Err(expected));
        let gone_text = gone.display().to_string();
        prop_assert_eq!(gone_refusal, Err(describe_missing(&gone_text)));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_require_folder_on_this_device_property_other_devices_are_refused() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));

    let outcome = runner.run(&folder_name_strategy(), |folder_name| {
        let root = create_temporary_folder().map_err(fail)?;
        let checkout =
            create_named_git_folder(root.path(), &folder_name, "main")
                .map_err(fail)?;
        let address = render_local_address(OTHER_DEVICE_ID, &checkout);
        let refused = create_folder_project(&prepared, &address);

        let checkout_text = checkout.display();
        let expected =
            format!("the folder {checkout_text} {ANOTHER_COMPUTER_END}");
        prop_assert_eq!(refused, Err(expected));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_require_folder_on_this_device_property_remote_addresses_skip_checks() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));
    let drawn = (repository_strategy(), spelling_strategy());

    let outcome = runner.run(&drawn, |(repository, spelling)| {
        let address = spelling.replace("{path}", &repository.path);
        let created =
            create_folder_project(&prepared, &address).map_err(fail)?;

        let saved_address = &created["repositories"][0]["address"];
        prop_assert_eq!(saved_address, &json!(repository.canonical_address()));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_require_folder_on_this_device_property_own_folders_keep_one_address() {
    let prepared = prepared_or_panic();
    let device_id = read_device_id(&prepared.device).unwrap_or_default();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));
    let padding = proptest::sample::select(PADDINGS.to_vec());

    let outcome = runner.run(&(folder_name_strategy(), padding), |drawn| {
        let (folder_name, padding) = drawn;
        let root = create_temporary_folder().map_err(fail)?;
        let checkout =
            create_named_git_folder(root.path(), &folder_name, "main")
                .map_err(fail)?;
        let address = render_local_address(&device_id, &checkout);
        let padded_address = format!("{address}{padding}");
        let created =
            create_folder_project(&prepared, &padded_address).map_err(fail)?;

        let saved_address = &created["repositories"][0]["address"];
        prop_assert_eq!(saved_address, &json!(address));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
