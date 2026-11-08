use orchestration_node::identity_store::{
    IdentityStore, IdentityStoreError, KeychainIdentityStore,
    PEER_SECRET_LENGTH,
};
use orchestration_security::identity::IDENTITY_SECRET_LENGTH;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::store_contract::{
    StoreSnapshot, fill_every_secret, full_snapshot_strategy, read_snapshot,
    secret_in,
};
use crate::store_desk::{
    SECRET_KINDS, STORE_CASE_COUNT, SecretKind, TEST_SERVICE_NAME,
    identity_strategy, open_keychain_desk, open_mock_keychain,
    peer_secret_strategy, service_name_strategy, wrong_length_strategy,
};
use crate::support::test_device::fail;

const SHORTEST_SEARCHABLE_SECRET: usize = 16;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

    #[test]
    fn test_keychain_identity_store_new_property_keeps_the_service_name(
        service_name in service_name_strategy(),
        secrets in full_snapshot_strategy(),
    ) {
        let desk = open_keychain_desk(&service_name)?;

        fill_every_secret(&desk.store, &secrets)?;

        prop_assert_eq!(
            desk.read_planted(SecretKind::Identity)?,
            secrets.identity,
        );
        prop_assert_eq!(
            desk.read_planted(SecretKind::PeerSecret)?,
            secrets.peer_secret,
        );
        prop_assert_eq!(
            desk.read_planted(SecretKind::AgentCredential)?,
            secrets.agent_credential,
        );
    }

    #[test]
    fn test_keychain_identity_store_new_property_services_stay_apart(
        first_service in service_name_strategy(),
        second_service in service_name_strategy(),
        secrets in full_snapshot_strategy(),
    ) {
        prop_assume!(first_service != second_service);
        let credential_store = open_mock_keychain()?;
        let first_store = KeychainIdentityStore::new(
            &first_service,
            credential_store.clone(),
        );
        let second_store =
            KeychainIdentityStore::new(&second_service, credential_store);

        fill_every_secret(&first_store, &secrets)?;

        let second_snapshot = read_snapshot(&second_store)?;
        prop_assert_eq!(second_snapshot, StoreSnapshot::default());
        prop_assert_eq!(read_snapshot(&first_store)?, secrets);
    }

    #[test]
    fn test_keychain_identity_store_new_property_debug_hides_secrets(
        service_name in service_name_strategy(),
        secrets in full_snapshot_strategy(),
    ) {
        let desk = open_keychain_desk(&service_name)?;
        fill_every_secret(&desk.store, &secrets)?;

        let description = format!("{:?}", desk.store);

        let quoted_service_name = format!("{service_name:?}");
        prop_assert!(description.contains(&quoted_service_name));
        for kind in SECRET_KINDS {
            let secret = secret_in(&secrets, kind).unwrap_or_default();
            if secret.len() < SHORTEST_SEARCHABLE_SECRET {
                continue;
            }
            let listed_secret = format!("{secret:?}");
            prop_assert!(!description.contains(&hex::encode(&secret)));
            prop_assert!(!description.contains(&listed_secret));
        }
    }

    #[test]
    fn test_keychain_identity_store_save_identity_property_load_returns_it(
        identity in identity_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;

        desk.store.save_identity(&identity).map_err(fail)?;

        let loaded = desk.store.load_identity().map_err(fail)?;
        let loaded_secret = loaded.map(|found| *found.secret_bytes());
        prop_assert_eq!(loaded_secret, Some(*identity.secret_bytes()));
    }

    #[test]
    fn test_keychain_identity_store_save_identity_property_last_save_wins(
        first_identity in identity_strategy(),
        second_identity in identity_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;

        desk.store.save_identity(&first_identity).map_err(fail)?;
        desk.store.save_identity(&second_identity).map_err(fail)?;

        let stored = desk.read_planted(SecretKind::Identity)?;
        prop_assert_eq!(stored, Some(second_identity.secret_bytes().to_vec()));
    }

    #[test]
    fn test_keychain_identity_store_save_identity_property_keeps_others(
        secrets in full_snapshot_strategy(),
        identity in identity_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        fill_every_secret(&desk.store, &secrets)?;

        desk.store.save_identity(&identity).map_err(fail)?;

        let expected = secrets.with_secret(
            SecretKind::Identity,
            Some(identity.secret_bytes().to_vec()),
        );
        prop_assert_eq!(read_snapshot(&desk.store)?, expected);
    }

    #[test]
    fn test_keychain_identity_store_load_identity_property_reads_planted(
        planted in vec(any::<u8>(), IDENTITY_SECRET_LENGTH),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        desk.plant(SecretKind::Identity, &planted)?;

        let loaded = desk.store.load_identity().map_err(fail)?;

        let loaded_secret = loaded.map(|found| found.secret_bytes().to_vec());
        prop_assert_eq!(loaded_secret, Some(planted));
    }

    #[test]
    fn test_keychain_identity_store_load_identity_property_wrong_size_damaged(
        planted in wrong_length_strategy(IDENTITY_SECRET_LENGTH),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        desk.plant(SecretKind::Identity, &planted)?;

        let loaded = desk.store.load_identity();

        let is_damaged =
            matches!(loaded, Err(IdentityStoreError::DamagedIdentity));
        prop_assert!(is_damaged);
        let still_stored = desk.read_planted(SecretKind::Identity)?;
        prop_assert_eq!(still_stored, Some(planted));
    }

    #[test]
    fn test_keychain_identity_store_load_identity_property_absent_is_none(
        peer_secret in peer_secret_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        desk.store.save_peer_secret(&peer_secret).map_err(fail)?;

        let loaded = desk.store.load_identity().map_err(fail)?;

        prop_assert!(loaded.is_none());
        prop_assert_eq!(desk.read_planted(SecretKind::Identity)?, None);
    }

    #[test]
    fn test_keychain_identity_store_save_peer_secret_property_round_trip(
        peer_secret in peer_secret_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;

        desk.store.save_peer_secret(&peer_secret).map_err(fail)?;

        let loaded = desk.store.load_peer_secret().map_err(fail)?;
        prop_assert_eq!(loaded.map(|found| *found), Some(peer_secret));
    }

    #[test]
    fn test_keychain_identity_store_save_peer_secret_property_last_save_wins(
        first_secret in peer_secret_strategy(),
        second_secret in peer_secret_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;

        desk.store.save_peer_secret(&first_secret).map_err(fail)?;
        desk.store.save_peer_secret(&second_secret).map_err(fail)?;

        let stored = desk.read_planted(SecretKind::PeerSecret)?;
        prop_assert_eq!(stored, Some(second_secret.to_vec()));
    }

    #[test]
    fn test_keychain_identity_store_save_peer_secret_property_keeps_others(
        secrets in full_snapshot_strategy(),
        peer_secret in peer_secret_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        fill_every_secret(&desk.store, &secrets)?;

        desk.store.save_peer_secret(&peer_secret).map_err(fail)?;

        let expected = secrets
            .with_secret(SecretKind::PeerSecret, Some(peer_secret.to_vec()));
        prop_assert_eq!(read_snapshot(&desk.store)?, expected);
    }

    #[test]
    fn test_keychain_identity_store_load_peer_secret_property_reads_planted(
        planted in peer_secret_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        desk.plant(SecretKind::PeerSecret, &planted)?;

        let loaded = desk.store.load_peer_secret().map_err(fail)?;

        prop_assert_eq!(loaded.map(|found| *found), Some(planted));
    }

    #[test]
    fn test_keychain_identity_store_load_peer_secret_property_wrong_size(
        planted in wrong_length_strategy(PEER_SECRET_LENGTH),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        desk.plant(SecretKind::PeerSecret, &planted)?;

        let loaded = desk.store.load_peer_secret();

        let is_damaged =
            matches!(loaded, Err(IdentityStoreError::DamagedPeerSecret));
        prop_assert!(is_damaged);
        let still_stored = desk.read_planted(SecretKind::PeerSecret)?;
        prop_assert_eq!(still_stored, Some(planted));
    }

    #[test]
    fn test_keychain_identity_store_load_peer_secret_property_absent_none(
        identity in identity_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        desk.store.save_identity(&identity).map_err(fail)?;

        let loaded = desk.store.load_peer_secret().map_err(fail)?;

        prop_assert!(loaded.is_none());
        prop_assert_eq!(desk.read_planted(SecretKind::PeerSecret)?, None);
    }
}
