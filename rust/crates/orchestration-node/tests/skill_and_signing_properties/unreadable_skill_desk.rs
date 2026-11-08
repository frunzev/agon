use orchestration_core::library::Skill;
use serde_json::{Value, json};
use uuid::Uuid;

use crate::support::command_builders::create_skill_command;
use crate::support::runner_access::ClaimedRun;
use crate::support::server_access::use_server_at;
use crate::support::test_device::read_text;
use crate::unreadable_approval_desk::FIRST_INSTRUCTIONS;

pub const UNREADABLE_PROBLEM: &str =
    "the sealed text cannot be opened with any workspace key";
const AUTOMATIC_IMPROVEMENT: &str = "auto";

#[derive(Debug)]
pub struct CreatedSkill {
    pub id: String,
    pub name: String,
}

pub fn create_automatic_skill(
    claimed: &ClaimedRun,
) -> Result<CreatedSkill, String> {
    let prepared = &claimed.prepared;
    let mut command =
        create_skill_command(&prepared.workspace_id, FIRST_INSTRUCTIONS);
    let name = format!("skill-{}", Uuid::new_v4().simple());
    command["name"] = json!(name);
    command["improvement"] = json!(AUTOMATIC_IMPROVEMENT);
    let skill = prepared.device.run(&command)?;
    let id = read_text(&skill, "/id")?;
    Ok(CreatedSkill { id, name })
}

pub fn list_skills(claimed: &ClaimedRun) -> Result<Vec<Value>, String> {
    let prepared = &claimed.prepared;
    let listed = prepared.device.run(&json!({
        "command": "list_skills",
        "workspace_id": prepared.workspace_id,
    }))?;
    Ok(listed.as_array().cloned().unwrap_or_default())
}

pub fn find_listed_skill(listed: &[Value], skill_id: &str) -> Option<Value> {
    let wanted = json!(skill_id);
    listed.iter().find(|skill| skill["id"] == wanted).cloned()
}

pub fn read_stored_skill(
    claimed: &ClaimedRun,
    skill_id: &str,
) -> Result<Option<Skill>, String> {
    let identity = claimed.prepared.device.load_identity()?;
    let stored =
        use_server_at(&claimed.prepared.server.address, async |server| {
            server.signed(&identity).list_skills().await
        })?;
    let wanted =
        Uuid::parse_str(skill_id).map_err(|problem| problem.to_string())?;
    Ok(stored.into_iter().find(|skill| skill.id.0 == wanted))
}

pub fn update_skill(
    claimed: &ClaimedRun,
    skill: &CreatedSkill,
    instructions: &str,
) -> Result<Value, String> {
    let prepared = &claimed.prepared;
    let mut command =
        create_skill_command(&prepared.workspace_id, instructions);
    command["command"] = json!("update_skill");
    command["skill_id"] = json!(skill.id);
    command["name"] = json!(skill.name);
    command["improvement"] = json!(AUTOMATIC_IMPROVEMENT);
    prepared.device.run(&command)
}

pub fn undo_skill_change(
    claimed: &ClaimedRun,
    skill_id: &str,
) -> Result<Value, String> {
    claimed.prepared.device.run(&json!({
        "command": "undo_skill_change",
        "skill_id": skill_id,
    }))
}
