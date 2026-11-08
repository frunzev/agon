use orchestration_node::identity_store::{IdentityStore, IdentityStoreError};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::device_folder::{create_device_folder, list_file_names};
use crate::sealed_store_desk::{
    AGENT_CREDENTIAL_FILE_NAME, PeerSecretBytes, SEALED_CASE_COUNT, StoreKey,
    apply_damage, credential_strategy, damage_strategy,
    distinct_keys_strategy, find_files_holding, identity_strategy,
    open_sealed_store, searchable_credential_strategy,
};
use crate::support::test_device::fail;

const MOST_SAVES: usize = 5;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALED_CASE_COUNT))]

    #[test]
    fn test_encrypted_file_identity_store_save_agent_credential_property_round_trips(
        key in any::<StoreKey>(),
        credential in credential_strategy(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;

        store.save_agent_credential(&credential).map_err(fail)?;
        let reopened = open_sealed_store(&folder, &key)?;
        let loaded = reopened.load_agent_credential().map_err(fail)?;

        let loaded_bytes = loaded.map(|loaded| loaded.to_vec());
        prop_assert_eq!(loaded_bytes, Some(credential));
    }

    #[test]
    fn test_encrypted_file_identity_store_save_agent_credential_property_hides_it(
        key in any::<StoreKey>(),
        credential in searchable_credential_strategy(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;

        store.save_agent_credential(&credential).map_err(fail)?;

        let holding = find_files_holding(&folder.data_path, &credential)?;
        prop_assert!(holding.is_empty(), "{:?}", holding);
        let names = list_file_names(&folder.data_path)?;
        prop_assert_eq!(names, vec![AGENT_CREDENTIAL_FILE_NAME.to_owned()]);
    }

    #[test]
    fn test_encrypted_file_identity_store_save_agent_credential_property_last_wins(
        key in any::<StoreKey>(),
        credentials in vec(credential_strategy(), 1..MOST_SAVES),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;

        for credential in &credentials {
            store.save_agent_credential(credential).map_err(fail)?;
        }
        let loaded = store.load_agent_credential().map_err(fail)?;

        let loaded_bytes = loaded.map(|loaded| loaded.to_vec());
        prop_assert_eq!(loaded_bytes.as_ref(), credentials.last());
    }

    #[test]
    fn test_encrypted_file_identity_store_load_agent_credential_property_none_first(
        key in any::<StoreKey>(),
        identity in identity_strategy(),
        peer_secret in any::<PeerSecretBytes>(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        store.save_identity(&identity).map_err(fail)?;
        store.save_peer_secret(&peer_secret).map_err(fail)?;

        let loaded = store.load_agent_credential().map_err(fail)?;

        prop_assert!(loaded.is_none());
    }

    #[test]
    fn test_encrypted_file_identity_store_load_agent_credential_property_key_bound(
        (key, other_key) in distinct_keys_strategy(),
        credential in credential_strategy(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        store.save_agent_credential(&credential).map_err(fail)?;

        let other_store = open_sealed_store(&folder, &other_key)?;
        let loaded = other_store.load_agent_credential();

        let is_wrong_key =
            matches!(loaded, Err(IdentityStoreError::WrongStoreKey));
        prop_assert!(is_wrong_key, "{:?}", loaded.map(|_| ()));
        prop_assert!(store.load_agent_credential().map_err(fail)?.is_some());
    }

    #[test]
    fn test_encrypted_file_identity_store_load_agent_credential_property_damage_errs(
        key in any::<StoreKey>(),
        credential in credential_strategy(),
        damage in damage_strategy(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        store.save_agent_credential(&credential).map_err(fail)?;
        let sealed_path = folder.data_path.join(AGENT_CREDENTIAL_FILE_NAME);

        apply_damage(&sealed_path, &damage)?;
        let loaded = store.load_agent_credential();

        prop_assert!(loaded.is_err(), "{:?}", damage);
    }
}
