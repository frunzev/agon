use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::DeviceId;
use orchestration_core::workflow::{StepKind, Workflow};
use orchestration_core::workflow_document::render_workflow_document;
use orchestration_node::content_sealing::{
    open_sealed_document, seal_workflow,
};
use orchestration_security::sealing::SEALED_TEXT_PREFIX;
use proptest::prelude::*;
use proptest::sample::Index;

use crate::sealing_samples::{
    SEALING_CASES, foreign_keyring, hostile_text_strategy,
    hostile_texts_strategy, is_unreadable, tamper_sealed_text,
    workspace_number,
};
use crate::support::entity_strategies::{sample_keyring, sample_workflow};
use crate::support::test_device::fail;

fn workflow_with_hostile_runners(
    agent_tasks: &[String],
    runner_text: &str,
) -> Workflow {
    let mut workflow = sample_workflow(agent_tasks);
    for (position, agent) in workflow.agents.iter_mut().enumerate() {
        agent.runs_on = if position % 2 == 0 {
            RunnerTarget::RunnerWithLabels {
                labels: vec![runner_text.to_owned()],
            }
        } else {
            RunnerTarget::SpecificRunner {
                device_id: DeviceId(runner_text.to_owned()),
            }
        };
    }
    workflow
}

fn workflow_with_person_steps(agent_tasks: &[String]) -> Workflow {
    let mut workflow = sample_workflow(agent_tasks);
    for (position, agent) in workflow.agents.iter_mut().enumerate() {
        if position % 2 == 1 {
            agent.step_kind = StepKind::Person;
        }
    }
    workflow
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALING_CASES))]

    #[test]
    fn test_open_sealed_document_property_opens_to_the_plain_document(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(12)).map_err(fail)?;
        let workflow = workflow_with_person_steps(&agent_tasks);
        let sealed = seal_workflow(&workspace_key, &workflow).map_err(fail)?;
        let sealed_document = render_workflow_document(&sealed);

        let opened_document =
            open_sealed_document(&keyring, &sealed_document).map_err(fail)?;

        prop_assert_eq!(opened_document, render_workflow_document(&workflow));
    }

    #[test]
    fn test_open_sealed_document_property_quotes_elsewhere_stay_plain(
        agent_tasks in hostile_texts_strategy(),
        runner_text in hostile_text_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(12)).map_err(fail)?;
        let workflow =
            workflow_with_hostile_runners(&agent_tasks, &runner_text);
        let sealed = seal_workflow(&workspace_key, &workflow).map_err(fail)?;
        let sealed_document = render_workflow_document(&sealed);

        let opened_document =
            open_sealed_document(&keyring, &sealed_document).map_err(fail)?;

        prop_assert_eq!(opened_document, render_workflow_document(&workflow));
    }

    #[test]
    fn test_open_sealed_document_property_unsealed_document_is_unchanged(
        agent_tasks in hostile_texts_strategy(),
        runner_text in hostile_text_strategy(),
    ) {
        let looks_sealed = agent_tasks
            .iter()
            .any(|agent_task| agent_task.starts_with(SEALED_TEXT_PREFIX));
        prop_assume!(!looks_sealed);
        let (_, keyring) = sample_keyring(workspace_number(12)).map_err(fail)?;
        let workflow =
            workflow_with_hostile_runners(&agent_tasks, &runner_text);
        let plain_document = render_workflow_document(&workflow);

        let opened_document =
            open_sealed_document(&keyring, &plain_document).map_err(fail)?;

        prop_assert_eq!(opened_document, plain_document);
    }

    #[test]
    fn test_open_sealed_document_property_another_workspace_cannot_open(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(12)).map_err(fail)?;
        let other_keyring = foreign_keyring().map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);
        let sealed = seal_workflow(&workspace_key, &workflow).map_err(fail)?;
        let sealed_document = render_workflow_document(&sealed);

        let outcome = open_sealed_document(&other_keyring, &sealed_document);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_sealed_document_property_detects_a_tampered_step(
        agent_tasks in hostile_texts_strategy(),
        step in any::<Index>(),
        position in any::<Index>(),
        shift in any::<u8>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(12)).map_err(fail)?;
        let mut sealed =
            seal_workflow(&workspace_key, &sample_workflow(&agent_tasks))
                .map_err(fail)?;
        let tampered_agent = &mut sealed.agents[step.index(agent_tasks.len())];
        tampered_agent.task =
            tamper_sealed_text(&tampered_agent.task, position, shift);

        let outcome =
            open_sealed_document(&keyring, &render_workflow_document(&sealed));

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }
}
