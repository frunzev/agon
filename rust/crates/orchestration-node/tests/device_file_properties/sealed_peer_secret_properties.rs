use std::fs;

use orchestration_node::identity_store::{IdentityStore, IdentityStoreError};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::device_folder::{create_device_folder, list_file_names};
use crate::sealed_store_desk::{
    AGENT_CREDENTIAL_FILE_NAME, PEER_SECRET_FILE_NAME, PEER_SECRET_LENGTH,
    PeerSecretBytes, SEALED_CASE_COUNT, StoreKey, credential_strategy,
    distinct_keys_strategy, find_files_holding, identity_strategy,
    open_sealed_store,
};
use crate::support::test_device::fail;

const MOST_SAVES: usize = 5;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALED_CASE_COUNT))]

    #[test]
    fn test_encrypted_file_identity_store_save_peer_secret_property_loads_back(
        key in any::<StoreKey>(),
        peer_secret in any::<PeerSecretBytes>(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;

        store.save_peer_secret(&peer_secret).map_err(fail)?;
        let reopened = open_sealed_store(&folder, &key)?;
        let loaded = reopened.load_peer_secret().map_err(fail)?;

        prop_assert_eq!(loaded.map(|loaded| *loaded), Some(peer_secret));
    }

    #[test]
    fn test_encrypted_file_identity_store_save_peer_secret_property_hides_it(
        key in any::<StoreKey>(),
        peer_secret in any::<PeerSecretBytes>(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;

        store.save_peer_secret(&peer_secret).map_err(fail)?;

        let holding = find_files_holding(&folder.data_path, &peer_secret)?;
        prop_assert!(holding.is_empty(), "{:?}", holding);
        let names = list_file_names(&folder.data_path)?;
        prop_assert_eq!(names, vec![PEER_SECRET_FILE_NAME.to_owned()]);
    }

    #[test]
    fn test_encrypted_file_identity_store_save_peer_secret_property_last_wins(
        key in any::<StoreKey>(),
        peer_secrets in vec(any::<PeerSecretBytes>(), 1..MOST_SAVES),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;

        for peer_secret in &peer_secrets {
            store.save_peer_secret(peer_secret).map_err(fail)?;
        }
        let loaded = store.load_peer_secret().map_err(fail)?;

        let last_saved = peer_secrets.last().copied();
        prop_assert_eq!(loaded.map(|loaded| *loaded), last_saved);
    }

    #[test]
    fn test_encrypted_file_identity_store_load_peer_secret_property_none_first(
        key in any::<StoreKey>(),
        identity in identity_strategy(),
        credential in credential_strategy(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        store.save_identity(&identity).map_err(fail)?;
        store.save_agent_credential(&credential).map_err(fail)?;

        let loaded = store.load_peer_secret().map_err(fail)?;

        prop_assert!(loaded.is_none());
    }

    #[test]
    fn test_encrypted_file_identity_store_load_peer_secret_property_key_bound(
        (key, other_key) in distinct_keys_strategy(),
        peer_secret in any::<PeerSecretBytes>(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        store.save_peer_secret(&peer_secret).map_err(fail)?;

        let other_store = open_sealed_store(&folder, &other_key)?;
        let loaded = other_store.load_peer_secret();

        let is_wrong_key =
            matches!(loaded, Err(IdentityStoreError::WrongStoreKey));
        prop_assert!(is_wrong_key, "{:?}", loaded.map(|_| ()));
        prop_assert!(store.load_peer_secret().map_err(fail)?.is_some());
    }

    #[test]
    fn test_encrypted_file_identity_store_load_peer_secret_property_size_bound(
        key in any::<StoreKey>(),
        credential in credential_strategy(),
    ) {
        prop_assume!(credential.len() != PEER_SECRET_LENGTH);
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        store.save_agent_credential(&credential).map_err(fail)?;
        let credential_path =
            folder.data_path.join(AGENT_CREDENTIAL_FILE_NAME);
        let peer_secret_path = folder.data_path.join(PEER_SECRET_FILE_NAME);
        fs::copy(credential_path, peer_secret_path).map_err(fail)?;

        let loaded = store.load_peer_secret();

        let is_damaged =
            matches!(loaded, Err(IdentityStoreError::DamagedPeerSecret));
        prop_assert!(is_damaged, "{:?}", loaded.map(|_| ()));
    }
}
