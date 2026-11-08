use std::path::PathBuf;

use orchestration_node::device_files::DeviceFiles;
use proptest::prelude::*;

use crate::device_folder::{
    ACCOUNT_FILE_NAME, AGENT_PLACE_FILE_NAME, PENDING_JOIN_FILE_NAME,
    SERVER_FILE_NAME, SERVER_GROUP_FILE_NAME, create_device_folder,
    open_device_files,
};
use crate::support::test_device::fail;

pub const PATH_CASE_COUNT: u32 = 24;
pub const FOLDER_NAME_PATTERN: &str =
    "[a-zA-Z0-9 _\u{e9}\u{4e2d}-][a-zA-Z0-9 ._\u{e9}\u{4e2d}-]{0,23}";

const RECORDS_WITHOUT_A_PATH_GETTER: [&str; 5] = [
    ACCOUNT_FILE_NAME,
    PENDING_JOIN_FILE_NAME,
    SERVER_FILE_NAME,
    SERVER_GROUP_FILE_NAME,
    AGENT_PLACE_FILE_NAME,
];

pub type PathGetter = fn(&DeviceFiles) -> PathBuf;

const PATH_GETTERS: [PathGetter; 5] = [
    DeviceFiles::identity_path,
    DeviceFiles::sealed_identity_path,
    DeviceFiles::hosted_server_directory,
    DeviceFiles::repository_cache_directory,
    DeviceFiles::hosted_server_record_path,
];

pub fn check_sits_directly_in_data_folder(
    folder_name: &str,
    getter: PathGetter,
) -> Result<(), TestCaseError> {
    let folder = create_device_folder()?;
    let data_path = folder.root_path().join(folder_name);
    let files = DeviceFiles::open(&data_path).map_err(fail)?;

    let found_path = getter(&files);

    prop_assert_eq!(found_path.parent(), Some(data_path.as_path()));
    let file_name = found_path.file_name();
    prop_assert!(file_name.is_some_and(|name| !name.is_empty()));
    Ok(())
}

pub fn check_differs_from_every_other_path(
    getter: PathGetter,
) -> Result<(), TestCaseError> {
    let folder = create_device_folder()?;
    let files = open_device_files(&folder)?;
    let mut known_paths = Vec::new();
    for other_getter in PATH_GETTERS {
        known_paths.push(other_getter(&files));
    }
    for record_name in RECORDS_WITHOUT_A_PATH_GETTER {
        known_paths.push(folder.data_path.join(record_name));
    }

    let found_path = getter(&files);

    let mut matching_count = 0;
    for known_path in &known_paths {
        if *known_path == found_path {
            matching_count += 1;
        }
    }
    prop_assert_eq!(matching_count, 1, "{:?}", found_path);
    Ok(())
}

pub fn check_survives_reopening(
    first_name: &str,
    second_name: &str,
    getter: PathGetter,
) -> Result<(), TestCaseError> {
    let folder = create_device_folder()?;
    let first_path = folder.root_path().join(first_name);
    let second_path = folder.root_path().join(second_name);

    let first_files = DeviceFiles::open(&first_path).map_err(fail)?;
    let reopened_files = DeviceFiles::open(&first_path).map_err(fail)?;
    let second_files = DeviceFiles::open(&second_path).map_err(fail)?;

    let first_found = getter(&first_files);
    prop_assert_eq!(&first_found, &getter(&reopened_files));
    prop_assert_eq!(&first_found, &getter(&first_files));
    let second_found = getter(&second_files);
    prop_assert_eq!(first_found.file_name(), second_found.file_name());
    Ok(())
}
