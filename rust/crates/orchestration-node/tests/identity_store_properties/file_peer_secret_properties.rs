use std::fs;

use orchestration_node::identity_store::{
    IdentityStore, IdentityStoreError, PEER_SECRET_LENGTH,
};
use orchestration_security::identity::IDENTITY_SECRET_LENGTH;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::store_contract::{
    fill_every_secret, full_snapshot_strategy, read_snapshot,
};
use crate::store_desk::{
    STORE_CASE_COUNT, SecretKind, list_file_names, open_file_desk,
    peer_secret_strategy, wrong_length_strategy,
};
use crate::support::test_device::fail;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

    #[test]
    fn test_file_identity_store_save_peer_secret_property_load_returns_it(
        peer_secret in peer_secret_strategy(),
    ) {
        let desk = open_file_desk()?;

        desk.store.save_peer_secret(&peer_secret).map_err(fail)?;

        let loaded = desk.store.load_peer_secret().map_err(fail)?;
        prop_assert_eq!(loaded.map(|found| *found), Some(peer_secret));
    }

    #[test]
    fn test_file_identity_store_save_peer_secret_property_last_save_wins(
        first_secret in peer_secret_strategy(),
        second_secret in peer_secret_strategy(),
    ) {
        let desk = open_file_desk()?;

        desk.store.save_peer_secret(&first_secret).map_err(fail)?;
        desk.store.save_peer_secret(&second_secret).map_err(fail)?;

        let stored = fs::read(desk.path_of(SecretKind::PeerSecret))
            .map_err(fail)?;
        prop_assert_eq!(stored, second_secret.to_vec());
    }

    #[test]
    fn test_file_identity_store_save_peer_secret_property_keeps_others(
        secrets in full_snapshot_strategy(),
        peer_secret in peer_secret_strategy(),
    ) {
        let desk = open_file_desk()?;
        fill_every_secret(&desk.store, &secrets)?;

        desk.store.save_peer_secret(&peer_secret).map_err(fail)?;

        let expected = secrets
            .with_secret(SecretKind::PeerSecret, Some(peer_secret.to_vec()));
        prop_assert_eq!(read_snapshot(&desk.store)?, expected);
    }

    #[test]
    fn test_file_identity_store_load_peer_secret_property_reads_planted(
        planted in peer_secret_strategy(),
    ) {
        let desk = open_file_desk()?;
        desk.plant(SecretKind::PeerSecret, &planted)?;

        let loaded = desk.store.load_peer_secret().map_err(fail)?;

        prop_assert_eq!(loaded.map(|found| *found), Some(planted));
    }

    #[test]
    fn test_file_identity_store_load_peer_secret_property_wrong_size_damaged(
        planted in wrong_length_strategy(PEER_SECRET_LENGTH),
    ) {
        let desk = open_file_desk()?;
        desk.plant(SecretKind::PeerSecret, &planted)?;

        let loaded = desk.store.load_peer_secret();

        let is_damaged =
            matches!(loaded, Err(IdentityStoreError::DamagedPeerSecret));
        prop_assert!(is_damaged);
        let still_stored =
            fs::read(desk.path_of(SecretKind::PeerSecret)).map_err(fail)?;
        prop_assert_eq!(still_stored, planted);
    }

    #[test]
    fn test_file_identity_store_load_peer_secret_property_absent_is_none(
        identity_secret in vec(any::<u8>(), IDENTITY_SECRET_LENGTH),
    ) {
        let desk = open_file_desk()?;
        desk.plant(SecretKind::Identity, &identity_secret)?;

        let loaded = desk.store.load_peer_secret().map_err(fail)?;

        prop_assert!(loaded.is_none());
        let names = list_file_names(desk.folder.path())?;
        prop_assert_eq!(names, vec![SecretKind::Identity.file_name()]);
    }
}
