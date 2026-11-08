use orchestration_node::identity_store::{
    EncryptedFileIdentityStore, IdentityStore, IdentityStoreError,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::device_folder::{create_device_folder, list_file_names};
use crate::sealed_store_desk::{
    PeerSecretBytes, SEALED_CASE_COUNT, SEALED_IDENTITY_FILE_NAME,
    STORE_KEY_LENGTH, StoreKey, apply_damage, credential_strategy,
    damage_strategy, distinct_keys_strategy, find_files_holding,
    identity_strategy, open_sealed_store,
};
use crate::support::test_device::fail;

const LONGEST_TRIED_KEY: usize = 80;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALED_CASE_COUNT))]

    #[test]
    fn test_encrypted_file_identity_store_new_property_needs_a_32_byte_key(
        key_bytes in vec(any::<u8>(), 0..LONGEST_TRIED_KEY),
    ) {
        let folder = create_device_folder()?;
        let identity_path = folder.data_path.join(SEALED_IDENTITY_FILE_NAME);

        let opened =
            EncryptedFileIdentityStore::new(identity_path, &key_bytes);

        if key_bytes.len() == STORE_KEY_LENGTH {
            prop_assert!(opened.is_ok(), "{:?}", opened);
        } else {
            let is_invalid_key =
                matches!(opened, Err(IdentityStoreError::InvalidStoreKey));
            prop_assert!(is_invalid_key, "{:?}", opened);
        }
    }

    #[test]
    fn test_encrypted_file_identity_store_new_property_touches_no_file(
        key in any::<StoreKey>(),
    ) {
        let folder = create_device_folder()?;
        let names_before = list_file_names(folder.root_path())?;
        let identity_path = folder.data_path.join(SEALED_IDENTITY_FILE_NAME);

        EncryptedFileIdentityStore::new(identity_path, &key).map_err(fail)?;

        prop_assert_eq!(list_file_names(folder.root_path())?, names_before);
        prop_assert!(!folder.data_path.exists());
    }

    #[test]
    fn test_encrypted_file_identity_store_new_property_debug_hides_the_key(
        key in any::<StoreKey>(),
    ) {
        let folder = create_device_folder()?;

        let store = open_sealed_store(&folder, &key)?;

        let shown = format!("{store:?}");
        prop_assert!(!shown.contains(&hex::encode(key)), "{}", shown);
        prop_assert!(!shown.contains(&format!("{key:?}")), "{}", shown);
    }

    #[test]
    fn test_encrypted_file_identity_store_save_identity_property_round_trips(
        key in any::<StoreKey>(),
        identity in identity_strategy(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;

        store.save_identity(&identity).map_err(fail)?;
        let reopened = open_sealed_store(&folder, &key)?;
        let loaded = reopened.load_identity().map_err(fail)?;

        let loaded_public = loaded.map(|loaded| loaded.public_identity());
        prop_assert_eq!(loaded_public, Some(identity.public_identity()));
    }

    #[test]
    fn test_encrypted_file_identity_store_save_identity_property_hides_it(
        key in any::<StoreKey>(),
        identity in identity_strategy(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;

        store.save_identity(&identity).map_err(fail)?;

        let secret = identity.secret_bytes();
        let secret_bytes = secret.as_slice();
        let holding = find_files_holding(&folder.data_path, secret_bytes)?;
        prop_assert!(holding.is_empty(), "{:?}", holding);
        let names = list_file_names(&folder.data_path)?;
        prop_assert_eq!(names, vec![SEALED_IDENTITY_FILE_NAME.to_owned()]);
    }

    #[test]
    fn test_encrypted_file_identity_store_load_identity_property_none_first(
        key in any::<StoreKey>(),
        peer_secret in any::<PeerSecretBytes>(),
        credential in credential_strategy(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        store.save_peer_secret(&peer_secret).map_err(fail)?;
        store.save_agent_credential(&credential).map_err(fail)?;

        let loaded = store.load_identity().map_err(fail)?;

        prop_assert!(loaded.is_none());
    }

    #[test]
    fn test_encrypted_file_identity_store_load_identity_property_key_bound(
        (key, other_key) in distinct_keys_strategy(),
        identity in identity_strategy(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        store.save_identity(&identity).map_err(fail)?;

        let other_store = open_sealed_store(&folder, &other_key)?;
        let loaded = other_store.load_identity();

        let is_wrong_key =
            matches!(loaded, Err(IdentityStoreError::WrongStoreKey));
        prop_assert!(is_wrong_key, "{:?}", loaded.map(|_| ()));
        prop_assert!(store.load_identity().map_err(fail)?.is_some());
    }

    #[test]
    fn test_encrypted_file_identity_store_load_identity_property_damage_errs(
        key in any::<StoreKey>(),
        identity in identity_strategy(),
        damage in damage_strategy(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        store.save_identity(&identity).map_err(fail)?;
        let sealed_path = folder.data_path.join(SEALED_IDENTITY_FILE_NAME);

        apply_damage(&sealed_path, &damage)?;
        let loaded = store.load_identity();

        prop_assert!(loaded.is_err(), "{:?}", damage);
    }
}

#[cfg(unix)]
mod owner_only {
    use std::fs;

    use orchestration_node::identity_store::IdentityStore;
    use proptest::prelude::*;

    use crate::device_folder::{
        create_device_folder, list_unfinished_file_names, open_device_files,
    };
    use crate::sealed_store_desk::{
        SEALED_CASE_COUNT, SEALED_IDENTITY_FILE_NAME, StoreKey,
        identity_strategy, open_sealed_store, read_permission_bits,
    };
    use crate::support::test_device::fail;

    const OWNER_ONLY_BITS: u32 = 0o600;
    const SHARED_BITS: u32 = 0o644;

    proptest! {
        #![proptest_config(ProptestConfig::with_cases(SEALED_CASE_COUNT))]

        #[test]
        fn test_encrypted_file_identity_store_save_identity_property_owner_only(
            key in any::<StoreKey>(),
            identity in identity_strategy(),
            older_bytes in proptest::collection::vec(any::<u8>(), 0..64),
        ) {
            use std::os::unix::fs::PermissionsExt;

            let folder = create_device_folder()?;
            open_device_files(&folder)?;
            let sealed_path = folder.data_path.join(SEALED_IDENTITY_FILE_NAME);
            fs::write(&sealed_path, &older_bytes).map_err(fail)?;
            let shared = fs::Permissions::from_mode(SHARED_BITS);
            fs::set_permissions(&sealed_path, shared).map_err(fail)?;
            let store = open_sealed_store(&folder, &key)?;

            store.save_identity(&identity).map_err(fail)?;

            let permission_bits = read_permission_bits(&sealed_path)?;
            prop_assert_eq!(permission_bits, OWNER_ONLY_BITS);
            let unfinished = list_unfinished_file_names(&folder.data_path)?;
            prop_assert!(unfinished.is_empty(), "{:?}", unfinished);
        }
    }
}
