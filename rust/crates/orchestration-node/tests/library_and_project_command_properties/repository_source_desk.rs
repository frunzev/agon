use std::fs;
use std::path::PathBuf;

use orchestration_hub::cached_clones::{
    cached_clone_folder, record_clone_address,
};
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::folder_desk::create_temporary_folder;
use crate::project_desk::create_project;
use crate::support::command_builders::PreparedWorkspace;
use crate::support::folder_checks::prepared_or_panic;
use crate::support::git_origin::{
    LOCAL_REPOSITORY_ADDRESS, create_local_origin, run_git,
};
use crate::support::test_device::{describe, read_text};

const REPOSITORY_CACHE_FOLDER: &str = "repository-cache";

#[derive(Debug)]
pub struct SourceDesk {
    pub prepared: PreparedWorkspace,
    pub project_id: String,
    origin: PathBuf,
    _origin_root: TempDir,
}

pub fn open_source_desk() -> Result<SourceDesk, String> {
    let prepared = prepared_or_panic();
    let repository = json!({
        "address": LOCAL_REPOSITORY_ADDRESS,
        "default_branch": "main",
        "agent_access": "read_only",
    });
    let project = create_project(&prepared, "sources", &[repository])?;
    let project_id = read_text(&project, "/id")?;
    let origin_root = create_temporary_folder()?;
    let origin = create_local_origin(origin_root.path())?;
    Ok(SourceDesk {
        prepared,
        project_id,
        origin,
        _origin_root: origin_root,
    })
}

impl SourceDesk {
    pub fn cached_clone(&self, address: &str) -> PathBuf {
        let cache_root = self
            .prepared
            .device
            .data_directory
            .path()
            .join(REPOSITORY_CACHE_FOLDER);
        cached_clone_folder(&cache_root, address)
    }

    pub fn cache_a_copy(&self, address: &str) -> Result<PathBuf, String> {
        let clone = self.cached_clone(address);
        let parent = clone.parent().ok_or("the clone has no parent")?;
        fs::create_dir_all(parent).map_err(describe)?;
        let origin_text = self.origin.display().to_string();
        let clone_text = clone.display().to_string();
        run_git(parent, &["clone", "--quiet", &origin_text, &clone_text])?;
        record_clone_address(&clone, address).map_err(describe)?;
        Ok(clone)
    }

    pub fn forget_the_copy(&self, address: &str) -> Result<(), String> {
        fs::remove_dir_all(self.cached_clone(address)).map_err(describe)
    }

    pub fn list_branches(
        &self,
        project_id: &str,
        address: &str,
        preferred_runner_id: Option<&str>,
    ) -> Result<Value, String> {
        self.prepared.device.run(&json!({
            "command": "list_repository_branches",
            "project_id": project_id,
            "repository_address": address,
            "preferred_runner_id": preferred_runner_id,
        }))
    }

    pub fn list_files(&self, runner_id: &str) -> Result<Value, String> {
        self.prepared.device.run(&json!({
            "command": "list_repository_files",
            "project_id": self.project_id,
            "repository_address": LOCAL_REPOSITORY_ADDRESS,
            "runner_id": runner_id,
            "branch": "main",
            "folder": "",
        }))
    }

    pub fn read_device_id(&self) -> Result<String, String> {
        let status =
            self.prepared.device.run(&json!({ "command": "status" }))?;
        read_text(&status, "/device_id")
    }
}
