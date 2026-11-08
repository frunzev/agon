use std::fs;

use proptest::prelude::*;

use crate::git_desk::{
    GIT_CASES, GIT_FOLDER_NAME, check_chosen_folder, folder_files_strategy,
    folder_name_strategy, guard_committed, guard_unborn,
    read_repository_state, write_files,
};
use crate::support::git_origin::run_git;
use crate::support::test_device::fail;

const SOURCE_FOLDER_NAME: &str = "source";
const LINKED_BRANCH: &str = "linked";
const BROKEN_GIT_FILE_TEXT: &str = "gitdir: nowhere-at-all\n";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CASES))]

    #[test]
    fn test_has_own_repository_property_an_empty_git_folder_becomes_one(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let guarded = guard_unborn(&name)?;
        write_files(&guarded.chosen, &files).map_err(fail)?;
        fs::create_dir_all(guarded.chosen.join(GIT_FOLDER_NAME))
            .map_err(fail)?;
        let guard_before = read_repository_state(&guarded.guard);

        let checked = check_chosen_folder(&guarded.chosen);

        prop_assert!(checked.is_ok(), "{:?}", checked);
        let prefix = run_git(&guarded.chosen, &["rev-parse", "--show-prefix"])
            .map_err(fail)?;
        prop_assert_eq!(prefix, "");
        let chosen_state = read_repository_state(&guarded.chosen);
        prop_assert_eq!(chosen_state.commit_count, "1");
        prop_assert_eq!(read_repository_state(&guarded.guard), guard_before);
    }

    #[test]
    fn test_has_own_repository_property_a_linked_checkout_stays_linked(
        name in folder_name_strategy(),
    ) {
        let guarded = guard_committed(&name)?;
        let source = guarded.guard.join(SOURCE_FOLDER_NAME);
        fs::create_dir_all(&source).map_err(fail)?;
        run_git(&source, &["init", "--quiet", "--initial-branch=main"])
            .map_err(fail)?;
        run_git(&source, &["commit", "--quiet", "--allow-empty", "-m", "a"])
            .map_err(fail)?;
        let chosen_text = guarded.chosen.display().to_string();
        run_git(
            &source,
            &["worktree", "add", "--quiet", "-b", LINKED_BRANCH, &chosen_text],
        )
        .map_err(fail)?;
        let link_path = guarded.chosen.join(GIT_FOLDER_NAME);
        let link_before = fs::read_to_string(&link_path).map_err(fail)?;
        let source_before = read_repository_state(&source);

        let _checked = check_chosen_folder(&guarded.chosen);

        prop_assert!(link_path.is_file());
        let link_after = fs::read_to_string(&link_path).map_err(fail)?;
        prop_assert_eq!(link_after, link_before);
        prop_assert_eq!(read_repository_state(&source), source_before);
    }

    #[test]
    fn test_has_own_repository_property_a_broken_link_is_not_replaced(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let guarded = guard_committed(&name)?;
        write_files(&guarded.chosen, &files).map_err(fail)?;
        let link_path = guarded.chosen.join(GIT_FOLDER_NAME);
        fs::write(&link_path, BROKEN_GIT_FILE_TEXT).map_err(fail)?;

        let checked = check_chosen_folder(&guarded.chosen);

        prop_assert!(checked.is_err(), "{:?}", checked);
        prop_assert!(link_path.is_file());
        let link_after = fs::read_to_string(&link_path).map_err(fail)?;
        prop_assert_eq!(link_after, BROKEN_GIT_FILE_TEXT);
    }
}
