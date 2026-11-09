use std::path::{Path, PathBuf};

use orchestration_core::git_ceiling::{
    GIT_CEILING_VARIABLE, name_git_ceiling,
};
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::select;

const FOLDER_NAME_PATTERN: &str = "[a-zA-Z0-9 _\u{e9}\u{4e2d}-]{1,12}";
const MOST_FOLDER_DEPTH: usize = 5;
const MOST_ROOT_SEPARATORS: usize = 4;
const ROOT_FOLDER: &str = "/";
const TRAILING_ENDINGS: [&str; 3] = ["/", "/.", "//"];
const GIT_READS_THIS_VARIABLE: &str = "GIT_CEILING_DIRECTORIES";
const GIT_FOLDER_LIST_SEPARATOR: char = ':';
const MISSING_CEILING: &str = "a folder below the root has a ceiling";

fn absolute_folder_strategy() -> impl Strategy<Value = PathBuf> {
    vec(FOLDER_NAME_PATTERN, 1..=MOST_FOLDER_DEPTH)
        .prop_map(|folder_names| join_below_root(&folder_names))
}

fn join_below_root(folder_names: &[String]) -> PathBuf {
    let mut folder = PathBuf::from(ROOT_FOLDER);
    for folder_name in folder_names {
        folder.push(folder_name);
    }
    folder
}

proptest! {
    #[test]
    fn test_name_git_ceiling_property_the_folder_sits_right_below_it(
        folder in absolute_folder_strategy(),
    ) {
        let Some(ceiling) = name_git_ceiling(&folder) else {
            return Err(TestCaseError::fail(MISSING_CEILING));
        };

        let folder_name = folder.file_name().unwrap_or_default();
        prop_assert_eq!(Path::new(&ceiling).join(folder_name), folder);
    }

    #[test]
    fn test_name_git_ceiling_property_is_a_strict_ancestor_of_the_folder(
        folder in absolute_folder_strategy(),
    ) {
        let Some(ceiling) = name_git_ceiling(&folder) else {
            return Err(TestCaseError::fail(MISSING_CEILING));
        };

        let ceiling_folder = Path::new(&ceiling);
        prop_assert!(folder.starts_with(ceiling_folder));
        prop_assert_ne!(ceiling_folder, folder.as_path());
        prop_assert!(ceiling_folder.is_absolute());
    }

    #[test]
    fn test_name_git_ceiling_property_ignores_trailing_separators(
        folder in absolute_folder_strategy(),
        ending in select(TRAILING_ENDINGS.to_vec()),
    ) {
        let folder_text = folder.display().to_string();
        let ended_folder = PathBuf::from(format!("{folder_text}{ending}"));

        let ended_ceiling = name_git_ceiling(&ended_folder);

        prop_assert_eq!(ended_ceiling, name_git_ceiling(&folder));
    }

    #[test]
    fn test_name_git_ceiling_property_the_root_has_no_ceiling(
        separator_count in 1..=MOST_ROOT_SEPARATORS,
    ) {
        let root = PathBuf::from(ROOT_FOLDER.repeat(separator_count));

        prop_assert_eq!(name_git_ceiling(&root), None);
    }

    #[test]
    fn test_git_ceiling_variable_property_names_one_folder_git_reads(
        folder in absolute_folder_strategy(),
    ) {
        let ceiling = name_git_ceiling(&folder).unwrap_or_default();

        prop_assert_eq!(GIT_CEILING_VARIABLE, GIT_READS_THIS_VARIABLE);
        prop_assert!(!ceiling.contains(GIT_FOLDER_LIST_SEPARATOR));
        prop_assert!(!ceiling.is_empty());
    }
}
