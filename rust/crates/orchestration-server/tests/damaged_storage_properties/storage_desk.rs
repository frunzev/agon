use std::fmt::Display;
use std::fs;
use std::path::PathBuf;

use orchestration_server::StateStorage;
use proptest::prelude::*;
use tempfile::TempDir;

const MOST_DAMAGED_BYTES: usize = 96;
const DAMAGED_TEXT_PATTERN: &str = "\\PC{0,40}";

#[derive(Debug)]
pub struct StorageDesk {
    pub data_directory: TempDir,
    pub storage: StateStorage,
}

pub fn fail(problem: impl Display) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

pub fn open_storage_desk() -> Result<StorageDesk, TestCaseError> {
    let data_directory = TempDir::new().map_err(fail)?;
    let storage = StateStorage::new(data_directory.path().to_path_buf());
    Ok(StorageDesk {
        data_directory,
        storage,
    })
}

impl StorageDesk {
    pub fn path_of(&self, file_name: &str) -> PathBuf {
        self.data_directory.path().join(file_name)
    }

    pub fn write_file(
        &self,
        file_name: &str,
        file_bytes: &[u8],
    ) -> Result<(), TestCaseError> {
        fs::write(self.path_of(file_name), file_bytes).map_err(fail)
    }

    pub fn put_folder_at(
        &self,
        file_name: &str,
        folder_depth: usize,
    ) -> Result<(), TestCaseError> {
        let mut folder = self.path_of(file_name);
        for depth in 0..folder_depth {
            folder = folder.join(depth.to_string());
        }
        fs::create_dir_all(folder).map_err(fail)
    }
}

pub fn damaged_bytes_strategy() -> impl Strategy<Value = Vec<u8>> {
    let damaged_text = DAMAGED_TEXT_PATTERN.prop_map(String::into_bytes);
    let damaged_bytes =
        prop::collection::vec(any::<u8>(), 0..MOST_DAMAGED_BYTES);
    prop_oneof![damaged_text, damaged_bytes]
}
