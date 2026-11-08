use proptest::prelude::*;

use crate::forget_contract::{
    LONGEST_FORGET_RUN, check_forget_is_idempotent,
    check_forget_removes_only_its_secret, check_save_after_forget_restores,
};
use crate::store_contract::{StoreSnapshot, full_snapshot_strategy};
use crate::store_desk::{
    STORE_CASE_COUNT, SecretKind, TEST_SERVICE_NAME, open_keychain_desk,
};

fn check_keychain_forget_removes_only_its_entry(
    kind: SecretKind,
    secrets: &StoreSnapshot,
) -> Result<(), TestCaseError> {
    let desk = open_keychain_desk(TEST_SERVICE_NAME)?;

    check_forget_removes_only_its_secret(&desk.store, kind, secrets)?;

    prop_assert_eq!(desk.read_planted(kind)?, None);
    Ok(())
}

fn check_keychain_forget_is_idempotent(
    kind: SecretKind,
    secrets: &StoreSnapshot,
    forget_count: usize,
) -> Result<(), TestCaseError> {
    let desk = open_keychain_desk(TEST_SERVICE_NAME)?;

    check_forget_is_idempotent(&desk.store, kind, secrets, forget_count)?;

    prop_assert_eq!(desk.read_planted(kind)?, None);
    Ok(())
}

fn check_keychain_save_after_forget_restores(
    kind: SecretKind,
    secrets: &StoreSnapshot,
) -> Result<(), TestCaseError> {
    let desk = open_keychain_desk(TEST_SERVICE_NAME)?;

    check_save_after_forget_restores(&desk.store, kind, secrets)?;

    prop_assert!(desk.read_planted(kind)?.is_some());
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

    #[test]
    fn test_keychain_identity_store_forget_identity_property_only_it(
        secrets in full_snapshot_strategy(),
    ) {
        check_keychain_forget_removes_only_its_entry(
            SecretKind::Identity,
            &secrets,
        )?;
    }

    #[test]
    fn test_keychain_identity_store_forget_identity_property_is_idempotent(
        secrets in full_snapshot_strategy(),
        forget_count in 1..LONGEST_FORGET_RUN,
    ) {
        check_keychain_forget_is_idempotent(
            SecretKind::Identity,
            &secrets,
            forget_count,
        )?;
    }

    #[test]
    fn test_keychain_identity_store_forget_identity_property_save_restores(
        secrets in full_snapshot_strategy(),
    ) {
        check_keychain_save_after_forget_restores(
            SecretKind::Identity,
            &secrets,
        )?;
    }

    #[test]
    fn test_keychain_identity_store_forget_peer_secret_property_only_it(
        secrets in full_snapshot_strategy(),
    ) {
        check_keychain_forget_removes_only_its_entry(
            SecretKind::PeerSecret,
            &secrets,
        )?;
    }

    #[test]
    fn test_keychain_identity_store_forget_peer_secret_property_idempotent(
        secrets in full_snapshot_strategy(),
        forget_count in 1..LONGEST_FORGET_RUN,
    ) {
        check_keychain_forget_is_idempotent(
            SecretKind::PeerSecret,
            &secrets,
            forget_count,
        )?;
    }

    #[test]
    fn test_keychain_identity_store_forget_peer_secret_property_restores(
        secrets in full_snapshot_strategy(),
    ) {
        check_keychain_save_after_forget_restores(
            SecretKind::PeerSecret,
            &secrets,
        )?;
    }

    #[test]
    fn test_keychain_identity_store_forget_agent_credential_property_only(
        secrets in full_snapshot_strategy(),
    ) {
        check_keychain_forget_removes_only_its_entry(
            SecretKind::AgentCredential,
            &secrets,
        )?;
    }

    #[test]
    fn test_keychain_identity_store_forget_agent_credential_property_twice(
        secrets in full_snapshot_strategy(),
        forget_count in 1..LONGEST_FORGET_RUN,
    ) {
        check_keychain_forget_is_idempotent(
            SecretKind::AgentCredential,
            &secrets,
            forget_count,
        )?;
    }

    #[test]
    fn test_keychain_identity_store_forget_agent_credential_property_saves(
        secrets in full_snapshot_strategy(),
    ) {
        check_keychain_save_after_forget_restores(
            SecretKind::AgentCredential,
            &secrets,
        )?;
    }
}
