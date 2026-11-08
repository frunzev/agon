use std::fmt::Debug;
use std::fs;

use orchestration_node::device_files::DeviceFiles;
use orchestration_node::node_error::NodeError;
use proptest::prelude::*;
use proptest::sample::Index;
use serde::Serialize;
use serde_json::Value;

use crate::device_folder::{
    create_device_folder, list_file_names, open_device_files,
};
use crate::support::test_device::fail;

pub type SaveRecord<Record> =
    fn(&DeviceFiles, &Record) -> Result<(), NodeError>;
pub type LoadRecord<Record> =
    fn(&DeviceFiles) -> Result<Option<Record>, NodeError>;

pub fn check_round_trip<Record: PartialEq + Debug>(
    save: SaveRecord<Record>,
    load: LoadRecord<Record>,
    record: &Record,
) -> Result<(), TestCaseError> {
    let folder = create_device_folder()?;
    let files = open_device_files(&folder)?;

    save(&files, record).map_err(fail)?;
    let reopened = open_device_files(&folder)?;
    let loaded = load(&reopened).map_err(fail)?;

    prop_assert_eq!(loaded.as_ref(), Some(record));
    Ok(())
}

pub fn check_last_save_wins<Record: PartialEq + Debug>(
    save: SaveRecord<Record>,
    load: LoadRecord<Record>,
    records: &[Record],
) -> Result<(), TestCaseError> {
    let folder = create_device_folder()?;
    let files = open_device_files(&folder)?;

    for record in records {
        save(&files, record).map_err(fail)?;
    }
    let loaded = load(&files).map_err(fail)?;

    prop_assert_eq!(loaded.as_ref(), records.last());
    Ok(())
}

pub fn check_only_its_file_is_written<Record: Serialize>(
    save: SaveRecord<Record>,
    record: &Record,
    file_name: &str,
) -> Result<(), TestCaseError> {
    let folder = create_device_folder()?;
    let files = open_device_files(&folder)?;

    save(&files, record).map_err(fail)?;

    let file_names = list_file_names(&folder.data_path)?;
    prop_assert_eq!(file_names, vec![file_name.to_owned()]);
    let stored_bytes =
        fs::read(folder.data_path.join(file_name)).map_err(fail)?;
    let stored_value: Value =
        serde_json::from_slice(&stored_bytes).map_err(fail)?;
    let expected_value = serde_json::to_value(record).map_err(fail)?;
    prop_assert_eq!(stored_value, expected_value);
    Ok(())
}

pub fn check_unrelated_files_load_nothing<Record: Debug>(
    load: LoadRecord<Record>,
    unrelated_name: &str,
    unrelated_content: &[u8],
) -> Result<(), TestCaseError> {
    let folder = create_device_folder()?;
    let files = open_device_files(&folder)?;
    let unrelated_path = folder.data_path.join(unrelated_name);
    fs::write(unrelated_path, unrelated_content).map_err(fail)?;

    let loaded = load(&files);

    prop_assert!(matches!(loaded, Ok(None)), "{:?}", loaded);
    Ok(())
}

pub fn check_half_written_file_is_refused<Record: Serialize + Debug>(
    load: LoadRecord<Record>,
    record: &Record,
    file_name: &str,
    cut: Index,
) -> Result<(), TestCaseError> {
    let folder = create_device_folder()?;
    let files = open_device_files(&folder)?;
    let whole_bytes = serde_json::to_vec_pretty(record).map_err(fail)?;
    let half_bytes = &whole_bytes[..cut.index(whole_bytes.len())];
    fs::write(folder.data_path.join(file_name), half_bytes).map_err(fail)?;

    let loaded = load(&files);

    prop_assert!(loaded.is_err(), "{:?}", loaded);
    Ok(())
}

pub fn check_wrong_shape_is_refused<Record: Debug>(
    load: LoadRecord<Record>,
    file_name: &str,
    wrong_shape: &Value,
) -> Result<(), TestCaseError> {
    let folder = create_device_folder()?;
    let files = open_device_files(&folder)?;
    let wrong_bytes = serde_json::to_vec(wrong_shape).map_err(fail)?;
    fs::write(folder.data_path.join(file_name), wrong_bytes).map_err(fail)?;

    let loaded = load(&files);

    prop_assert!(matches!(loaded, Err(NodeError::Json(_))), "{:?}", loaded);
    Ok(())
}
