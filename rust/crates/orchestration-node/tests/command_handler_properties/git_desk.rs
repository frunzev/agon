use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};

use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::handler_desk::shared_workspace;
use crate::support::git_origin::run_git;
use crate::support::test_device::{describe, fail};

pub type FolderFiles = BTreeMap<String, String>;

pub const GIT_CASES: u32 = 6;
pub const GIT_FOLDER_NAME: &str = ".git";
pub const STARTED_BRANCH: &str = "main";
pub const UNBORN_HEAD: &str = "unborn";
const CASE_ROOT: &str = env!("CARGO_TARGET_TMPDIR");
const CASE_FOLDER_PREFIX: &str = "command-handler-git-";
const GUARD_FOLDER_NAME: &str = "guard";
const GUARD_FILE_NAME: &str = "guard.txt";
const GUARD_FILE_TEXT: &str = "outside the chosen folder";
const FILE_NAME_PATTERN: &str = "([a-z]{1,4}/)?[a-z][a-z0-9]{0,6}\\.txt";
const FILE_TEXT_PATTERN: &str = "[a-z \u{e9}]{0,20}";
const FOLDER_NAME_PATTERN: &str =
    "[a-z\u{e9}\u{4e2d}-][a-z0-9 \u{e9}\u{4e2d}-]{0,8}[a-z0-9\u{e9}]";
const MOST_FILES: usize = 4;

#[derive(Debug)]
pub struct GuardedFolder {
    _case_root: TempDir,
    pub guard: PathBuf,
    pub chosen: PathBuf,
}

#[derive(Clone, Copy, Debug)]
pub enum GuardHistory {
    Committed,
    Unborn,
}

#[derive(Debug, PartialEq, Eq)]
pub struct RepositoryState {
    pub head_reference: String,
    pub head_commit: String,
    pub commit_count: String,
    pub index: String,
}

pub fn folder_files_strategy() -> impl Strategy<Value = FolderFiles> {
    prop::collection::btree_map(
        FILE_NAME_PATTERN,
        FILE_TEXT_PATTERN,
        0..=MOST_FILES,
    )
}

pub fn folder_name_strategy() -> impl Strategy<Value = String> {
    FOLDER_NAME_PATTERN
}

pub fn prepare_guarded_folder(
    chosen_name: &str,
    guard_history: GuardHistory,
) -> Result<GuardedFolder, String> {
    fs::create_dir_all(CASE_ROOT).map_err(describe)?;
    let case_root = tempfile::Builder::new()
        .prefix(CASE_FOLDER_PREFIX)
        .tempdir_in(CASE_ROOT)
        .map_err(describe)?;
    let guard = case_root.path().join(GUARD_FOLDER_NAME);
    fs::create_dir_all(&guard).map_err(describe)?;
    run_git(&guard, &["init", "--quiet", "--initial-branch=trunk"])?;
    fs::write(guard.join(GUARD_FILE_NAME), GUARD_FILE_TEXT)
        .map_err(describe)?;
    if matches!(guard_history, GuardHistory::Committed) {
        run_git(&guard, &["add", "--all"])?;
        run_git(&guard, &["commit", "--quiet", "--message", "Guard"])?;
    }
    let chosen = guard.join(chosen_name);
    fs::create_dir_all(&chosen).map_err(describe)?;
    Ok(GuardedFolder {
        _case_root: case_root,
        guard,
        chosen,
    })
}

pub fn guard_committed(
    chosen_name: &str,
) -> Result<GuardedFolder, TestCaseError> {
    prepare_guarded_folder(chosen_name, GuardHistory::Committed).map_err(fail)
}

pub fn guard_unborn(
    chosen_name: &str,
) -> Result<GuardedFolder, TestCaseError> {
    prepare_guarded_folder(chosen_name, GuardHistory::Unborn).map_err(fail)
}

pub fn write_files(folder: &Path, files: &FolderFiles) -> Result<(), String> {
    for (file_name, file_text) in files {
        let file_path = folder.join(file_name);
        if let Some(parent) = file_path.parent() {
            fs::create_dir_all(parent).map_err(describe)?;
        }
        fs::write(file_path, file_text).map_err(describe)?;
    }
    Ok(())
}

pub fn read_repository_state(folder: &Path) -> RepositoryState {
    let head_reference =
        run_git(folder, &["symbolic-ref", "HEAD"]).unwrap_or_default();
    let head_commit =
        run_git(folder, &["rev-parse", "--verify", "--quiet", "HEAD"])
            .unwrap_or_else(|_| UNBORN_HEAD.to_owned());
    let commit_count =
        run_git(folder, &["rev-list", "--count", "--all"]).unwrap_or_default();
    let index = run_git(folder, &["ls-files", "--stage"]).unwrap_or_default();
    RepositoryState {
        head_reference,
        head_commit,
        commit_count,
        index,
    }
}

pub fn read_guard_file(guarded: &GuardedFolder) -> Result<String, String> {
    fs::read_to_string(guarded.guard.join(GUARD_FILE_NAME)).map_err(describe)
}

pub fn list_committed_files(folder: &Path) -> Result<Vec<String>, String> {
    let listed = run_git(folder, &["ls-tree", "-r", "--name-only", "HEAD"])?;
    let mut committed_files = Vec::new();
    for file_name in listed.lines() {
        committed_files.push(file_name.to_owned());
    }
    Ok(committed_files)
}

pub fn check_chosen_folder(folder: &Path) -> Result<Value, String> {
    let prepared = shared_workspace().map_err(|error| error.to_string())?;
    prepared.device.run(&json!({
        "command": "check_local_folder",
        "path": folder.display().to_string(),
    }))
}

pub fn read_git_problem(folder: &Path) -> String {
    check_chosen_folder(folder).err().unwrap_or_default()
}

pub fn read_started_flag(checked: &Value) -> Option<bool> {
    checked["has_started_git"].as_bool()
}
