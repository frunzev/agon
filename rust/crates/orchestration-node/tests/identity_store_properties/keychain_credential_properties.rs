use orchestration_node::identity_store::IdentityStore;
use proptest::prelude::*;

use crate::store_contract::{
    fill_every_secret, full_snapshot_strategy, read_snapshot,
};
use crate::store_desk::{
    STORE_CASE_COUNT, SecretKind, TEST_SERVICE_NAME, credential_strategy,
    open_keychain_desk,
};
use crate::support::test_device::fail;

const LONGEST_LOAD_RUN: usize = 5;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

    #[test]
    fn test_keychain_identity_store_save_agent_credential_property_round_trip(
        credential in credential_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;

        desk.store.save_agent_credential(&credential).map_err(fail)?;

        let loaded = desk.store.load_agent_credential().map_err(fail)?;
        prop_assert_eq!(loaded.map(|found| found.to_vec()), Some(credential));
    }

    #[test]
    fn test_keychain_identity_store_save_agent_credential_property_last_wins(
        first_credential in credential_strategy(),
        second_credential in credential_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;

        desk.store.save_agent_credential(&first_credential).map_err(fail)?;
        desk.store.save_agent_credential(&second_credential).map_err(fail)?;

        let stored = desk.read_planted(SecretKind::AgentCredential)?;
        prop_assert_eq!(stored, Some(second_credential));
    }

    #[test]
    fn test_keychain_identity_store_save_agent_credential_property_others(
        secrets in full_snapshot_strategy(),
        credential in credential_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        fill_every_secret(&desk.store, &secrets)?;

        desk.store.save_agent_credential(&credential).map_err(fail)?;

        let expected = secrets
            .with_secret(SecretKind::AgentCredential, Some(credential));
        prop_assert_eq!(read_snapshot(&desk.store)?, expected);
    }

    #[test]
    fn test_keychain_identity_store_load_agent_credential_property_verbatim(
        planted in credential_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        desk.plant(SecretKind::AgentCredential, &planted)?;

        let loaded = desk.store.load_agent_credential().map_err(fail)?;

        prop_assert_eq!(loaded.map(|found| found.to_vec()), Some(planted));
    }

    #[test]
    fn test_keychain_identity_store_load_agent_credential_property_repeats(
        planted in credential_strategy(),
        load_count in 2..LONGEST_LOAD_RUN,
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        desk.plant(SecretKind::AgentCredential, &planted)?;

        for _ in 0..load_count {
            let loaded = desk.store.load_agent_credential().map_err(fail)?;
            prop_assert_eq!(
                loaded.map(|found| found.to_vec()),
                Some(planted.clone()),
            );
        }
        let still_stored = desk.read_planted(SecretKind::AgentCredential)?;
        prop_assert_eq!(still_stored, Some(planted));
    }

    #[test]
    fn test_keychain_identity_store_load_agent_credential_property_absent(
        secrets in full_snapshot_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        let without_credential =
            secrets.with_secret(SecretKind::AgentCredential, None);
        fill_every_secret(&desk.store, &without_credential)?;

        let loaded = desk.store.load_agent_credential().map_err(fail)?;

        prop_assert!(loaded.is_none());
    }
}
