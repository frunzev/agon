use std::fs;

use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::json;

use crate::folder_desk::{
    FOLDER_CASES, branch_strategy, create_folder_project,
    create_linked_worktree, folder_name_strategy, render_local_address,
};
use crate::support::folder_checks::{check_folder, prepared_or_panic};
use crate::support::git_origin::run_git;
use crate::support::item_drafting_desk::read_device_id;
use crate::support::test_device::fail;

const GIT_FILE_NAME: &str = ".git";
const MISSING_GIT_DIRECTORY: &str = "gitdir: /missing/worktrees/gone\n";

#[test]
fn test_read_checked_out_branch_property_a_linked_worktree_names_its_branch() {
    let prepared = prepared_or_panic();
    let device_id = read_device_id(&prepared.device).unwrap_or_default();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));

    let outcome = runner.run(&branch_strategy(), |branch| {
        let linked = create_linked_worktree(&branch).map_err(fail)?;
        let worktree_text = linked.worktree.display().to_string();
        let checked = check_folder(&prepared, &worktree_text).map_err(fail)?;
        let detached = run_git(&linked.worktree, &["checkout", "--detach"]);
        let after_detaching = check_folder(&prepared, &worktree_text);

        let address = render_local_address(&device_id, &linked.worktree);
        prop_assert_eq!(&checked["default_branch"], &json!(branch));
        prop_assert_eq!(&checked["has_started_git"], &json!(false));
        prop_assert_eq!(&checked["address"], &json!(address));
        prop_assert!(detached.is_ok(), "{:?}", detached);
        let expected =
            format!("the folder {worktree_text} has no branch checked out");
        prop_assert_eq!(after_detaching, Err(expected));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_require_git_checkout_property_a_linked_worktree_joins_a_project() {
    let prepared = prepared_or_panic();
    let device_id = read_device_id(&prepared.device).unwrap_or_default();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));

    let outcome = runner.run(&branch_strategy(), |branch| {
        let linked = create_linked_worktree(&branch).map_err(fail)?;
        let address = render_local_address(&device_id, &linked.worktree);
        let main_address =
            render_local_address(&device_id, &linked.main_checkout);
        let created = create_folder_project(&prepared, &address);
        let main_created = create_folder_project(&prepared, &main_address);

        let created = created.map_err(fail)?;
        let saved_address = &created["repositories"][0]["address"];
        prop_assert_eq!(saved_address, &json!(address));
        prop_assert!(main_created.is_ok(), "{:?}", main_created);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_require_git_checkout_property_git_never_leaves_the_chosen_folder() {
    let prepared = prepared_or_panic();
    let device_id = read_device_id(&prepared.device).unwrap_or_default();
    let mut runner = TestRunner::new(Config::with_cases(FOLDER_CASES));
    let drawn = (branch_strategy(), folder_name_strategy());

    let outcome = runner.run(&drawn, |(branch, folder_name)| {
        let linked = create_linked_worktree(&branch).map_err(fail)?;
        let nested = linked.worktree.join(&folder_name);
        fs::create_dir_all(&nested).map_err(fail)?;
        let broken = linked.root.path().join(format!("broken-{folder_name}"));
        fs::create_dir_all(&broken).map_err(fail)?;
        fs::write(broken.join(GIT_FILE_NAME), MISSING_GIT_DIRECTORY)
            .map_err(fail)?;
        let nested_address = render_local_address(&device_id, &nested);
        let broken_address = render_local_address(&device_id, &broken);

        let nested_refusal = create_folder_project(&prepared, &nested_address);
        let broken_refusal = create_folder_project(&prepared, &broken_address);

        let nested_text = nested.display();
        let broken_text = broken.display();
        prop_assert_eq!(
            nested_refusal,
            Err(format!("the folder {nested_text} is not a git repository"))
        );
        prop_assert_eq!(
            broken_refusal,
            Err(format!("the folder {broken_text} is not a git repository"))
        );
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
