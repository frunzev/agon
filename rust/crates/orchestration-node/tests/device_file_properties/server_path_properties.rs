use orchestration_node::device_files::DeviceFiles;
use proptest::prelude::*;

use crate::path_checks::{
    FOLDER_NAME_PATTERN, PATH_CASE_COUNT, check_differs_from_every_other_path,
    check_sits_directly_in_data_folder, check_survives_reopening,
};

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PATH_CASE_COUNT))]

    #[test]
    fn test_hosted_server_directory_property_sits_in_the_data_folder(
        folder_name in FOLDER_NAME_PATTERN,
    ) {
        check_sits_directly_in_data_folder(
            &folder_name,
            DeviceFiles::hosted_server_directory,
        )?;
    }

    #[test]
    fn test_hosted_server_directory_property_differs_from_every_other_path(
        _case in any::<u8>(),
    ) {
        check_differs_from_every_other_path(
            DeviceFiles::hosted_server_directory,
        )?;
    }

    #[test]
    fn test_hosted_server_directory_property_is_stable_across_folders(
        first_name in FOLDER_NAME_PATTERN,
        second_name in FOLDER_NAME_PATTERN,
    ) {
        check_survives_reopening(
            &first_name,
            &second_name,
            DeviceFiles::hosted_server_directory,
        )?;
    }

    #[test]
    fn test_repository_cache_directory_property_sits_in_the_data_folder(
        folder_name in FOLDER_NAME_PATTERN,
    ) {
        check_sits_directly_in_data_folder(
            &folder_name,
            DeviceFiles::repository_cache_directory,
        )?;
    }

    #[test]
    fn test_repository_cache_directory_property_differs_from_every_other_path(
        _case in any::<u8>(),
    ) {
        check_differs_from_every_other_path(
            DeviceFiles::repository_cache_directory,
        )?;
    }

    #[test]
    fn test_repository_cache_directory_property_is_stable_across_folders(
        first_name in FOLDER_NAME_PATTERN,
        second_name in FOLDER_NAME_PATTERN,
    ) {
        check_survives_reopening(
            &first_name,
            &second_name,
            DeviceFiles::repository_cache_directory,
        )?;
    }

    #[test]
    fn test_hosted_server_record_path_property_sits_in_the_data_folder(
        folder_name in FOLDER_NAME_PATTERN,
    ) {
        check_sits_directly_in_data_folder(
            &folder_name,
            DeviceFiles::hosted_server_record_path,
        )?;
    }

    #[test]
    fn test_hosted_server_record_path_property_differs_from_every_other_path(
        _case in any::<u8>(),
    ) {
        check_differs_from_every_other_path(
            DeviceFiles::hosted_server_record_path,
        )?;
    }

    #[test]
    fn test_hosted_server_record_path_property_is_stable_across_folders(
        first_name in FOLDER_NAME_PATTERN,
        second_name in FOLDER_NAME_PATTERN,
    ) {
        check_survives_reopening(
            &first_name,
            &second_name,
            DeviceFiles::hosted_server_record_path,
        )?;
    }
}
