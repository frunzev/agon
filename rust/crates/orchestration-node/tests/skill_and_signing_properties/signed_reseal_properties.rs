use orchestration_core::workflow::{SignatureState, Workflow};
use orchestration_core::workflow_document::render_workflow_document;
use orchestration_node::content_sealing::{
    open_workflow, reseal_workflow, seal_workflow,
};
use orchestration_security::documents::{sign_document, signature_state};
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::sealing::WorkspaceKey;
use proptest::prelude::*;
use proptest::sample::Index;

use crate::sealing_samples::{
    hostile_text_strategy, hostile_texts_strategy, is_hex_only_sealed_text,
    workspace_number,
};
use crate::support::entity_strategies::{sample_keyring, sample_workflow};
use crate::support::test_device::{describe, fail};

const RESEAL_CASES: u32 = 24;
const CHANGED_SUFFIX: &str = " (changed)";

pub fn sign_sealed(
    workspace_key: &WorkspaceKey,
    identity: &DeviceIdentity,
    plain_workflow: &Workflow,
) -> Result<Workflow, String> {
    let sealed =
        seal_workflow(workspace_key, plain_workflow).map_err(describe)?;
    let document = render_workflow_document(&sealed);
    Ok(Workflow {
        signature: Some(sign_document(identity, &document)),
        ..sealed
    })
}

pub fn save_as_the_server_does(
    workspace_key: &WorkspaceKey,
    plain_workflow: &Workflow,
    stored_workflow: &Workflow,
) -> Result<Workflow, String> {
    let resealed =
        reseal_workflow(workspace_key, plain_workflow, stored_workflow)
            .map_err(describe)?;
    Ok(Workflow {
        signature: stored_workflow.signature.clone(),
        ..resealed
    })
}

pub fn change_one_step(plain_workflow: &Workflow, step: Index) -> Workflow {
    let mut changed = plain_workflow.clone();
    let position = step.index(changed.agents.len());
    changed.agents[position].task.push_str(CHANGED_SUFFIX);
    changed
}

pub fn read_state(
    identity: &DeviceIdentity,
    stored: &Workflow,
) -> SignatureState {
    let signer_key = identity.public_identity().signing_public_key;
    let document = render_workflow_document(stored);
    signature_state(stored.signature.as_ref(), &document, Some(&signer_key))
}

pub fn signed_document_of(stored: &Workflow) -> String {
    stored
        .signature
        .as_ref()
        .map(|signature| signature.signed_document.clone())
        .unwrap_or_default()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RESEAL_CASES))]

    #[test]
    fn test_reseal_workflow_property_a_revert_renders_the_signed_document(
        agent_tasks in hostile_texts_strategy(),
        step in any::<Index>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(7)).map_err(fail)?;
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let plain = sample_workflow(&agent_tasks);
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
        prop_assert_eq!(
            read_state(&identity, &after_revert),
            SignatureState::Signed
        );
        let opened = open_workflow(&keyring, &after_revert).map_err(fail)?;
        prop_assert_eq!(opened.agents, plain.agents);
    }

    #[test]
    fn test_reseal_workflow_property_a_kept_change_still_reads_changed(
        agent_tasks in hostile_texts_strategy(),
        step in any::<Index>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(7)).map_err(fail)?;
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let plain = sample_workflow(&agent_tasks);
        let signed = sign_sealed(&workspace_key, &identity, &plain)
            .map_err(fail)?;
        let changed = change_one_step(&plain, step);

        let after_change =
            save_as_the_server_does(&workspace_key, &changed, &signed)
                .map_err(fail)?;
        let saved_again =
            save_as_the_server_does(&workspace_key, &changed, &after_change)
                .map_err(fail)?;

        prop_assert_eq!(
            read_state(&identity, &saved_again),
            SignatureState::ChangedNotSigned
        );
        prop_assert_eq!(&saved_again.agents, &after_change.agents);
        let opened = open_workflow(&keyring, &saved_again).map_err(fail)?;
        prop_assert_eq!(opened.agents, changed.agents);
    }

    #[test]
    fn test_reseal_step_task_property_a_fresh_copy_of_signed_text_heals(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(7)).map_err(fail)?;
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let plain = sample_workflow(&agent_tasks);
        let signed = sign_sealed(&workspace_key, &identity, &plain)
            .map_err(fail)?;
        let fresh_copy =
            seal_workflow(&workspace_key, &plain).map_err(fail)?;
        let drifted = Workflow {
            signature: signed.signature.clone(),
            ..fresh_copy
        };

        let healed =
            save_as_the_server_does(&workspace_key, &plain, &drifted)
                .map_err(fail)?;

        prop_assert_eq!(
            read_state(&identity, &drifted),
            SignatureState::ChangedNotSigned
        );
        let healed_state = read_state(&identity, &healed);
        prop_assert_eq!(healed_state, SignatureState::Signed);
    }

    #[test]
    fn test_read_step_sealed_texts_property_never_borrows_a_foreign_seal(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (signing_key, _) =
            sample_keyring(workspace_number(7)).map_err(fail)?;
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(8)).map_err(fail)?;
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let plain = sample_workflow(&agent_tasks);
        let signed = sign_sealed(&signing_key, &identity, &plain)
            .map_err(fail)?;

        let resealed =
            save_as_the_server_does(&workspace_key, &plain, &signed)
                .map_err(fail)?;

        let pairs = resealed.agents.iter().zip(&signed.agents);
        for (resealed_agent, signed_agent) in pairs {
            prop_assert_ne!(&resealed_agent.task, &signed_agent.task);
            prop_assert!(is_hex_only_sealed_text(&resealed_agent.task));
        }
        let opened = open_workflow(&keyring, &resealed).map_err(fail)?;
        prop_assert_eq!(opened.agents, plain.agents);
    }

    #[test]
    fn test_read_step_sealed_texts_property_unsigned_keeps_stored_seals(
        agent_tasks in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(7)).map_err(fail)?;
        let plain = sample_workflow(&agent_tasks);
        let stored = seal_workflow(&workspace_key, &plain).map_err(fail)?;

        let resealed =
            save_as_the_server_does(&workspace_key, &plain, &stored)
                .map_err(fail)?;

        prop_assert_eq!(resealed.agents, stored.agents);
    }

    #[test]
    fn test_read_step_sealed_texts_property_a_damaged_document_is_harmless(
        agent_tasks in hostile_texts_strategy(),
        damaged_document in hostile_text_strategy(),
        step in any::<Index>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(7)).map_err(fail)?;
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let plain = sample_workflow(&agent_tasks);
        let mut signed = sign_sealed(&workspace_key, &identity, &plain)
            .map_err(fail)?;
        if let Some(signature) = signed.signature.as_mut() {
            signature.signed_document = damaged_document;
        }
        let changed = change_one_step(&plain, step);

        let resealed =
            save_as_the_server_does(&workspace_key, &changed, &signed)
                .map_err(fail)?;

        let opened = open_workflow(&keyring, &resealed).map_err(fail)?;
        prop_assert_eq!(opened.agents, changed.agents);
    }
}
