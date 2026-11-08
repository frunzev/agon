use proptest::prelude::*;

use crate::forget_contract::{
    LONGEST_FORGET_RUN, check_forget_is_idempotent,
    check_forget_removes_only_its_secret, check_save_after_forget_restores,
};
use crate::store_contract::{StoreSnapshot, full_snapshot_strategy};
use crate::store_desk::{
    SECRET_KINDS, STORE_CASE_COUNT, SecretKind, list_file_names,
    open_file_desk,
};

fn check_file_forget_removes_only_its_file(
    kind: SecretKind,
    secrets: &StoreSnapshot,
) -> Result<(), TestCaseError> {
    let desk = open_file_desk()?;

    check_forget_removes_only_its_secret(&desk.store, kind, secrets)?;

    let mut expected_names = Vec::new();
    for kept_kind in SECRET_KINDS {
        if kept_kind != kind {
            expected_names.push(kept_kind.file_name());
        }
    }
    expected_names.sort_unstable();
    prop_assert_eq!(list_file_names(desk.folder.path())?, expected_names);
    Ok(())
}

fn check_file_forget_is_idempotent(
    kind: SecretKind,
    secrets: &StoreSnapshot,
    forget_count: usize,
) -> Result<(), TestCaseError> {
    let desk = open_file_desk()?;

    check_forget_is_idempotent(&desk.store, kind, secrets, forget_count)?;

    prop_assert!(!desk.path_of(kind).exists());
    Ok(())
}

fn check_file_save_after_forget_restores(
    kind: SecretKind,
    secrets: &StoreSnapshot,
) -> Result<(), TestCaseError> {
    let desk = open_file_desk()?;

    check_save_after_forget_restores(&desk.store, kind, secrets)?;

    prop_assert!(desk.path_of(kind).is_file());
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

    #[test]
    fn test_file_identity_store_forget_identity_property_removes_only_it(
        secrets in full_snapshot_strategy(),
    ) {
        check_file_forget_removes_only_its_file(
            SecretKind::Identity,
            &secrets,
        )?;
    }

    #[test]
    fn test_file_identity_store_forget_identity_property_is_idempotent(
        secrets in full_snapshot_strategy(),
        forget_count in 1..LONGEST_FORGET_RUN,
    ) {
        check_file_forget_is_idempotent(
            SecretKind::Identity,
            &secrets,
            forget_count,
        )?;
    }

    #[test]
    fn test_file_identity_store_forget_identity_property_save_restores(
        secrets in full_snapshot_strategy(),
    ) {
        check_file_save_after_forget_restores(SecretKind::Identity, &secrets)?;
    }

    #[test]
    fn test_file_identity_store_forget_peer_secret_property_removes_only_it(
        secrets in full_snapshot_strategy(),
    ) {
        check_file_forget_removes_only_its_file(
            SecretKind::PeerSecret,
            &secrets,
        )?;
    }

    #[test]
    fn test_file_identity_store_forget_peer_secret_property_is_idempotent(
        secrets in full_snapshot_strategy(),
        forget_count in 1..LONGEST_FORGET_RUN,
    ) {
        check_file_forget_is_idempotent(
            SecretKind::PeerSecret,
            &secrets,
            forget_count,
        )?;
    }

    #[test]
    fn test_file_identity_store_forget_peer_secret_property_save_restores(
        secrets in full_snapshot_strategy(),
    ) {
        check_file_save_after_forget_restores(
            SecretKind::PeerSecret,
            &secrets,
        )?;
    }

    #[test]
    fn test_file_identity_store_forget_agent_credential_property_only_it(
        secrets in full_snapshot_strategy(),
    ) {
        check_file_forget_removes_only_its_file(
            SecretKind::AgentCredential,
            &secrets,
        )?;
    }

    #[test]
    fn test_file_identity_store_forget_agent_credential_property_idempotent(
        secrets in full_snapshot_strategy(),
        forget_count in 1..LONGEST_FORGET_RUN,
    ) {
        check_file_forget_is_idempotent(
            SecretKind::AgentCredential,
            &secrets,
            forget_count,
        )?;
    }

    #[test]
    fn test_file_identity_store_forget_agent_credential_property_restores(
        secrets in full_snapshot_strategy(),
    ) {
        check_file_save_after_forget_restores(
            SecretKind::AgentCredential,
            &secrets,
        )?;
    }
}
