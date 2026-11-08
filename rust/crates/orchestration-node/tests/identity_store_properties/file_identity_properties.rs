use std::fs;

use orchestration_node::identity_store::{
    FileIdentityStore, IdentityStore, IdentityStoreError,
};
use orchestration_security::identity::{
    DeviceIdentity, IDENTITY_SECRET_LENGTH,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::store_contract::{
    StoreSnapshot, fill_every_secret, full_snapshot_strategy, read_snapshot,
};
use crate::store_desk::{
    AGENT_CREDENTIAL_FILE_NAME, PEER_SECRET_FILE_NAME, STORE_CASE_COUNT,
    SecretKind, create_case_folder, identity_strategy, list_file_names,
    open_file_desk, wrong_length_strategy,
};
use crate::support::test_device::fail;

const IDENTITY_STEM_PATTERN: &str = "[a-z][a-z0-9_]{0,15}";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

    #[test]
    fn test_file_identity_store_new_property_starts_with_nothing_stored(
        identity_stem in IDENTITY_STEM_PATTERN,
    ) {
        let folder = create_case_folder()?;
        let identity_path = folder.path().join(format!("{identity_stem}.key"));

        let store = FileIdentityStore::new(identity_path);

        prop_assert_eq!(read_snapshot(&store)?, StoreSnapshot::default());
        prop_assert!(list_file_names(folder.path())?.is_empty());
    }

    #[test]
    fn test_file_identity_store_new_property_secrets_sit_beside_identity(
        identity_stem in IDENTITY_STEM_PATTERN,
        secrets in full_snapshot_strategy(),
    ) {
        let folder = create_case_folder()?;
        let identity_name = format!("{identity_stem}.key");
        let store = FileIdentityStore::new(folder.path().join(&identity_name));

        fill_every_secret(&store, &secrets)?;

        let mut expected_names = vec![
            identity_name,
            PEER_SECRET_FILE_NAME.to_owned(),
            AGENT_CREDENTIAL_FILE_NAME.to_owned(),
        ];
        expected_names.sort();
        prop_assert_eq!(list_file_names(folder.path())?, expected_names);
    }

    #[test]
    fn test_file_identity_store_new_property_stores_on_one_path_agree(
        secrets in full_snapshot_strategy(),
    ) {
        let desk = open_file_desk()?;
        fill_every_secret(&desk.store, &secrets)?;

        let reopened =
            FileIdentityStore::new(desk.path_of(SecretKind::Identity));

        prop_assert_eq!(read_snapshot(&reopened)?, secrets);
    }

    #[test]
    fn test_file_identity_store_save_identity_property_load_returns_it(
        identity in identity_strategy(),
    ) {
        let desk = open_file_desk()?;

        desk.store.save_identity(&identity).map_err(fail)?;

        let loaded = desk.store.load_identity().map_err(fail)?;
        let loaded_secret = loaded.map(|found| *found.secret_bytes());
        prop_assert_eq!(loaded_secret, Some(*identity.secret_bytes()));
    }

    #[test]
    fn test_file_identity_store_save_identity_property_last_save_wins(
        first_identity in identity_strategy(),
        second_identity in identity_strategy(),
    ) {
        let desk = open_file_desk()?;

        desk.store.save_identity(&first_identity).map_err(fail)?;
        desk.store.save_identity(&second_identity).map_err(fail)?;

        let stored = fs::read(desk.path_of(SecretKind::Identity))
            .map_err(fail)?;
        prop_assert_eq!(stored, second_identity.secret_bytes().to_vec());
    }

    #[test]
    fn test_file_identity_store_save_identity_property_keeps_other_secrets(
        secrets in full_snapshot_strategy(),
        identity in identity_strategy(),
    ) {
        let desk = open_file_desk()?;
        fill_every_secret(&desk.store, &secrets)?;

        desk.store.save_identity(&identity).map_err(fail)?;

        let expected = secrets.with_secret(
            SecretKind::Identity,
            Some(identity.secret_bytes().to_vec()),
        );
        prop_assert_eq!(read_snapshot(&desk.store)?, expected);
    }

    #[test]
    fn test_file_identity_store_load_identity_property_reads_planted_bytes(
        planted in vec(any::<u8>(), IDENTITY_SECRET_LENGTH),
    ) {
        let desk = open_file_desk()?;
        desk.plant(SecretKind::Identity, &planted)?;

        let loaded = desk.store.load_identity().map_err(fail)?;

        let expected = DeviceIdentity::from_secret_bytes(&planted)
            .map_err(fail)?
            .public_identity();
        let loaded_public = loaded.map(|found| found.public_identity());
        prop_assert_eq!(loaded_public, Some(expected));
    }

    #[test]
    fn test_file_identity_store_load_identity_property_wrong_size_is_damaged(
        planted in wrong_length_strategy(IDENTITY_SECRET_LENGTH),
    ) {
        let desk = open_file_desk()?;
        desk.plant(SecretKind::Identity, &planted)?;

        let loaded = desk.store.load_identity();

        let is_damaged =
            matches!(loaded, Err(IdentityStoreError::DamagedIdentity));
        prop_assert!(is_damaged);
        let still_stored =
            fs::read(desk.path_of(SecretKind::Identity)).map_err(fail)?;
        prop_assert_eq!(still_stored, planted);
    }

    #[test]
    fn test_file_identity_store_load_identity_property_absent_writes_nothing(
        load_count in 1_usize..4,
    ) {
        let desk = open_file_desk()?;

        for _ in 0..load_count {
            prop_assert!(desk.store.load_identity().map_err(fail)?.is_none());
        }

        prop_assert!(list_file_names(desk.folder.path())?.is_empty());
    }
}
