use std::fs;

use orchestration_node::device_files::{DeviceFiles, HostedServerRecord};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::device_folder::{
    create_device_folder, list_file_names, open_device_files,
};
use crate::path_checks::{
    FOLDER_NAME_PATTERN, PATH_CASE_COUNT, check_differs_from_every_other_path,
    check_sits_directly_in_data_folder, check_survives_reopening,
};
use crate::support::test_device::fail;

const MOST_NESTED_FOLDERS: usize = 4;
const LONGEST_CONTENT: usize = 64;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PATH_CASE_COUNT))]

    #[test]
    fn test_device_files_open_property_creates_every_missing_folder(
        folder_names in vec(FOLDER_NAME_PATTERN, 1..MOST_NESTED_FOLDERS),
    ) {
        let folder = create_device_folder()?;
        let mut data_path = folder.root_path().to_path_buf();
        for folder_name in &folder_names {
            data_path.push(folder_name);
        }

        DeviceFiles::open(&data_path).map_err(fail)?;

        prop_assert!(data_path.is_dir());
        prop_assert!(list_file_names(&data_path)?.is_empty());
    }

    #[test]
    fn test_device_files_open_property_reopening_keeps_saved_records(
        port in any::<u16>(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        files
            .save_hosted_server(&HostedServerRecord { port })
            .map_err(fail)?;
        let names_before = list_file_names(&folder.data_path)?;

        let reopened = open_device_files(&folder)?;

        let loaded = reopened.load_hosted_server().map_err(fail)?;
        prop_assert_eq!(loaded, Some(HostedServerRecord { port }));
        prop_assert_eq!(list_file_names(&folder.data_path)?, names_before);
    }

    #[test]
    fn test_device_files_open_property_a_file_in_the_way_is_refused(
        content in vec(any::<u8>(), 0..LONGEST_CONTENT),
    ) {
        let folder = create_device_folder()?;
        fs::write(&folder.data_path, &content).map_err(fail)?;

        let opened = DeviceFiles::open(&folder.data_path);

        prop_assert!(opened.is_err(), "{:?}", opened);
        prop_assert_eq!(fs::read(&folder.data_path).map_err(fail)?, content);
    }

    #[test]
    fn test_identity_path_property_sits_in_the_data_folder(
        folder_name in FOLDER_NAME_PATTERN,
    ) {
        check_sits_directly_in_data_folder(
            &folder_name,
            DeviceFiles::identity_path,
        )?;
    }

    #[test]
    fn test_identity_path_property_differs_from_every_other_path(
        _case in any::<u8>(),
    ) {
        check_differs_from_every_other_path(DeviceFiles::identity_path)?;
    }

    #[test]
    fn test_identity_path_property_is_stable_across_folders(
        first_name in FOLDER_NAME_PATTERN,
        second_name in FOLDER_NAME_PATTERN,
    ) {
        check_survives_reopening(
            &first_name,
            &second_name,
            DeviceFiles::identity_path,
        )?;
    }

    #[test]
    fn test_sealed_identity_path_property_sits_in_the_data_folder(
        folder_name in FOLDER_NAME_PATTERN,
    ) {
        check_sits_directly_in_data_folder(
            &folder_name,
            DeviceFiles::sealed_identity_path,
        )?;
    }

    #[test]
    fn test_sealed_identity_path_property_differs_from_every_other_path(
        _case in any::<u8>(),
    ) {
        check_differs_from_every_other_path(
            DeviceFiles::sealed_identity_path,
        )?;
    }

    #[test]
    fn test_sealed_identity_path_property_is_stable_across_folders(
        first_name in FOLDER_NAME_PATTERN,
        second_name in FOLDER_NAME_PATTERN,
    ) {
        check_survives_reopening(
            &first_name,
            &second_name,
            DeviceFiles::sealed_identity_path,
        )?;
    }
}
