use orchestration_runner::git_command::GitError;
use proptest::prelude::*;

use crate::outer_guard::{
    FENCE_CASES, FolderShape, GUARD_WORK_SUBJECT, NESTED_START_SUBJECT,
    OuterGuard, folder_files_strategy, folder_name_strategy,
    refused_shape_strategy, shape_without_git_strategy,
};
use crate::runner_operations::{list_unpushed_commits, push_task_branch};

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FENCE_CASES))]

    #[test]
    fn test_list_unpushed_commit_subjects_property_refuses_folder_without_git(
        folder_name in folder_name_strategy(),
        files in folder_files_strategy(),
        shape in shape_without_git_strategy(),
    ) {
        let guard = OuterGuard::build(&folder_name, &files, shape)?;
        let state_before = guard.read_state()?;

        let listing = list_unpushed_commits(&guard.working_folder)?;

        let is_refused = matches!(listing, Err(GitError::NoOwnRepository(_)));
        prop_assert!(is_refused, "{:?}", listing);
        prop_assert_eq!(guard.read_state()?, state_before);
    }

    #[test]
    fn test_list_unpushed_commit_subjects_property_never_lists_outer_commits(
        folder_name in folder_name_strategy(),
        files in folder_files_strategy(),
        shape in refused_shape_strategy(),
    ) {
        let guard = OuterGuard::build(&folder_name, &files, shape)?;

        let listing = list_unpushed_commits(&guard.working_folder)?;

        let listed_subjects = listing.as_deref().unwrap_or_default();
        let outer_work = GUARD_WORK_SUBJECT.to_string();
        prop_assert!(!listed_subjects.contains(&outer_work), "{:?}", listing);
        prop_assert!(listing.is_err(), "{:?}", listing);
    }

    #[test]
    fn test_list_unpushed_commit_subjects_property_lists_only_nested_commits(
        folder_name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let shape = FolderShape::OwnRepository;
        let guard = OuterGuard::build(&folder_name, &files, shape)?;
        let state_before = guard.read_state()?;

        let listing = list_unpushed_commits(&guard.working_folder)?;

        let listed_subjects = listing.as_deref().unwrap_or_default();
        prop_assert_eq!(listed_subjects, [NESTED_START_SUBJECT.to_string()]);
        prop_assert_eq!(guard.read_state()?, state_before);
    }

    #[test]
    fn test_push_branch_property_refuses_a_folder_without_its_own_repository(
        folder_name in folder_name_strategy(),
        files in folder_files_strategy(),
        shape in shape_without_git_strategy(),
    ) {
        let guard = OuterGuard::build(&folder_name, &files, shape)?;
        let state_before = guard.read_state()?;

        let pushed = push_task_branch(&guard.working_folder)?;

        let is_refused = matches!(pushed, Err(GitError::NoOwnRepository(_)));
        prop_assert!(is_refused, "{:?}", pushed);
        prop_assert_eq!(guard.read_state()?, state_before);
    }

    #[test]
    fn test_push_branch_property_never_pushes_from_the_outer_repository(
        folder_name in folder_name_strategy(),
        files in folder_files_strategy(),
        shape in refused_shape_strategy(),
    ) {
        let guard = OuterGuard::build(&folder_name, &files, shape)?;
        let state_before = guard.read_state()?;

        let pushed = push_task_branch(&guard.working_folder)?;

        prop_assert!(pushed.is_err(), "{:?}", pushed);
        prop_assert_eq!(guard.read_state()?, state_before);
    }

    #[test]
    fn test_push_branch_property_nested_repository_never_reaches_outer_origin(
        folder_name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let shape = FolderShape::OwnRepository;
        let guard = OuterGuard::build(&folder_name, &files, shape)?;
        let state_before = guard.read_state()?;

        let pushed = push_task_branch(&guard.working_folder)?;

        prop_assert!(pushed.is_err(), "{:?}", pushed);
        prop_assert_eq!(guard.read_state()?, state_before);
    }
}
