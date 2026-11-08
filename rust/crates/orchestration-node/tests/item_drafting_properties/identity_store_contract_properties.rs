use orchestration_node::identity_store::{
    FileIdentityStore, IdentityStore, IdentityStoreError, PEER_SECRET_LENGTH,
};
use orchestration_node::node_configuration::IdentityStoreChoice;
use orchestration_security::identity::IDENTITY_SECRET_LENGTH;
use proptest::collection::vec;
use proptest::prelude::*;
use tempfile::TempDir;

use crate::identity_files::{
    PLAIN_IDENTITY_FILE_NAME, PLAIN_PEER_SECRET_FILE_NAME,
    SEALED_IDENTITY_FILE_NAME, SEALED_PEER_SECRET_FILE_NAME, StoreKey,
    open_node, open_sealed_store, plant, plant_sealed, sealed_choice,
    wrong_length_strategy,
};
use crate::support::test_device::fail;

const STORE_CASES: u32 = 24;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASES))]

    #[test]
    fn test_read_stored_identity_property_keeps_the_secret_bytes(
        secret in vec(any::<u8>(), IDENTITY_SECRET_LENGTH),
        key in any::<StoreKey>(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let plain_path = directory.path().join(PLAIN_IDENTITY_FILE_NAME);
        plant(&plain_path, &secret)?;
        let sealed_path = directory.path().join(SEALED_IDENTITY_FILE_NAME);
        plant_sealed(&sealed_path, &key, &secret)?;

        let plain = FileIdentityStore::new(plain_path).load_identity();
        let sealed = open_sealed_store(&directory, &key)?.load_identity();

        let plain = plain.map_err(fail)?.ok_or_else(|| fail("none"))?;
        let sealed = sealed.map_err(fail)?.ok_or_else(|| fail("none"))?;
        let plain_secret = plain.secret_bytes();
        prop_assert_eq!(plain_secret.as_slice(), secret.as_slice());
        prop_assert_eq!(plain.device_id(), sealed.device_id());
    }

    #[test]
    fn test_read_stored_identity_property_a_wrong_length_is_damaged(
        secret in wrong_length_strategy(IDENTITY_SECRET_LENGTH),
        key in any::<StoreKey>(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let plain_path = directory.path().join(PLAIN_IDENTITY_FILE_NAME);
        plant(&plain_path, &secret)?;
        let sealed_path = directory.path().join(SEALED_IDENTITY_FILE_NAME);
        plant_sealed(&sealed_path, &key, &secret)?;

        let plain = FileIdentityStore::new(plain_path).load_identity();
        let sealed = open_sealed_store(&directory, &key)?.load_identity();

        let is_plain_damaged =
            matches!(plain, Err(IdentityStoreError::DamagedIdentity));
        let is_sealed_damaged =
            matches!(sealed, Err(IdentityStoreError::DamagedIdentity));
        prop_assert!(is_plain_damaged, "{:?}", plain);
        prop_assert!(is_sealed_damaged, "{:?}", sealed);
    }

    #[test]
    fn test_read_stored_identity_property_the_node_finds_a_planted_one(
        secret in vec(any::<u8>(), IDENTITY_SECRET_LENGTH),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let node =
            open_node(&directory, IdentityStoreChoice::File).map_err(fail)?;
        let identity_path = node.device_files().identity_path();
        plant(&identity_path, &secret)?;

        let found = node.find_identity().map_err(fail)?;

        let stored = FileIdentityStore::new(identity_path).load_identity();
        let stored = stored.map_err(fail)?.ok_or_else(|| fail("none"))?;
        let found = found.ok_or_else(|| fail("the node found none"))?;
        prop_assert_eq!(found.device_id(), stored.device_id());
    }

    #[test]
    fn test_read_stored_peer_secret_property_keeps_the_secret_bytes(
        secret in any::<[u8; PEER_SECRET_LENGTH]>(),
        key in any::<StoreKey>(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let plain_identity = directory.path().join(PLAIN_IDENTITY_FILE_NAME);
        let plain_path = directory.path().join(PLAIN_PEER_SECRET_FILE_NAME);
        plant(&plain_path, &secret)?;
        let sealed_path = directory.path().join(SEALED_PEER_SECRET_FILE_NAME);
        plant_sealed(&sealed_path, &key, &secret)?;

        let plain = FileIdentityStore::new(plain_identity).load_peer_secret();
        let sealed = open_sealed_store(&directory, &key)?.load_peer_secret();

        let plain = plain.map_err(fail)?.ok_or_else(|| fail("none"))?;
        let sealed = sealed.map_err(fail)?.ok_or_else(|| fail("none"))?;
        prop_assert_eq!(*plain, secret);
        prop_assert_eq!(*sealed, secret);
    }

    #[test]
    fn test_read_stored_peer_secret_property_a_wrong_length_is_damaged(
        secret in wrong_length_strategy(PEER_SECRET_LENGTH),
        key in any::<StoreKey>(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let plain_identity = directory.path().join(PLAIN_IDENTITY_FILE_NAME);
        let plain_path = directory.path().join(PLAIN_PEER_SECRET_FILE_NAME);
        plant(&plain_path, &secret)?;
        let sealed_path = directory.path().join(SEALED_PEER_SECRET_FILE_NAME);
        plant_sealed(&sealed_path, &key, &secret)?;

        let plain = FileIdentityStore::new(plain_identity).load_peer_secret();
        let sealed = open_sealed_store(&directory, &key)?.load_peer_secret();

        let is_plain_damaged =
            matches!(plain, Err(IdentityStoreError::DamagedPeerSecret));
        let is_sealed_damaged =
            matches!(sealed, Err(IdentityStoreError::DamagedPeerSecret));
        prop_assert!(is_plain_damaged, "{:?}", plain);
        prop_assert!(is_sealed_damaged, "{:?}", sealed);
    }

    #[test]
    fn test_read_stored_peer_secret_property_the_node_keeps_one_secret(
        key in any::<StoreKey>(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let node =
            open_node(&directory, sealed_choice(&key)).map_err(fail)?;

        let first = node.find_or_create_peer_secret().map_err(fail)?;
        let second = node.find_or_create_peer_secret().map_err(fail)?;

        prop_assert_eq!(*first, *second);
        let sealed = open_sealed_store(&directory, &key)?.load_peer_secret();
        let sealed = sealed.map_err(fail)?.ok_or_else(|| fail("none"))?;
        prop_assert_eq!(*sealed, *first);
    }
}
