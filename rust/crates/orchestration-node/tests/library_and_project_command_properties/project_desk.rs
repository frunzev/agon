use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::command_builders::PreparedWorkspace;

pub const PROJECT_CASES: u32 = 6;
pub const CANONICAL_HOST: &str = "github.com";
const ACCESS_LEVELS: [&str; 2] = ["read_only", "push_after_approval"];
const OWNER_PATTERN: &str = "[a-z][a-z0-9]{0,8}";
const SPELLINGS: [&str; 4] = [
    "https://github.com/{path}.git",
    "https://GitHub.com/{path}/",
    "git@github.com:{path}.git",
    "github.com/{path}",
];
const PATH_PLACEHOLDER: &str = "{path}";

#[derive(Clone, Debug)]
pub struct DrawnRepository {
    pub path: String,
    pub spelling: &'static str,
    pub agent_access: &'static str,
}

impl DrawnRepository {
    pub fn spelled_address(&self) -> String {
        self.spelling.replace(PATH_PLACEHOLDER, &self.path)
    }

    pub fn canonical_address(&self) -> String {
        format!("{CANONICAL_HOST}/{}", self.path)
    }

    pub fn input(&self, default_branch: &str) -> Value {
        json!({
            "address": self.spelled_address(),
            "default_branch": default_branch,
            "agent_access": self.agent_access,
        })
    }
}

pub fn repository_strategy() -> impl Strategy<Value = DrawnRepository> {
    (
        OWNER_PATTERN,
        OWNER_PATTERN,
        proptest::sample::select(SPELLINGS.to_vec()),
        proptest::sample::select(ACCESS_LEVELS.to_vec()),
    )
        .prop_map(|(owner, name, spelling, agent_access)| {
            DrawnRepository {
                path: format!("{owner}/{name}"),
                spelling,
                agent_access,
            }
        })
}

pub fn spelling_strategy() -> impl Strategy<Value = &'static str> {
    proptest::sample::select(SPELLINGS.to_vec())
}

pub fn create_project(
    prepared: &PreparedWorkspace,
    name: &str,
    repositories: &[Value],
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "create_project",
        "workspace_id": prepared.workspace_id,
        "name": name,
        "repositories": repositories,
    }))
}

pub fn list_projects(
    prepared: &PreparedWorkspace,
    workspace_id: &str,
) -> Result<Vec<Value>, String> {
    let listed = prepared.device.run(&json!({
        "command": "list_projects",
        "workspace_id": workspace_id,
    }))?;
    Ok(listed.as_array().cloned().unwrap_or_default())
}

pub fn list_repositories(
    prepared: &PreparedWorkspace,
    project_id: &Value,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "list_repositories",
        "project_id": project_id,
    }))
}

pub fn add_repository(
    prepared: &PreparedWorkspace,
    project_id: &Value,
    repository: &Value,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "create_repository",
        "project_id": project_id,
        "repository": repository,
    }))
}

pub fn remove_repository(
    prepared: &PreparedWorkspace,
    project_id: &Value,
    address: &str,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "remove_repository",
        "project_id": project_id,
        "address": address,
    }))
}

pub fn find_project_view(
    views: &[Value],
    project_id: &Value,
) -> Option<Value> {
    views
        .iter()
        .find(|view| &view["project"]["id"] == project_id)
        .cloned()
}
