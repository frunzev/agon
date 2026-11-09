use orchestration_runner::git_command::GitError;
use proptest::prelude::*;

use crate::outer_guard::{
    FENCE_CASES, FolderShape, OuterGuard, fail, folder_files_strategy,
    folder_name_strategy, shape_without_git_strategy,
};
use crate::runner_operations::{operation_strategy, run_operation};

const MISSING_REFUSAL: &str = "the folder without a repository was accepted";

fn broken_git_folder_strategy() -> impl Strategy<Value = FolderShape> {
    prop_oneof![
        Just(FolderShape::EmptyGitFolder),
        Just(FolderShape::BrokenGitLink),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FENCE_CASES))]

    #[test]
    fn test_run_git_property_refuses_a_folder_without_its_own_repository(
        folder_name in folder_name_strategy(),
        files in folder_files_strategy(),
        shape in shape_without_git_strategy(),
        operation in operation_strategy(),
    ) {
        let guard = OuterGuard::build(&folder_name, &files, shape)?;
        let state_before = guard.read_state()?;

        let outcome = run_operation(operation, &guard.working_folder)?;

        let is_refused = matches!(outcome, Err(GitError::NoOwnRepository(_)));
        prop_assert!(is_refused, "{:?}", outcome);
        prop_assert_eq!(guard.read_state()?, state_before);
    }

    #[test]
    fn test_run_git_property_never_climbs_past_a_broken_git_folder(
        folder_name in folder_name_strategy(),
        files in folder_files_strategy(),
        shape in broken_git_folder_strategy(),
        operation in operation_strategy(),
    ) {
        let guard = OuterGuard::build(&folder_name, &files, shape)?;
        let state_before = guard.read_state()?;

        let outcome = run_operation(operation, &guard.working_folder)?;

        prop_assert!(outcome.is_err(), "{:?}", outcome);
        prop_assert_eq!(guard.read_state()?, state_before);
    }

    #[test]
    fn test_run_git_property_refusal_names_the_refused_folder(
        folder_name in folder_name_strategy(),
        files in folder_files_strategy(),
        shape in shape_without_git_strategy(),
        operation in operation_strategy(),
    ) {
        let guard = OuterGuard::build(&folder_name, &files, shape)?;

        let outcome = run_operation(operation, &guard.working_folder)?;

        let Err(refusal) = outcome else {
            return Err(fail(MISSING_REFUSAL));
        };
        let folder_text = guard.working_folder.display().to_string();
        prop_assert!(refusal.to_string().contains(&folder_text));
    }

    #[test]
    fn test_run_git_property_a_nested_repository_leaves_the_outer_one_alone(
        folder_name in folder_name_strategy(),
        files in folder_files_strategy(),
        operation in operation_strategy(),
    ) {
        let shape = FolderShape::OwnRepository;
        let guard = OuterGuard::build(&folder_name, &files, shape)?;
        let state_before = guard.read_state()?;

        let _nested_outcome = run_operation(operation, &guard.working_folder)?;

        prop_assert_eq!(guard.read_state()?, state_before);
    }
}
