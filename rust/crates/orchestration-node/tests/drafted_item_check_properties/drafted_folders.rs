use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

use proptest::prelude::*;
use tempfile::{Builder, TempDir};

use crate::support::git_origin::run_git;
use crate::support::test_device::fail;

const TARGET_TEMPORARY_FOLDER: &str = env!("CARGO_TARGET_TMPDIR");
const CASE_FOLDER_PREFIX: &str = "drafted-folders-";
const GIT_FOLDER_NAME: &str = ".git";
const PLAIN_FOLDER_NAME: &str = "plain";
const FILE_NAME_PATTERN: &str = "[a-z][a-z0-9_-]{0,8}\\.(txt|md|rs)";
const MOST_FILES: usize = 4;
const LONGEST_CONTENT: usize = 64;

pub type FolderSnapshot = BTreeMap<PathBuf, Option<Vec<u8>>>;
pub type PlannedFiles = BTreeMap<String, Vec<u8>>;

pub fn planned_files_strategy() -> impl Strategy<Value = PlannedFiles> {
    let content = proptest::collection::vec(any::<u8>(), 0..LONGEST_CONTENT);
    proptest::collection::btree_map(FILE_NAME_PATTERN, content, 0..MOST_FILES)
}

pub fn create_case_folder() -> Result<TempDir, TestCaseError> {
    fs::create_dir_all(TARGET_TEMPORARY_FOLDER).map_err(fail)?;
    Builder::new()
        .prefix(CASE_FOLDER_PREFIX)
        .tempdir_in(TARGET_TEMPORARY_FOLDER)
        .map_err(fail)
}

pub fn create_plain_folder(
    parent: &Path,
    planned_files: &PlannedFiles,
) -> Result<PathBuf, TestCaseError> {
    let folder = parent.join(PLAIN_FOLDER_NAME);
    fs::create_dir_all(&folder).map_err(fail)?;
    for (name, content) in planned_files {
        fs::write(folder.join(name), content).map_err(fail)?;
    }
    Ok(folder)
}

pub fn create_empty_repository(
    parent: &Path,
    branch: &str,
) -> Result<PathBuf, TestCaseError> {
    let folder = parent.join(PLAIN_FOLDER_NAME);
    fs::create_dir_all(&folder).map_err(fail)?;
    let initial_branch = format!("--initial-branch={branch}");
    run_git(&folder, &["init", "--quiet", &initial_branch]).map_err(fail)?;
    Ok(folder)
}

pub fn has_own_git(folder: &Path) -> bool {
    folder.join(GIT_FOLDER_NAME).exists()
}

pub fn snapshot_folder(
    folder: &Path,
) -> Result<FolderSnapshot, TestCaseError> {
    let mut snapshot = FolderSnapshot::new();
    let mut waiting_folders = vec![folder.to_path_buf()];
    while let Some(current_folder) = waiting_folders.pop() {
        for entry in fs::read_dir(&current_folder).map_err(fail)? {
            let entry_path = entry.map_err(fail)?.path();
            let relative_path =
                entry_path.strip_prefix(folder).map_err(fail)?.to_path_buf();
            if entry_path.is_dir() {
                waiting_folders.push(entry_path);
                snapshot.insert(relative_path, None);
            } else {
                let content = fs::read(&entry_path).map_err(fail)?;
                snapshot.insert(relative_path, Some(content));
            }
        }
    }
    Ok(snapshot)
}
