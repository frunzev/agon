use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::subsequence;
use serde_json::{Value, json};
use uuid::Uuid;

use crate::support::command_builders::{
    PreparedWorkspace, create_skill_command, two_step_workflow_command,
};
use crate::support::test_device::read_text;
use crate::workflow_desk::find_workflow_view;

pub const SKILL_COUNT: usize = 3;
pub const STEP_TASK_PATTERN: &str = "[a-z]{16,22}";
pub const AGENT_COUNT: usize = 2;
pub const MOST_WORKFLOWS: usize = 3;

pub type SkillChoices = Vec<Vec<usize>>;

pub fn skill_choices() -> impl Strategy<Value = SkillChoices> {
    let positions: Vec<usize> = (0..SKILL_COUNT).collect();
    vec(subsequence(positions, 0..=SKILL_COUNT), AGENT_COUNT)
}

pub fn create_skills(
    prepared: &PreparedWorkspace,
) -> Result<Vec<String>, String> {
    let mut skill_ids = Vec::new();
    for _ in 0..SKILL_COUNT {
        let mut command =
            create_skill_command(&prepared.workspace_id, "Write it well");
        let unique_name = format!("skill-{}", Uuid::new_v4().simple());
        command["name"] = json!(unique_name);
        let skill = prepared.device.run(&command)?;
        skill_ids.push(read_text(&skill, "/id")?);
    }
    Ok(skill_ids)
}

pub fn create_skilled_workflow(
    prepared: &PreparedWorkspace,
    tasks: (&str, &str),
    skills_per_agent: &[Vec<String>],
) -> Result<Value, String> {
    let (plan_task, build_task) = tasks;
    let mut command = two_step_workflow_command(
        &prepared.workspace_id,
        plan_task,
        build_task,
    );
    for (position, skills) in skills_per_agent.iter().enumerate() {
        command["agents"][position]["skills"] = json!(skills);
    }
    let created = prepared.device.run(&command)?;
    Ok(created["workflow"].clone())
}

pub fn pick_skills(
    skill_ids: &[String],
    choices: &SkillChoices,
) -> Vec<Vec<String>> {
    let mut skills_per_agent = Vec::new();
    for agent_choices in choices {
        let mut agent_skills = Vec::new();
        for position in agent_choices {
            agent_skills.push(skill_ids[*position].clone());
        }
        skills_per_agent.push(agent_skills);
    }
    skills_per_agent
}

pub fn delete_skill(
    prepared: &PreparedWorkspace,
    skill_id: &str,
) -> Result<Value, String> {
    prepared
        .device
        .run(&json!({ "command": "delete_skill", "skill_id": skill_id }))
}

pub fn listed_view(
    prepared: &PreparedWorkspace,
    workflow: &Value,
) -> Result<Value, String> {
    find_workflow_view(prepared, &workflow["id"])?
        .ok_or_else(|| "the workflow is listed".to_owned())
}

pub fn without(skills: &[String], removed: &str) -> Vec<String> {
    let mut kept = Vec::new();
    for skill in skills {
        if skill != removed {
            kept.push(skill.clone());
        }
    }
    kept
}
