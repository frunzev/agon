use std::collections::BTreeMap;

use orchestration_core::library::{Rule, Skill, SkillChange};
use orchestration_core::task::Task;
use orchestration_core::workflow::{Workflow, WorkflowAgent};
use orchestration_core::yaml_text::render_yaml_scalar;
use orchestration_security::sealing::{WorkspaceKey, open_text, seal_text};

use super::sealed_document::read_step_sealed_texts;
use super::workspace_keyring::WorkspaceKeyring;
use crate::node_error::NodeError;

pub fn seal_task(
    workspace_key: &WorkspaceKey,
    task: &Task,
) -> Result<Task, NodeError> {
    Ok(Task {
        details: seal_text(workspace_key, &task.details)?,
        ..task.clone()
    })
}

pub fn open_task(
    keyring: &WorkspaceKeyring,
    task: &Task,
) -> Result<Task, NodeError> {
    Ok(Task {
        details: keyring.open_text(&task.details)?,
        ..task.clone()
    })
}

pub fn seal_skill(
    workspace_key: &WorkspaceKey,
    skill: &Skill,
) -> Result<Skill, NodeError> {
    let mut sealed_history = Vec::new();
    for change in &skill.history {
        let replaced = &change.replaced_instructions;
        sealed_history.push(SkillChange {
            replaced_instructions: seal_text(workspace_key, replaced)?,
            ..change.clone()
        });
    }
    Ok(Skill {
        instructions: seal_text(workspace_key, &skill.instructions)?,
        history: sealed_history,
        ..skill.clone()
    })
}

pub fn open_skill(
    keyring: &WorkspaceKeyring,
    skill: &Skill,
) -> Result<Skill, NodeError> {
    let mut opened_history = Vec::new();
    for change in &skill.history {
        let replaced = &change.replaced_instructions;
        opened_history.push(SkillChange {
            replaced_instructions: keyring.open_text(replaced)?,
            ..change.clone()
        });
    }
    Ok(Skill {
        instructions: keyring.open_text(&skill.instructions)?,
        history: opened_history,
        ..skill.clone()
    })
}

pub fn seal_rule(
    workspace_key: &WorkspaceKey,
    rule: &Rule,
) -> Result<Rule, NodeError> {
    Ok(Rule {
        details: seal_text(workspace_key, &rule.details)?,
        ..rule.clone()
    })
}

pub fn open_rule(
    keyring: &WorkspaceKeyring,
    rule: &Rule,
) -> Result<Rule, NodeError> {
    Ok(Rule {
        details: keyring.open_text(&rule.details)?,
        ..rule.clone()
    })
}

pub fn seal_workflow(
    workspace_key: &WorkspaceKey,
    workflow: &Workflow,
) -> Result<Workflow, NodeError> {
    let mut sealed_agents = Vec::new();
    for agent in &workflow.agents {
        sealed_agents.push(WorkflowAgent {
            task: seal_text(workspace_key, &agent.task)?,
            ..agent.clone()
        });
    }
    Ok(Workflow {
        agents: sealed_agents,
        ..workflow.clone()
    })
}

pub fn reseal_workflow(
    workspace_key: &WorkspaceKey,
    workflow: &Workflow,
    stored_workflow: &Workflow,
) -> Result<Workflow, NodeError> {
    let signed_tasks = read_signed_step_tasks(stored_workflow);
    let mut sealed_agents = Vec::new();
    for agent in &workflow.agents {
        let kept_tasks = KeptStepTasks {
            signed: signed_tasks.get(&render_yaml_scalar(&agent.name)),
            stored: find_stored_task(stored_workflow, agent),
        };
        let task = reseal_step_task(workspace_key, agent, &kept_tasks)?;
        sealed_agents.push(WorkflowAgent {
            task,
            ..agent.clone()
        });
    }
    Ok(Workflow {
        agents: sealed_agents,
        ..workflow.clone()
    })
}

struct KeptStepTasks<'kept> {
    signed: Option<&'kept String>,
    stored: Option<&'kept String>,
}

fn read_signed_step_tasks(
    stored_workflow: &Workflow,
) -> BTreeMap<String, String> {
    match &stored_workflow.signature {
        Some(signature) => read_step_sealed_texts(&signature.signed_document),
        None => BTreeMap::new(),
    }
}

fn find_stored_task<'stored>(
    stored_workflow: &'stored Workflow,
    agent: &WorkflowAgent,
) -> Option<&'stored String> {
    let stored_agent = stored_workflow
        .agents
        .iter()
        .find(|stored_agent| stored_agent.id == agent.id);
    stored_agent.map(|stored_agent| &stored_agent.task)
}

fn reseal_step_task(
    workspace_key: &WorkspaceKey,
    agent: &WorkflowAgent,
    kept_tasks: &KeptStepTasks<'_>,
) -> Result<String, NodeError> {
    for kept_task in [kept_tasks.signed, kept_tasks.stored] {
        if let Some(kept_task) = kept_task
            && seals_same_text(workspace_key, kept_task, &agent.task)
        {
            return Ok(kept_task.clone());
        }
    }
    Ok(seal_text(workspace_key, &agent.task)?)
}

fn seals_same_text(
    workspace_key: &WorkspaceKey,
    sealed_text: &str,
    plain_text: &str,
) -> bool {
    match open_text(workspace_key, sealed_text) {
        Ok(opened_text) => opened_text == plain_text,
        Err(_) => false,
    }
}

pub fn open_workflow(
    keyring: &WorkspaceKeyring,
    workflow: &Workflow,
) -> Result<Workflow, NodeError> {
    let mut opened_agents = Vec::new();
    for agent in &workflow.agents {
        opened_agents.push(WorkflowAgent {
            task: keyring.open_text(&agent.task)?,
            ..agent.clone()
        });
    }
    Ok(Workflow {
        agents: opened_agents,
        ..workflow.clone()
    })
}
