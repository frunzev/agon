use std::fs;
use std::path::{Path, PathBuf};

use proptest::prelude::*;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::project_desk::create_project;
use crate::support::command_builders::PreparedWorkspace;
use crate::support::git_folders::create_named_git_folder;
use crate::support::git_origin::run_git;
use crate::support::test_device::describe;

pub const FOLDER_CASES: u32 = 4;
const TARGET_TEMPORARY_FOLDER: &str = env!("CARGO_TARGET_TMPDIR");
const DATA_FOLDER_NAME: &str = "library_and_project_command_properties";
const LOCAL_ADDRESS_PREFIX: &str = "local:";
const MAIN_FOLDER_NAME: &str = "main-checkout";
const WORKTREE_FOLDER_NAME: &str = "linked-checkout";
const MAIN_BRANCH: &str = "main";
const BRANCH_PATTERN: &str = "[a-z][a-z0-9]{0,8}(/[a-z0-9]{1,6})?";
const FOLDER_NAME_PATTERN: &str = "[a-z][a-z0-9-]{0,10}";

#[derive(Debug)]
pub struct LinkedWorktree {
    pub root: TempDir,
    pub main_checkout: PathBuf,
    pub worktree: PathBuf,
}

pub fn branch_strategy() -> impl Strategy<Value = String> {
    BRANCH_PATTERN.prop_filter("main is the first branch", |branch| {
        branch != MAIN_BRANCH
    })
}

pub fn folder_name_strategy() -> impl Strategy<Value = String> {
    FOLDER_NAME_PATTERN
}

pub fn create_temporary_folder() -> Result<TempDir, String> {
    let data_folder =
        PathBuf::from(TARGET_TEMPORARY_FOLDER).join(DATA_FOLDER_NAME);
    fs::create_dir_all(&data_folder).map_err(describe)?;
    let root = TempDir::new_in(&data_folder).map_err(describe)?;
    let canonical_root = root.path().canonicalize().map_err(describe)?;
    if canonical_root != root.path() {
        return Err(format!("{} is not canonical", root.path().display()));
    }
    Ok(root)
}

pub fn create_linked_worktree(branch: &str) -> Result<LinkedWorktree, String> {
    let root = create_temporary_folder()?;
    let main_checkout =
        create_named_git_folder(root.path(), MAIN_FOLDER_NAME, MAIN_BRANCH)?;
    let worktree = root.path().join(WORKTREE_FOLDER_NAME);
    let worktree_text = worktree.display().to_string();
    run_git(
        &main_checkout,
        &["worktree", "add", "--quiet", "-b", branch, &worktree_text],
    )?;
    Ok(LinkedWorktree {
        root,
        main_checkout,
        worktree,
    })
}

pub fn render_local_address(device_id: &str, folder: &Path) -> String {
    format!("{LOCAL_ADDRESS_PREFIX}{device_id}:{}", folder.display())
}

pub fn create_folder_project(
    prepared: &PreparedWorkspace,
    address: &str,
) -> Result<Value, String> {
    let repository = json!({
        "address": address,
        "default_branch": MAIN_BRANCH,
        "agent_access": "read_only",
    });
    create_project(prepared, "folder", &[repository])
}
