use orchestration_core::workspace::AgentAccess;
use orchestration_node::item_drafting::{ProjectDraft, RepositoryDraft};
use proptest::prelude::*;

use crate::drafted_folders::{
    create_case_folder, create_empty_repository, create_plain_folder,
    has_own_git, planned_files_strategy, snapshot_folder,
};
use crate::drafted_item_checks::check_project;
use crate::support::drafting_samples::{THIS_DEVICE_ID, empty_context};
use crate::support::git_folders::create_git_folder;
use crate::support::test_device::fail;

const FOLDER_CASES: u32 = 6;
const BRANCH_PATTERN: &str = "[a-z][a-z0-9-]{0,8}[a-z0-9]";
const ANSWERED_BRANCH: &str = "answered-branch";
const REPOSITORY_FIX: &str = "Ask for changes and give a GitHub address or a \
                              git folder on this computer.";
const SPELLING_COUNT: usize = 3;
const PATH_SPELLING_COUNT: usize = 2;
const MISSING_PART_PATTERN: &str = "[a-z][a-z0-9-]{0,8}";

fn spell_folder(path: &str, spelling: usize) -> String {
    match spelling {
        0 => path.to_owned(),
        1 => format!("{path}/"),
        _ => format!("local:{THIS_DEVICE_ID}:{path}"),
    }
}

fn project_naming(address: &str) -> ProjectDraft {
    ProjectDraft {
        name: "billing".to_owned(),
        repositories: vec![RepositoryDraft {
            address: address.to_owned(),
            default_branch: ANSWERED_BRANCH.to_owned(),
        }],
        agent_access: AgentAccess::PushAfterApproval,
        approval_policy: None,
    }
}

fn local_repository(path: &str, branch: &str) -> RepositoryDraft {
    RepositoryDraft {
        address: format!("local:{THIS_DEVICE_ID}:{path}"),
        default_branch: branch.to_owned(),
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FOLDER_CASES))]

    #[test]
    fn test_resolve_folder_path_property_a_plain_folder_gets_no_git(
        planned_files in planned_files_strategy(),
        spelling in 0..SPELLING_COUNT,
    ) {
        let case_folder = create_case_folder()?;
        let folder = create_plain_folder(case_folder.path(), &planned_files)?;
        let path = folder.display().to_string();
        let before = snapshot_folder(&folder)?;
        let project = project_naming(&spell_folder(&path, spelling));

        let (checked, problems) = check_project(&empty_context(), &project)?;

        prop_assert!(!has_own_git(&folder));
        prop_assert_eq!(snapshot_folder(&folder)?, before);
        prop_assert!(checked.repositories.is_empty());
        let expected = format!(
            "Repos: the folder {path} is not a git repository. \
             {REPOSITORY_FIX}"
        );
        prop_assert_eq!(problems, vec![expected]);
    }

    #[test]
    fn test_resolve_folder_path_property_a_git_folder_is_only_read(
        branch in BRANCH_PATTERN,
        spelling in 0..PATH_SPELLING_COUNT,
    ) {
        let case_folder = create_case_folder()?;
        let folder =
            create_git_folder(case_folder.path(), &branch).map_err(fail)?;
        let path = folder.display().to_string();
        let before = snapshot_folder(&folder)?;
        let project = project_naming(&spell_folder(&path, spelling));

        let (checked, problems) = check_project(&empty_context(), &project)?;

        prop_assert_eq!(snapshot_folder(&folder)?, before);
        let expected = vec![local_repository(&path, &branch)];
        prop_assert_eq!(checked.repositories, expected);
        prop_assert!(problems.is_empty(), "{:?}", problems);
    }

    #[test]
    fn test_resolve_folder_path_property_an_empty_repository_gets_no_commit(
        branch in BRANCH_PATTERN,
    ) {
        let case_folder = create_case_folder()?;
        let folder = create_empty_repository(case_folder.path(), &branch)?;
        let path = folder.display().to_string();
        let before = snapshot_folder(&folder)?;

        let (checked, problems) =
            check_project(&empty_context(), &project_naming(&path))?;

        prop_assert_eq!(snapshot_folder(&folder)?, before);
        let expected = vec![local_repository(&path, &branch)];
        prop_assert_eq!(checked.repositories, expected);
        prop_assert!(problems.is_empty(), "{:?}", problems);
    }

    #[test]
    fn test_inspect_local_folder_property_a_missing_folder_stays_missing(
        missing_parts in proptest::collection::vec(MISSING_PART_PATTERN, 1..3),
        spelling in 0..SPELLING_COUNT,
    ) {
        let case_folder = create_case_folder()?;
        let mut missing_folder = case_folder.path().to_path_buf();
        for part in &missing_parts {
            missing_folder.push(part);
        }
        let path = missing_folder.display().to_string();
        let project = project_naming(&spell_folder(&path, spelling));

        let (checked, problems) = check_project(&empty_context(), &project)?;

        prop_assert!(!missing_folder.exists());
        prop_assert!(checked.repositories.is_empty());
        let expected = format!(
            "Repos: the folder {path} does not exist or this app cannot open \
             it. {REPOSITORY_FIX}"
        );
        prop_assert_eq!(problems, vec![expected]);
    }
}
