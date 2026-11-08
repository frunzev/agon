use orchestration_node::content_sealing::{
    open_workflow, reseal_workflow, seal_workflow,
};
use proptest::prelude::*;
use proptest::sample::Index;

use crate::sealing_samples::{
    SEALING_CASES, foreign_keyring, hostile_texts_strategy,
    is_hex_only_sealed_text, is_unreadable, tamper_sealed_text,
    workspace_number,
};
use crate::support::entity_strategies::{sample_keyring, sample_workflow};
use crate::support::test_device::fail;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALING_CASES))]

    #[test]
    fn test_seal_workflow_property_seals_every_hostile_step_task(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(4)).map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);

        let sealed = seal_workflow(&workspace_key, &workflow).map_err(fail)?;

        prop_assert_eq!(sealed.agents.len(), workflow.agents.len());
        for (sealed_agent, agent) in sealed.agents.iter().zip(&workflow.agents)
        {
            prop_assert!(is_hex_only_sealed_text(&sealed_agent.task));
            prop_assert_eq!(sealed_agent.id, agent.id);
            prop_assert_eq!(&sealed_agent.name, &agent.name);
        }
    }

    #[test]
    fn test_open_workflow_property_round_trips_hostile_step_tasks(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(4)).map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);

        let sealed = seal_workflow(&workspace_key, &workflow).map_err(fail)?;
        let opened = open_workflow(&keyring, &sealed).map_err(fail)?;

        prop_assert_eq!(opened, workflow);
    }

    #[test]
    fn test_open_workflow_property_detects_any_tampered_step(
        agent_tasks in hostile_texts_strategy(),
        step in any::<Index>(),
        position in any::<Index>(),
        shift in any::<u8>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(4)).map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);
        let mut sealed =
            seal_workflow(&workspace_key, &workflow).map_err(fail)?;
        let step_position = step.index(sealed.agents.len());
        let tampered_agent = &mut sealed.agents[step_position];
        tampered_agent.task =
            tamper_sealed_text(&tampered_agent.task, position, shift);

        let outcome = open_workflow(&keyring, &sealed);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_workflow_property_another_workspace_key_cannot_open(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(4)).map_err(fail)?;
        let other_keyring = foreign_keyring().map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);

        let sealed = seal_workflow(&workspace_key, &workflow).map_err(fail)?;
        let outcome = open_workflow(&other_keyring, &sealed);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_reseal_workflow_property_round_trips_hostile_changes(
        stored_tasks in hostile_texts_strategy(),
        changed_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(4)).map_err(fail)?;
        let stored_workflow = seal_workflow(
            &workspace_key,
            &sample_workflow(&stored_tasks),
        )
        .map_err(fail)?;
        let changed_workflow = sample_workflow(&changed_tasks);

        let resealed =
            reseal_workflow(
                &workspace_key,
                &changed_workflow,
                &stored_workflow,
            )
            .map_err(fail)?;

        let opened = open_workflow(&keyring, &resealed).map_err(fail)?;
        prop_assert_eq!(opened, changed_workflow);
    }

    #[test]
    fn test_reseal_step_task_property_matches_steps_by_id_not_position(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(4)).map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);
        let stored_workflow =
            seal_workflow(&workspace_key, &workflow).map_err(fail)?;
        let mut reordered_workflow = workflow.clone();
        reordered_workflow.agents.reverse();

        let resealed = reseal_workflow(
            &workspace_key,
            &reordered_workflow,
            &stored_workflow,
        )
        .map_err(fail)?;

        for resealed_agent in &resealed.agents {
            let stored_agent = stored_workflow
                .agents
                .iter()
                .find(|stored_agent| stored_agent.id == resealed_agent.id);
            let stored_task = stored_agent.map(|agent| agent.task.as_str());
            prop_assert_eq!(Some(resealed_agent.task.as_str()), stored_task);
        }
    }

    #[test]
    fn test_reseal_step_task_property_new_steps_get_fresh_ciphertext(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(4)).map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);
        let mut stored_workflow =
            seal_workflow(&workspace_key, &workflow).map_err(fail)?;
        stored_workflow.agents.clear();

        let resealed =
            reseal_workflow(&workspace_key, &workflow, &stored_workflow)
                .map_err(fail)?;

        for agent in &resealed.agents {
            prop_assert!(is_hex_only_sealed_text(&agent.task));
        }
        let opened = open_workflow(&keyring, &resealed).map_err(fail)?;
        prop_assert_eq!(opened, workflow);
    }

    #[test]
    fn test_reseal_step_task_property_a_step_under_another_key_is_resealed(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (stored_key, _) =
            sample_keyring(workspace_number(4)).map_err(fail)?;
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(5)).map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);
        let stored_workflow =
            seal_workflow(&stored_key, &workflow).map_err(fail)?;

        let resealed =
            reseal_workflow(&workspace_key, &workflow, &stored_workflow)
                .map_err(fail)?;

        let opened = open_workflow(&keyring, &resealed).map_err(fail)?;
        prop_assert_eq!(opened, workflow);
    }

    #[test]
    fn test_seals_same_text_property_stored_plain_text_is_never_kept(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(4)).map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);

        let resealed = reseal_workflow(&workspace_key, &workflow, &workflow)
            .map_err(fail)?;

        let agent_pairs = resealed.agents.iter().zip(&workflow.agents);
        for (resealed_agent, agent) in agent_pairs {
            prop_assert!(is_hex_only_sealed_text(&resealed_agent.task));
            prop_assert_ne!(&resealed_agent.task, &agent.task);
        }
    }

    #[test]
    fn test_seals_same_text_property_a_tampered_stored_step_is_replaced(
        agent_tasks in hostile_texts_strategy(),
        position in any::<Index>(),
        shift in any::<u8>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(4)).map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);
        let mut stored_workflow =
            seal_workflow(&workspace_key, &workflow).map_err(fail)?;
        let first_task = &stored_workflow.agents[0].task;
        let tampered_task = tamper_sealed_text(first_task, position, shift);
        stored_workflow.agents[0].task.clone_from(&tampered_task);

        let resealed =
            reseal_workflow(&workspace_key, &workflow, &stored_workflow)
                .map_err(fail)?;

        prop_assert_ne!(&resealed.agents[0].task, &tampered_task);
        let opened = open_workflow(&keyring, &resealed).map_err(fail)?;
        prop_assert_eq!(opened, workflow);
    }

    #[test]
    fn test_seals_same_text_property_a_changed_text_is_never_kept(
        agent_tasks in hostile_texts_strategy(),
        suffix in "[ a-z]{1,4}",
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(4)).map_err(fail)?;
        let workflow = sample_workflow(&agent_tasks);
        let stored_workflow =
            seal_workflow(&workspace_key, &workflow).map_err(fail)?;
        let mut changed_workflow = workflow.clone();
        changed_workflow.agents[0].task.push_str(&suffix);

        let resealed = reseal_workflow(
            &workspace_key,
            &changed_workflow,
            &stored_workflow,
        )
        .map_err(fail)?;

        prop_assert_ne!(
            &resealed.agents[0].task,
            &stored_workflow.agents[0].task
        );
    }
}
