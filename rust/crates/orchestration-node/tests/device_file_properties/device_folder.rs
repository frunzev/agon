use std::fs;
use std::path::{Path, PathBuf};

use orchestration_node::device_files::DeviceFiles;
use proptest::test_runner::TestCaseError;
use tempfile::{Builder, TempDir};

use crate::support::test_device::fail;

const TARGET_TEMPORARY_FOLDER: &str = env!("CARGO_TARGET_TMPDIR");
const CASE_FOLDER_PREFIX: &str = "device-files-";
const DATA_FOLDER_NAME: &str = "data";
const OUTSIDE_FOLDER_NAME: &str = "outside";
const UNFINISHED_FILE_SUFFIX: &str = ".incomplete";
pub const ACCOUNT_FILE_NAME: &str = "account.json";
pub const PENDING_JOIN_FILE_NAME: &str = "pending-join.json";
pub const SERVER_FILE_NAME: &str = "app-server.json";
pub const HOSTED_SERVER_FILE_NAME: &str = "hosted-app-server.json";
pub const SERVER_GROUP_FILE_NAME: &str = "server-group.json";
pub const AGENT_PLACE_FILE_NAME: &str = "agent-place.json";
pub const DEVICE_RECORD_NAMES: [&str; 4] = [
    ACCOUNT_FILE_NAME,
    PENDING_JOIN_FILE_NAME,
    SERVER_FILE_NAME,
    SERVER_GROUP_FILE_NAME,
];
pub const RECORD_FILE_NAMES: [&str; 6] = [
    ACCOUNT_FILE_NAME,
    PENDING_JOIN_FILE_NAME,
    SERVER_FILE_NAME,
    HOSTED_SERVER_FILE_NAME,
    SERVER_GROUP_FILE_NAME,
    AGENT_PLACE_FILE_NAME,
];

#[derive(Debug)]
pub struct DeviceFolder {
    pub data_path: PathBuf,
    pub outside_path: PathBuf,
    root: TempDir,
}

impl DeviceFolder {
    pub fn root_path(&self) -> &Path {
        self.root.path()
    }
}

pub fn create_device_folder() -> Result<DeviceFolder, TestCaseError> {
    fs::create_dir_all(TARGET_TEMPORARY_FOLDER).map_err(fail)?;
    let root = Builder::new()
        .prefix(CASE_FOLDER_PREFIX)
        .tempdir_in(TARGET_TEMPORARY_FOLDER)
        .map_err(fail)?;
    let data_path = root.path().join(DATA_FOLDER_NAME);
    let outside_path = root.path().join(OUTSIDE_FOLDER_NAME);
    fs::create_dir(&outside_path).map_err(fail)?;
    Ok(DeviceFolder {
        data_path,
        outside_path,
        root,
    })
}

pub fn open_device_files(
    folder: &DeviceFolder,
) -> Result<DeviceFiles, TestCaseError> {
    DeviceFiles::open(&folder.data_path).map_err(fail)
}

pub fn list_file_names(folder: &Path) -> Result<Vec<String>, TestCaseError> {
    let mut names = Vec::new();
    for entry in fs::read_dir(folder).map_err(fail)? {
        let entry = entry.map_err(fail)?;
        names.push(entry.file_name().to_string_lossy().into_owned());
    }
    names.sort();
    Ok(names)
}

pub fn list_unfinished_file_names(
    folder: &Path,
) -> Result<Vec<String>, TestCaseError> {
    let mut unfinished_names = Vec::new();
    for name in list_file_names(folder)? {
        if name.ends_with(UNFINISHED_FILE_SUFFIX) {
            unfinished_names.push(name);
        }
    }
    Ok(unfinished_names)
}

#[cfg(unix)]
pub fn link_to_outside_file(
    folder: &DeviceFolder,
    link_name: &str,
    outside_content: &[u8],
) -> Result<PathBuf, TestCaseError> {
    let outside_file = folder.outside_path.join(link_name);
    fs::write(&outside_file, outside_content).map_err(fail)?;
    let link_path = folder.data_path.join(link_name);
    std::os::unix::fs::symlink(&outside_file, &link_path).map_err(fail)?;
    Ok(outside_file)
}
