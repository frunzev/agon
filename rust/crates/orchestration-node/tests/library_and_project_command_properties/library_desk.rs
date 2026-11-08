use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::command_builders::PreparedWorkspace;

pub const LIBRARY_CASES: u32 = 6;
pub const FOREIGN_WORKSPACE_ID: &str = "00000000-0000-0000-0000-0000000f0e19";
const VALID_NAME_PATTERN: &str = "[a-z][a-z0-9-]{0,39}";
const FREE_TEXT_PATTERN: &str = "\\PC{0,40}";
const WORDED_TITLE_PATTERN: &str = "[A-Za-z][A-Za-z ]{0,30}";
const SKILL_USAGES: [&str; 2] = ["automatic", "when_chosen"];
const SKILL_IMPROVEMENTS: [&str; 3] = ["never", "ask_me", "auto"];

#[derive(Clone, Debug)]
pub struct SkillFields {
    pub name: String,
    pub summary: String,
    pub instructions: String,
    pub usage: &'static str,
    pub improvement: &'static str,
}

pub fn valid_name_strategy() -> impl Strategy<Value = String> {
    VALID_NAME_PATTERN
}

pub fn free_text_strategy() -> impl Strategy<Value = String> {
    FREE_TEXT_PATTERN
}

pub fn worded_title_strategy() -> impl Strategy<Value = String> {
    WORDED_TITLE_PATTERN
}

pub fn skill_fields_strategy() -> impl Strategy<Value = SkillFields> {
    (
        valid_name_strategy(),
        free_text_strategy(),
        free_text_strategy(),
        proptest::sample::select(SKILL_USAGES.to_vec()),
        proptest::sample::select(SKILL_IMPROVEMENTS.to_vec()),
    )
        .prop_map(|(name, summary, instructions, usage, improvement)| {
            SkillFields {
                name,
                summary,
                instructions,
                usage,
                improvement,
            }
        })
}

pub fn everywhere_scope() -> Value {
    json!({
        "workspaces": { "kind": "all_workspaces" },
        "projects": { "kind": "all_projects" },
    })
}

pub fn workspace_scope(workspace_id: &str) -> Value {
    json!({
        "workspaces": {
            "kind": "only_workspaces",
            "workspaces": [workspace_id],
        },
        "projects": { "kind": "all_projects" },
    })
}

pub fn skill_command(
    prepared: &PreparedWorkspace,
    fields: &SkillFields,
    scope: &Value,
) -> Value {
    json!({
        "workspace_id": prepared.workspace_id,
        "name": fields.name,
        "summary": fields.summary,
        "instructions": fields.instructions,
        "scope": scope,
        "usage": fields.usage,
        "improvement": fields.improvement,
    })
}

pub fn create_skill(
    prepared: &PreparedWorkspace,
    fields: &SkillFields,
    scope: &Value,
) -> Result<Value, String> {
    let mut command = skill_command(prepared, fields, scope);
    command["command"] = json!("create_skill");
    prepared.device.run(&command)
}

pub fn update_skill(
    prepared: &PreparedWorkspace,
    skill_id: &Value,
    fields: &SkillFields,
) -> Result<Value, String> {
    let mut command = skill_command(prepared, fields, &everywhere_scope());
    command["command"] = json!("update_skill");
    command["skill_id"] = skill_id.clone();
    prepared.device.run(&command)
}

pub fn create_rule(
    prepared: &PreparedWorkspace,
    title: &str,
    details: &str,
    scope: &Value,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "create_rule",
        "workspace_id": prepared.workspace_id,
        "title": title,
        "details": details,
        "scope": scope,
    }))
}

pub fn update_rule(
    prepared: &PreparedWorkspace,
    rule_id: &Value,
    title: &str,
    details: &str,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "update_rule",
        "workspace_id": prepared.workspace_id,
        "rule_id": rule_id,
        "title": title,
        "details": details,
        "scope": everywhere_scope(),
    }))
}

pub fn list_library(
    prepared: &PreparedWorkspace,
    command_name: &str,
) -> Result<Vec<Value>, String> {
    let listed = prepared.device.run(&json!({
        "command": command_name,
        "workspace_id": prepared.workspace_id,
    }))?;
    Ok(listed.as_array().cloned().unwrap_or_default())
}

pub fn find_listed(entries: &[Value], entry_id: &Value) -> Option<Value> {
    entries
        .iter()
        .find(|entry| &entry["id"] == entry_id)
        .cloned()
}

pub fn run_command(
    prepared: &PreparedWorkspace,
    command_name: &str,
    field_name: &str,
    field_value: &Value,
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": command_name,
        field_name: field_value,
    }))
}
