use std::fs;
use std::path::Path;

use proptest::prelude::*;

use crate::git_desk::{
    FolderFiles, GIT_CASES, GIT_FOLDER_NAME, GuardHistory, STARTED_BRANCH,
    check_chosen_folder, folder_files_strategy, folder_name_strategy,
    guard_committed, guard_unborn, list_committed_files,
    prepare_guarded_folder, read_guard_file, read_repository_state,
    read_started_flag, write_files,
};
use crate::support::git_origin::run_git;
use crate::support::test_device::{describe, fail};

const BRANCH_PATTERN: &str = "[a-z][a-z0-9-]{0,8}[a-z0-9]";
const MOST_COMMITS: usize = 3;
const HEAD_FILE_NAME: &str = "HEAD";

#[derive(Clone, Copy, Debug)]
enum ChosenStart {
    Plain,
    EmptyGitFolder,
    Unborn,
    Committed,
}

fn guard_history_strategy() -> impl Strategy<Value = GuardHistory> {
    prop_oneof![Just(GuardHistory::Committed), Just(GuardHistory::Unborn)]
}

fn shape_chosen_folder(
    folder: &Path,
    start: ChosenStart,
    files: &FolderFiles,
) -> Result<(), String> {
    write_files(folder, files)?;
    match start {
        ChosenStart::Plain => Ok(()),
        ChosenStart::EmptyGitFolder => {
            fs::create_dir_all(folder.join(GIT_FOLDER_NAME)).map_err(describe)
        }
        ChosenStart::Unborn => {
            run_git(folder, &["init", "--quiet", "--initial-branch=draft"])
                .map(|_| ())
        }
        ChosenStart::Committed => {
            run_git(folder, &["init", "--quiet", "--initial-branch=draft"])?;
            run_git(folder, &["commit", "--quiet", "--allow-empty", "-m", "a"])
                .map(|_| ())
        }
    }
}

fn add_commits(folder: &Path, count: usize) -> Result<(), String> {
    for number in 0..count {
        let message = format!("commit {number}");
        run_git(
            folder,
            &["commit", "--quiet", "--allow-empty", "-m", &message],
        )?;
    }
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(GIT_CASES))]

    #[test]
    fn test_start_git_when_missing_property_a_second_check_changes_nothing(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let guarded = guard_committed(&name)?;
        write_files(&guarded.chosen, &files).map_err(fail)?;

        let first = check_chosen_folder(&guarded.chosen).map_err(fail)?;
        let state_after_first = read_repository_state(&guarded.chosen);
        let second = check_chosen_folder(&guarded.chosen).map_err(fail)?;

        prop_assert_eq!(read_started_flag(&first), Some(true));
        prop_assert_eq!(read_started_flag(&second), Some(false));
        let state_after_second = read_repository_state(&guarded.chosen);
        prop_assert_eq!(state_after_second, state_after_first);
    }

    #[test]
    fn test_start_git_when_missing_property_never_touches_outer_folders(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
        guard_history in guard_history_strategy(),
        start in prop_oneof![
            Just(ChosenStart::Plain),
            Just(ChosenStart::EmptyGitFolder),
        ],
    ) {
        let guarded =
            prepare_guarded_folder(&name, guard_history).map_err(fail)?;
        shape_chosen_folder(&guarded.chosen, start, &files).map_err(fail)?;
        let guard_before = read_repository_state(&guarded.guard);
        let guard_file_before = read_guard_file(&guarded).map_err(fail)?;

        let checked = check_chosen_folder(&guarded.chosen);

        prop_assert_eq!(read_repository_state(&guarded.guard), guard_before);
        let guard_file_after = read_guard_file(&guarded).map_err(fail)?;
        prop_assert_eq!(guard_file_after, guard_file_before);
        let own_git_folder = guarded.chosen.join(GIT_FOLDER_NAME);
        let head_file = own_git_folder.join(HEAD_FILE_NAME);
        prop_assert!(checked.is_ok(), "{:?}", checked);
        prop_assert!(head_file.is_file());
    }

    #[test]
    fn test_start_git_when_missing_property_reports_only_starts_it_made(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
        start in prop_oneof![
            Just(ChosenStart::Plain),
            Just(ChosenStart::Unborn),
            Just(ChosenStart::Committed),
        ],
    ) {
        let guarded = guard_committed(&name)?;
        shape_chosen_folder(&guarded.chosen, start, &files).map_err(fail)?;
        let before = read_repository_state(&guarded.chosen);

        let checked = check_chosen_folder(&guarded.chosen).map_err(fail)?;

        let after = read_repository_state(&guarded.chosen);
        let had_commits = matches!(start, ChosenStart::Committed);
        prop_assert_eq!(read_started_flag(&checked), Some(!had_commits));
        if had_commits {
            prop_assert_eq!(after, before);
        } else {
            prop_assert_eq!(after.commit_count, "1");
        }
    }

    #[test]
    fn test_has_commits_property_an_existing_history_is_kept(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
        commit_count in 1..=MOST_COMMITS,
    ) {
        let guarded = guard_committed(&name)?;
        shape_chosen_folder(&guarded.chosen, ChosenStart::Committed, &files)
            .map_err(fail)?;
        add_commits(&guarded.chosen, commit_count - 1).map_err(fail)?;
        let before = read_repository_state(&guarded.chosen);

        let checked = check_chosen_folder(&guarded.chosen).map_err(fail)?;

        prop_assert_eq!(read_started_flag(&checked), Some(false));
        prop_assert_eq!(read_repository_state(&guarded.chosen), before);
    }

    #[test]
    fn test_has_commits_property_an_unborn_repository_gets_one_commit(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
        branch in BRANCH_PATTERN,
    ) {
        let guarded = guard_committed(&name)?;
        write_files(&guarded.chosen, &files).map_err(fail)?;
        let initial_branch = format!("--initial-branch={branch}");
        run_git(&guarded.chosen, &["init", "--quiet", &initial_branch])
            .map_err(fail)?;

        let checked = check_chosen_folder(&guarded.chosen).map_err(fail)?;

        let after = read_repository_state(&guarded.chosen);
        prop_assert_eq!(read_started_flag(&checked), Some(true));
        prop_assert_eq!(after.commit_count, "1");
        prop_assert_eq!(&checked["default_branch"], STARTED_BRANCH);
    }

    #[test]
    fn test_has_commits_property_another_branch_keeps_its_history(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
        orphan_branch in BRANCH_PATTERN,
        commit_count in 1..=MOST_COMMITS,
    ) {
        prop_assume!(orphan_branch != STARTED_BRANCH);
        let guarded = guard_committed(&name)?;
        let folder = &guarded.chosen;
        write_files(folder, &files).map_err(fail)?;
        run_git(folder, &["init", "--quiet", "--initial-branch=main"])
            .map_err(fail)?;
        add_commits(folder, commit_count).map_err(fail)?;
        run_git(folder, &["checkout", "--quiet", "--orphan", &orphan_branch])
            .map_err(fail)?;
        let main_before = run_git(folder, &["rev-parse", STARTED_BRANCH]);

        let _checked = check_chosen_folder(folder);

        let main_after = run_git(folder, &["rev-parse", STARTED_BRANCH]);
        prop_assert_eq!(main_after, main_before);
    }

    #[test]
    fn test_make_first_commit_property_commits_every_file(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let guarded = guard_unborn(&name)?;
        write_files(&guarded.chosen, &files).map_err(fail)?;

        check_chosen_folder(&guarded.chosen).map_err(fail)?;

        let committed = list_committed_files(&guarded.chosen).map_err(fail)?;
        let expected: Vec<String> = files.keys().cloned().collect();
        prop_assert_eq!(committed, expected);
    }

    #[test]
    fn test_make_first_commit_property_names_the_folder_in_the_subject(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let guarded = guard_committed(&name)?;
        write_files(&guarded.chosen, &files).map_err(fail)?;

        check_chosen_folder(&guarded.chosen).map_err(fail)?;

        let subject = run_git(&guarded.chosen, &["log", "-1", "--format=%s"])
            .map_err(fail)?;
        prop_assert_eq!(subject, format!("Start {name}"));
    }

    #[test]
    fn test_make_first_commit_property_leaves_a_clean_tree_on_main(
        name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let guarded = guard_committed(&name)?;
        write_files(&guarded.chosen, &files).map_err(fail)?;

        let checked = check_chosen_folder(&guarded.chosen).map_err(fail)?;

        let status = run_git(&guarded.chosen, &["status", "--porcelain"])
            .map_err(fail)?;
        let branch =
            run_git(&guarded.chosen, &["symbolic-ref", "--short", "HEAD"])
                .map_err(fail)?;
        prop_assert_eq!(status, "");
        prop_assert_eq!(branch, STARTED_BRANCH);
        prop_assert_eq!(&checked["default_branch"], STARTED_BRANCH);
    }
}
