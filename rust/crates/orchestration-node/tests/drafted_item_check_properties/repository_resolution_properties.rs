use std::path::Path;

use orchestration_core::local_folders::{
    is_local_address, parse_local_address,
};
use orchestration_core::repository_address::parse_repository_address;
use orchestration_node::item_drafting::{ItemDraft, check_item_draft};
use proptest::prelude::*;

use crate::drafted_folders::{
    PlannedFiles, create_case_folder, create_plain_folder,
};
use crate::drafted_item_checks::{check_again, check_project};
use crate::repository_sentence_properties::github_project;
use crate::support::drafting_samples::{
    FOREIGN_DEVICE_ID, THIS_DEVICE_ID, empty_context,
};
use crate::support::git_folders::create_git_folder;
use crate::support::test_device::fail;

const FOLDER_CASES: u32 = 6;
const MOST_ANSWERS: usize = 6;
const ANSWER_SHAPE_COUNT: usize = 8;
const HOSTILE_ADDRESS_PATTERN: &str =
    "[a-zA-Z0-9@._~-][a-zA-Z0-9:@./_ ~-]{0,23}";
const MISSING_FOLDER_NAME: &str = "missing";

fn answer_shapes_strategy() -> impl Strategy<Value = Vec<(usize, String)>> {
    let shape = (0..ANSWER_SHAPE_COUNT, HOSTILE_ADDRESS_PATTERN);
    proptest::collection::vec(shape, 1..MOST_ANSWERS)
}

fn spell_answer(
    shape: usize,
    hostile: &str,
    git_path: &str,
    plain_path: &str,
    missing_path: &str,
) -> String {
    match shape {
        0 => git_path.to_owned(),
        1 => format!("{git_path}/"),
        2 => format!("local:{THIS_DEVICE_ID}:{git_path}"),
        3 => format!("local:{FOREIGN_DEVICE_ID}:{git_path}"),
        4 => plain_path.to_owned(),
        5 => missing_path.to_owned(),
        6 => "https://github.com/acme/app.git".to_owned(),
        _ => hostile.to_owned(),
    }
}

fn spell_answers(
    shapes: &[(usize, String)],
    case_root: &Path,
    git_path: &str,
) -> Result<Vec<String>, TestCaseError> {
    let plain_folder = create_plain_folder(case_root, &PlannedFiles::new())?;
    let plain_path = plain_folder.display().to_string();
    let missing_path =
        case_root.join(MISSING_FOLDER_NAME).display().to_string();
    let mut answers = Vec::new();
    for (shape, hostile) in shapes {
        answers.push(spell_answer(
            *shape,
            hostile,
            git_path,
            &plain_path,
            &missing_path,
        ));
    }
    Ok(answers)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FOLDER_CASES))]

    #[test]
    fn test_resolve_repository_property_resolves_only_parseable_repos_here(
        shapes in answer_shapes_strategy(),
    ) {
        let case_folder = create_case_folder()?;
        let git_folder =
            create_git_folder(case_folder.path(), "main").map_err(fail)?;
        let git_path = git_folder.display().to_string();
        let answers = spell_answers(&shapes, case_folder.path(), &git_path)?;
        let project = github_project("billing", &answers);

        let (checked, _) = check_project(&empty_context(), &project)?;

        for repository in &checked.repositories {
            let address = &repository.address;
            let reparsed = parse_repository_address(address);
            prop_assert_eq!(reparsed, Ok(address.clone()));
            if is_local_address(address) {
                let folder = parse_local_address(address).map_err(fail)?;
                prop_assert_eq!(&folder.device_id.0, THIS_DEVICE_ID);
                prop_assert_eq!(&folder.path, &git_path);
            }
        }
    }

    #[test]
    fn test_resolve_repository_property_is_idempotent_on_its_output(
        shapes in answer_shapes_strategy(),
    ) {
        let case_folder = create_case_folder()?;
        let git_folder =
            create_git_folder(case_folder.path(), "main").map_err(fail)?;
        let git_path = git_folder.display().to_string();
        let answers = spell_answers(&shapes, case_folder.path(), &git_path)?;
        let drafted = ItemDraft::Project(github_project("billing", &answers));
        let checked = check_item_draft(&empty_context(), &drafted);

        let checked_again = check_again(&empty_context(), &checked);

        prop_assert_eq!(checked_again.draft, checked.draft);
    }

    #[test]
    fn test_resolve_repository_property_every_spelling_is_one_repo(
        spellings in proptest::collection::vec(0..3usize, 1..MOST_ANSWERS),
    ) {
        let case_folder = create_case_folder()?;
        let git_folder =
            create_git_folder(case_folder.path(), "main").map_err(fail)?;
        let git_path = git_folder.display().to_string();
        let mut shapes = Vec::new();
        for spelling in spellings {
            shapes.push((spelling, String::new()));
        }
        let answers = spell_answers(&shapes, case_folder.path(), &git_path)?;
        let project = github_project("billing", &answers);

        let (checked, problems) = check_project(&empty_context(), &project)?;

        prop_assert_eq!(checked.repositories.len(), 1);
        prop_assert!(problems.is_empty(), "{:?}", problems);
    }
}
