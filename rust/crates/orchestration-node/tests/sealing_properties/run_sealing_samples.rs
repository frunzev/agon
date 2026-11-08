use orchestration_core::run::{EarlierStepRound, Run, RunStep, StepStatus};
use orchestration_node::content_sealing::{seal_chat_message, seal_log_line};
use orchestration_security::sealing::{WorkspaceKey, seal_text};

use crate::support::entity_strategies::{sample_run, sample_step_with_result};
use crate::support::test_device::describe;

fn earlier_round(result: Option<String>) -> EarlierStepRound {
    EarlierStepRound {
        status: StepStatus::Done,
        started_at: None,
        finished_at: None,
        result,
        outcome: None,
    }
}

pub fn plain_run_with_steps(texts: &[String], results: &[String]) -> Run {
    let mut run = sample_run(texts);
    for (position, result) in results.iter().enumerate() {
        let mut step = sample_step_with_result(position, result);
        step.earlier_rounds
            .push(earlier_round(Some(result.clone())));
        step.earlier_rounds.push(earlier_round(None));
        run.steps.push(step);
    }
    let mut waiting_step = sample_step_with_result(results.len(), "");
    waiting_step.result = None;
    waiting_step.status = StepStatus::Waiting;
    run.steps.push(waiting_step);
    run
}

fn seal_optional_text(
    workspace_key: &WorkspaceKey,
    text: Option<&String>,
) -> Result<Option<String>, String> {
    let Some(text) = text else {
        return Ok(None);
    };
    let sealed_text = seal_text(workspace_key, text).map_err(describe)?;
    Ok(Some(sealed_text))
}

fn seal_step(
    workspace_key: &WorkspaceKey,
    step: &RunStep,
) -> Result<RunStep, String> {
    let mut sealed_step = step.clone();
    sealed_step.result =
        seal_optional_text(workspace_key, step.result.as_ref())?;
    for round in &mut sealed_step.earlier_rounds {
        round.result =
            seal_optional_text(workspace_key, round.result.as_ref())?;
    }
    Ok(sealed_step)
}

pub fn seal_whole_run(
    workspace_key: &WorkspaceKey,
    run: &Run,
) -> Result<Run, String> {
    let mut sealed_run = run.clone();
    sealed_run.log.clear();
    for line in &run.log {
        let sealed_line =
            seal_log_line(workspace_key, line).map_err(describe)?;
        sealed_run.log.push(sealed_line);
    }
    sealed_run.chat.clear();
    for message in &run.chat {
        let sealed_message =
            seal_chat_message(workspace_key, message).map_err(describe)?;
        sealed_run.chat.push(sealed_message);
    }
    sealed_run.steps.clear();
    for step in &run.steps {
        sealed_run.steps.push(seal_step(workspace_key, step)?);
    }
    Ok(sealed_run)
}
