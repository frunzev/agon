use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{StepKind, Workflow};
use orchestration_core::workflow_document::render_workflow_document;
use orchestration_node::content_sealing::{open_workflow, seal_workflow};
use orchestration_security::documents::sign_document;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::sealing::WorkspaceKey;
use proptest::prelude::*;
use proptest::sample::Index;
use uuid::Uuid;

use crate::sealing_samples::{
    hostile_texts_strategy, is_hex_only_sealed_text, workspace_number,
};
use crate::signed_reseal_properties::{
    change_one_step, save_as_the_server_does, sign_sealed, signed_document_of,
};
use crate::support::entity_strategies::{sample_keyring, sample_workflow};
use crate::support::test_device::{describe, fail};

const HELPER_CASES: u32 = 16;
const SHIFTED_ID_START: u128 = 1000;
const RENAMED_SUFFIX: &str = "-renamed";
const QUOTED_LINE_END: &str = "\"\n";
const UNQUOTED_LINE_END: &str = "\n";

fn drift_from_signature(
    workspace_key: &WorkspaceKey,
    plain: &Workflow,
    signed: &Workflow,
) -> Result<Workflow, String> {
    let fresh_copy = seal_workflow(workspace_key, plain).map_err(describe)?;
    Ok(Workflow {
        signature: signed.signature.clone(),
        ..fresh_copy
    })
}

fn shift_step_ids(workflow: &Workflow) -> Workflow {
    let mut shifted = workflow.clone();
    for (position, agent) in shifted.agents.iter_mut().enumerate() {
        let offset = u128::try_from(position).unwrap_or_default();
        agent.id = WorkflowAgentId(Uuid::from_u128(SHIFTED_ID_START + offset));
    }
    shifted
}

fn rename_steps(workflow: &Workflow) -> Workflow {
    let mut renamed = workflow.clone();
    for agent in &mut renamed.agents {
        agent.name.push_str(RENAMED_SUFFIX);
    }
    renamed
}

fn collect_tasks(workflow: &Workflow) -> Vec<String> {
    let mut tasks = Vec::new();
    for agent in &workflow.agents {
        tasks.push(agent.task.clone());
    }
    tasks
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HELPER_CASES))]

    #[test]
    fn test_find_line_sealed_text_property_a_question_is_borrowed(
        agent_tasks in hostile_texts_strategy(),
        step in any::<Index>(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(9)).map_err(fail)?;
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let mut plain = sample_workflow(&agent_tasks);
        for agent in &mut plain.agents {
            agent.step_kind = StepKind::Person;
        }
        let signed = sign_sealed(&workspace_key, &identity, &plain)
            .map_err(fail)?;
        let changed = change_one_step(&plain, step);

        let after_change =
            save_as_the_server_does(&workspace_key, &changed, &signed)
                .map_err(fail)?;
        let after_revert =
            save_as_the_server_does(&workspace_key, &plain, &after_change)
                .map_err(fail)?;

        prop_assert_eq!(
            render_workflow_document(&after_revert),
            signed_document_of(&signed)
        );
    }

    #[test]
    fn test_find_line_sealed_text_property_an_unclosed_quote_is_skipped(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(9)).map_err(fail)?;
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let plain = sample_workflow(&agent_tasks);
        let mut signed = sign_sealed(&workspace_key, &identity, &plain)
            .map_err(fail)?;
        if let Some(signature) = signed.signature.as_mut() {
            signature.signed_document = signature
                .signed_document
                .replace(QUOTED_LINE_END, UNQUOTED_LINE_END);
        }
        let drifted = drift_from_signature(&workspace_key, &plain, &signed)
            .map_err(fail)?;

        let resealed =
            save_as_the_server_does(&workspace_key, &plain, &drifted)
                .map_err(fail)?;

        prop_assert_eq!(collect_tasks(&resealed), collect_tasks(&drifted));
        let opened = open_workflow(&keyring, &resealed).map_err(fail)?;
        prop_assert_eq!(opened.agents, plain.agents);
    }

    #[test]
    fn test_find_line_sealed_text_property_plain_lines_are_never_kept(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(9)).map_err(fail)?;
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let plain = sample_workflow(&agent_tasks);
        let plain_document = render_workflow_document(&plain);
        let stored = Workflow {
            signature: Some(sign_document(&identity, &plain_document)),
            ..seal_workflow(&workspace_key, &plain).map_err(fail)?
        };

        let resealed =
            save_as_the_server_does(&workspace_key, &plain, &stored)
                .map_err(fail)?;

        prop_assert_eq!(collect_tasks(&resealed), collect_tasks(&stored));
        for agent in &resealed.agents {
            prop_assert!(is_hex_only_sealed_text(&agent.task));
        }
    }

    #[test]
    fn test_read_signed_step_tasks_property_new_unsigned_steps_seal_fresh(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(9)).map_err(fail)?;
        let plain = sample_workflow(&agent_tasks);
        let empty_stored = Workflow {
            agents: Vec::new(),
            ..plain.clone()
        };

        let resealed =
            save_as_the_server_does(&workspace_key, &plain, &empty_stored)
                .map_err(fail)?;

        prop_assert!(resealed.signature.is_none());
        let opened = open_workflow(&keyring, &resealed).map_err(fail)?;
        prop_assert_eq!(opened.agents, plain.agents);
    }

    #[test]
    fn test_read_signed_step_tasks_property_names_find_seals_without_ids(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(9)).map_err(fail)?;
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let plain = sample_workflow(&agent_tasks);
        let signed = sign_sealed(&workspace_key, &identity, &plain)
            .map_err(fail)?;
        let drifted = drift_from_signature(&workspace_key, &plain, &signed)
            .map_err(fail)?;
        let drifted_with_new_ids = shift_step_ids(&drifted);

        let resealed = save_as_the_server_does(
            &workspace_key,
            &shift_step_ids(&plain),
            &drifted_with_new_ids,
        )
        .map_err(fail)?;

        prop_assert_eq!(collect_tasks(&resealed), collect_tasks(&signed));
    }

    #[test]
    fn test_read_signed_step_tasks_property_other_names_borrow_nothing(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(9)).map_err(fail)?;
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let renamed_plain = rename_steps(&sample_workflow(&agent_tasks));
        let signed = sign_sealed(&workspace_key, &identity, &renamed_plain)
            .map_err(fail)?;
        let plain = sample_workflow(&agent_tasks);
        let drifted = drift_from_signature(&workspace_key, &plain, &signed)
            .map_err(fail)?;

        let resealed =
            save_as_the_server_does(&workspace_key, &plain, &drifted)
                .map_err(fail)?;

        prop_assert_eq!(collect_tasks(&resealed), collect_tasks(&drifted));
    }

    #[test]
    fn test_find_stored_task_property_a_renamed_step_keeps_its_seal(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(9)).map_err(fail)?;
        let plain = sample_workflow(&agent_tasks);
        let stored = seal_workflow(&workspace_key, &plain).map_err(fail)?;

        let resealed = save_as_the_server_does(
            &workspace_key,
            &rename_steps(&plain),
            &stored,
        )
        .map_err(fail)?;

        prop_assert_eq!(collect_tasks(&resealed), collect_tasks(&stored));
    }

    #[test]
    fn test_find_stored_task_property_an_unknown_id_seals_fresh(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(9)).map_err(fail)?;
        let plain = sample_workflow(&agent_tasks);
        let stored = seal_workflow(&workspace_key, &plain).map_err(fail)?;
        let shifted_plain = shift_step_ids(&plain);

        let resealed =
            save_as_the_server_does(&workspace_key, &shifted_plain, &stored)
                .map_err(fail)?;

        let pairs = resealed.agents.iter().zip(&stored.agents);
        for (resealed_agent, stored_agent) in pairs {
            prop_assert_ne!(&resealed_agent.task, &stored_agent.task);
        }
        let opened = open_workflow(&keyring, &resealed).map_err(fail)?;
        prop_assert_eq!(opened.agents, shifted_plain.agents);
    }

    #[test]
    fn test_find_stored_task_property_the_signed_seal_comes_first(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(9)).map_err(fail)?;
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let plain = sample_workflow(&agent_tasks);
        let signed = sign_sealed(&workspace_key, &identity, &plain)
            .map_err(fail)?;
        let drifted = drift_from_signature(&workspace_key, &plain, &signed)
            .map_err(fail)?;

        let resealed =
            save_as_the_server_does(&workspace_key, &plain, &drifted)
                .map_err(fail)?;

        prop_assert_eq!(collect_tasks(&resealed), collect_tasks(&signed));
    }
}
