use std::fs;

use orchestration_runner::git_command::GitError;
use proptest::prelude::*;

use crate::outer_guard::{
    FENCE_CASES, FolderShape, NESTED_START_SUBJECT, OuterGuard, fail,
    folder_files_strategy, folder_name_strategy, refused_shape_strategy,
    shape_without_git_strategy,
};
use crate::runner_operations::{CHANGE_SUBJECT, commit_changes};

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FENCE_CASES))]

    #[test]
    fn test_commit_uncommitted_changes_property_refuses_a_folder_without_git(
        folder_name in folder_name_strategy(),
        files in folder_files_strategy(),
        shape in shape_without_git_strategy(),
    ) {
        let guard = OuterGuard::build(&folder_name, &files, shape)?;
        let state_before = guard.read_state()?;

        let committed = commit_changes(&guard.working_folder)?;

        let is_refused =
            matches!(committed, Err(GitError::NoOwnRepository(_)));
        prop_assert!(is_refused, "{:?}", committed);
        prop_assert_eq!(guard.read_state()?, state_before);
        for (file_name, file_text) in &files {
            let kept_path = guard.working_folder.join(file_name);
            let kept_text = fs::read_to_string(kept_path).map_err(fail)?;
            prop_assert_eq!(&kept_text, file_text);
        }
    }

    #[test]
    fn test_commit_uncommitted_changes_property_never_touches_outer_repository(
        folder_name in folder_name_strategy(),
        files in folder_files_strategy(),
        shape in refused_shape_strategy(),
    ) {
        let guard = OuterGuard::build(&folder_name, &files, shape)?;
        let subjects_before = guard.list_subjects(&guard.repository)?;
        let state_before = guard.read_state()?;

        let committed = commit_changes(&guard.working_folder)?;

        let subjects_after = guard.list_subjects(&guard.repository)?;
        prop_assert!(committed.is_err(), "{:?}", committed);
        let change_subject = CHANGE_SUBJECT.to_string();
        prop_assert!(!subjects_after.contains(&change_subject));
        prop_assert_eq!(subjects_after, subjects_before);
        prop_assert_eq!(guard.read_state()?, state_before);
    }

    #[test]
    fn test_commit_uncommitted_changes_property_commits_only_nested_repository(
        folder_name in folder_name_strategy(),
        files in folder_files_strategy(),
    ) {
        let shape = FolderShape::OwnRepository;
        let guard = OuterGuard::build(&folder_name, &files, shape)?;
        let state_before = guard.read_state()?;

        let committed = commit_changes(&guard.working_folder)?;

        prop_assert!(committed.is_ok(), "{:?}", committed);
        let nested_subjects = guard.list_subjects(&guard.working_folder)?;
        let mut expected_subjects = Vec::new();
        if !files.is_empty() {
            expected_subjects.push(CHANGE_SUBJECT.to_string());
        }
        expected_subjects.push(NESTED_START_SUBJECT.to_string());
        prop_assert_eq!(nested_subjects, expected_subjects);
        prop_assert_eq!(guard.read_state()?, state_before);
    }
}
