use std::fs;

use orchestration_node::device_files::DeviceFiles;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::device_folder::{
    DEVICE_RECORD_NAMES, PENDING_JOIN_FILE_NAME, create_device_folder,
    link_to_outside_file, list_file_names, open_device_files,
};
use crate::path_checks::FOLDER_NAME_PATTERN;
use crate::support::test_device::fail;

const CASE_COUNT: u32 = 16;
const LONGEST_CONTENT: usize = 64;
const PARENT_FOLDER_STEP: &str = "..";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CASE_COUNT))]

    #[test]
    fn test_remove_pending_join_property_a_link_loses_only_itself(
        outside_content in vec(any::<u8>(), 0..LONGEST_CONTENT),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        let outside_file = link_to_outside_file(
            &folder,
            PENDING_JOIN_FILE_NAME,
            &outside_content,
        )?;

        files.remove_pending_join().map_err(fail)?;

        prop_assert!(list_file_names(&folder.data_path)?.is_empty());
        let kept = fs::read(&outside_file).map_err(fail)?;
        prop_assert_eq!(kept, outside_content);
    }

    #[test]
    fn test_remove_device_records_property_links_lose_only_themselves(
        linked_names in proptest::sample::subsequence(
            DEVICE_RECORD_NAMES.to_vec(),
            1..=DEVICE_RECORD_NAMES.len(),
        ),
        outside_content in vec(any::<u8>(), 0..LONGEST_CONTENT),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        let mut outside_files = Vec::new();
        for linked_name in &linked_names {
            outside_files.push(link_to_outside_file(
                &folder,
                linked_name,
                &outside_content,
            )?);
        }

        files.remove_device_records().map_err(fail)?;

        prop_assert!(list_file_names(&folder.data_path)?.is_empty());
        for outside_file in &outside_files {
            let kept = fs::read(outside_file).map_err(fail)?;
            prop_assert_eq!(&kept, &outside_content);
        }
    }

    #[test]
    fn test_remove_file_if_present_property_dot_dot_stays_in_its_folder(
        detour_name in FOLDER_NAME_PATTERN,
        detour_content in vec(any::<u8>(), 0..LONGEST_CONTENT),
    ) {
        let folder = create_device_folder()?;
        let data_name = folder.data_path.file_name().unwrap_or_default();
        let outside_name = folder.outside_path.file_name().unwrap_or_default();
        prop_assume!(detour_name.as_str() != data_name);
        prop_assume!(detour_name.as_str() != outside_name);
        let detour_path = folder.root_path().join(&detour_name);
        fs::create_dir_all(&detour_path).map_err(fail)?;
        for record_name in DEVICE_RECORD_NAMES {
            fs::write(detour_path.join(record_name), &detour_content)
                .map_err(fail)?;
        }
        let detoured_data_path =
            detour_path.join(PARENT_FOLDER_STEP).join(data_name);
        let files = DeviceFiles::open(&detoured_data_path).map_err(fail)?;
        for record_name in DEVICE_RECORD_NAMES {
            fs::write(folder.data_path.join(record_name), &detour_content)
                .map_err(fail)?;
        }

        files.remove_device_records().map_err(fail)?;

        prop_assert!(list_file_names(&folder.data_path)?.is_empty());
        for record_name in DEVICE_RECORD_NAMES {
            let kept = fs::read(detour_path.join(record_name)).map_err(fail)?;
            prop_assert_eq!(&kept, &detour_content);
        }
    }
}
