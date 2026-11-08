use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::command_builders::PreparedWorkspace;
use crate::support::test_device::{fail, read_text};

pub const FILE_LISTING_NAMES: [&str; 2] =
    ["list_repository_files", "read_repository_file"];
pub const ADDRESS_PATTERN: &str = "[a-z]{1,8}\\.test/[a-z]{1,8}/[a-z]{1,8}";

pub fn file_question(
    command: &str,
    project_id: &str,
    address: &str,
    runner_id: &str,
) -> Value {
    let mut question = json!({
        "command": command,
        "project_id": project_id,
        "repository_address": address,
        "runner_id": runner_id,
        "branch": "main",
    });
    if command == FILE_LISTING_NAMES[0] {
        question["folder"] = json!("");
    } else {
        question["path"] = json!("README.md");
    }
    question
}

pub fn list_branches(
    project_id: &str,
    address: &str,
    preferred: &Value,
) -> Value {
    json!({
        "command": "list_repository_branches",
        "project_id": project_id,
        "repository_address": address,
        "preferred_runner_id": preferred,
    })
}

pub fn read_project_address(
    prepared: &PreparedWorkspace,
) -> Result<String, TestCaseError> {
    let views = prepared
        .device
        .run(&json!({
            "command": "list_projects",
            "workspace_id": prepared.workspace_id,
        }))
        .map_err(fail)?;
    read_text(&views, "/0/project/repositories/0/address").map_err(fail)
}

pub fn file_command_strategy() -> impl Strategy<Value = &'static str> {
    prop::sample::select(FILE_LISTING_NAMES.to_vec())
}
