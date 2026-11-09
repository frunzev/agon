use std::fs;
use std::path::PathBuf;

use proptest::prelude::*;
use proptest::sample::Index;
use tempfile::TempDir;

use crate::search_path_steps::{
    EXECUTABLE_MODE, XCODE_LABEL, XCODE_PROGRAM, place_program_folder,
    place_program_link, read_detected_labels, write_program,
};
use crate::support::test_device::{describe, fail};

const SEARCH_CASES: u32 = 2;
const MOST_FOLDERS: usize = 4;
const MOST_MISSING_FOLDERS: usize = 3;
const ANY_EXECUTE_BITS: u32 = 0o111;
const LARGEST_MODE: u32 = 0o777;
const LINK_TARGET_NAME: &str = "real-xcodebuild";
const PLAIN_FILE_NAME: &str = "not-a-folder";

#[derive(Debug)]
struct SearchFolders {
    root: TempDir,
    folders: Vec<PathBuf>,
}

fn create_folders(count: usize) -> Result<SearchFolders, String> {
    let root = TempDir::new().map_err(describe)?;
    let mut folders = Vec::new();
    for index in 0..count {
        let folder = root.path().join(format!("folder-{index}"));
        fs::create_dir(&folder).map_err(describe)?;
        folders.push(folder);
    }
    Ok(SearchFolders { root, folders })
}

fn has_xcode_label(labels: &[String]) -> bool {
    labels.iter().any(|label| label == XCODE_LABEL)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEARCH_CASES))]

    #[test]
    fn test_is_program_on_path_property_finds_it_in_any_folder(
        folder_count in 1..=MOST_FOLDERS,
        chosen in any::<Index>(),
    ) {
        let search = create_folders(folder_count).map_err(fail)?;
        let chosen_folder = &search.folders[chosen.index(folder_count)];
        let program_path = chosen_folder.join(XCODE_PROGRAM);
        write_program(&program_path, EXECUTABLE_MODE).map_err(fail)?;

        let labels = read_detected_labels(&search.folders).map_err(fail)?;

        prop_assert!(has_xcode_label(&labels), "{:?}", labels);
    }

    #[test]
    fn test_is_program_on_path_property_missing_folders_are_skipped(
        missing_count in 1..=MOST_MISSING_FOLDERS,
        is_placed in any::<bool>(),
    ) {
        let search = create_folders(1).map_err(fail)?;
        let plain_file = search.root.path().join(PLAIN_FILE_NAME);
        fs::write(&plain_file, "").map_err(fail)?;
        let mut search_path = vec![plain_file];
        for index in 0..missing_count {
            let missing = search.root.path().join(format!("missing-{index}"));
            search_path.push(missing);
        }
        search_path.extend(search.folders.iter().cloned());
        if is_placed {
            let program_path = search.folders[0].join(XCODE_PROGRAM);
            write_program(&program_path, EXECUTABLE_MODE).map_err(fail)?;
        }

        let labels = read_detected_labels(&search_path).map_err(fail)?;

        prop_assert_eq!(has_xcode_label(&labels), is_placed, "{:?}", labels);
    }

    #[test]
    fn test_is_program_on_path_property_folders_without_it_find_nothing(
        folder_count in 1..=MOST_FOLDERS,
    ) {
        let search = create_folders(folder_count).map_err(fail)?;

        let labels = read_detected_labels(&search.folders).map_err(fail)?;

        prop_assert!(!has_xcode_label(&labels), "{:?}", labels);
        prop_assert!(!labels.is_empty());
    }

    #[test]
    fn test_is_executable_file_property_needs_an_execute_bit(
        mode in 0..=LARGEST_MODE,
    ) {
        let search = create_folders(1).map_err(fail)?;
        let program_path = search.folders[0].join(XCODE_PROGRAM);
        write_program(&program_path, mode).map_err(fail)?;

        let labels = read_detected_labels(&search.folders).map_err(fail)?;

        let is_executable = mode & ANY_EXECUTE_BITS != 0;
        prop_assert_eq!(has_xcode_label(&labels), is_executable, "{:o}", mode);
    }

    #[test]
    fn test_is_executable_file_property_a_folder_is_no_program(
        folder_count in 1..=MOST_FOLDERS,
        chosen in any::<Index>(),
    ) {
        let search = create_folders(folder_count).map_err(fail)?;
        let chosen_folder = &search.folders[chosen.index(folder_count)];
        place_program_folder(chosen_folder).map_err(fail)?;

        let labels = read_detected_labels(&search.folders).map_err(fail)?;

        prop_assert!(!has_xcode_label(&labels), "{:?}", labels);
    }

    #[test]
    fn test_is_executable_file_property_follows_links_to_programs(
        is_target_present in any::<bool>(),
    ) {
        let search = create_folders(1).map_err(fail)?;
        let target = search.root.path().join(LINK_TARGET_NAME);
        if is_target_present {
            write_program(&target, EXECUTABLE_MODE).map_err(fail)?;
        }
        place_program_link(&search.folders[0], &target).map_err(fail)?;

        let labels = read_detected_labels(&search.folders).map_err(fail)?;

        prop_assert_eq!(has_xcode_label(&labels), is_target_present);
    }
}
