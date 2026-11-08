use orchestration_node::identity_store::{
    EncryptedFileIdentityStore, IdentityStore, IdentityStoreError,
};
use orchestration_security::identity::DeviceIdentity;
use proptest::prelude::*;

use crate::device_folder::{create_device_folder, list_file_names};
use crate::sealed_store_desk::{
    AGENT_CREDENTIAL_FILE_NAME, PEER_SECRET_FILE_NAME, PeerSecretBytes,
    SEALED_CASE_COUNT, SEALED_IDENTITY_FILE_NAME, StoreKey,
    credential_strategy, identity_strategy, open_sealed_store,
};
use crate::support::test_device::fail;

const MOST_REPEATS: usize = 4;

type ForgetSlot =
    fn(&EncryptedFileIdentityStore) -> Result<(), IdentityStoreError>;

#[derive(Debug, PartialEq, Eq)]
struct LoadedSlots {
    identity: Option<Vec<u8>>,
    peer_secret: Option<PeerSecretBytes>,
    credential: Option<Vec<u8>>,
}

#[derive(Debug)]
struct SavedSlots {
    identity: DeviceIdentity,
    peer_secret: PeerSecretBytes,
    credential: Vec<u8>,
}

fn saved_slots_strategy() -> impl Strategy<Value = SavedSlots> {
    (
        identity_strategy(),
        any::<PeerSecretBytes>(),
        credential_strategy(),
    )
        .prop_map(|(identity, peer_secret, credential)| SavedSlots {
            identity,
            peer_secret,
            credential,
        })
}

fn save_every_slot(
    store: &EncryptedFileIdentityStore,
    slots: &SavedSlots,
) -> Result<(), TestCaseError> {
    store.save_identity(&slots.identity).map_err(fail)?;
    store.save_peer_secret(&slots.peer_secret).map_err(fail)?;
    store.save_agent_credential(&slots.credential).map_err(fail)
}

fn load_every_slot(
    store: &EncryptedFileIdentityStore,
) -> Result<LoadedSlots, TestCaseError> {
    let identity = store.load_identity().map_err(fail)?;
    let peer_secret = store.load_peer_secret().map_err(fail)?;
    let credential = store.load_agent_credential().map_err(fail)?;
    Ok(LoadedSlots {
        identity: identity.map(|loaded| loaded.secret_bytes().to_vec()),
        peer_secret: peer_secret.map(|loaded| *loaded),
        credential: credential.map(|loaded| loaded.to_vec()),
    })
}

fn expect_every_slot(slots: &SavedSlots) -> LoadedSlots {
    LoadedSlots {
        identity: Some(slots.identity.secret_bytes().to_vec()),
        peer_secret: Some(slots.peer_secret),
        credential: Some(slots.credential.clone()),
    }
}

fn expect_after_forgetting(
    slots: &SavedSlots,
    forgotten_file_name: &str,
) -> LoadedSlots {
    let mut expected = expect_every_slot(slots);
    match forgotten_file_name {
        SEALED_IDENTITY_FILE_NAME => expected.identity = None,
        PEER_SECRET_FILE_NAME => expected.peer_secret = None,
        _ => expected.credential = None,
    }
    expected
}

fn check_forgets_only_its_slot(
    key: &StoreKey,
    slots: &SavedSlots,
    forget: ForgetSlot,
    forgotten_file_name: &str,
) -> Result<(), TestCaseError> {
    let folder = create_device_folder()?;
    let store = open_sealed_store(&folder, key)?;
    save_every_slot(&store, slots)?;

    forget(&store).map_err(fail)?;

    let loaded = load_every_slot(&store)?;
    let expected = expect_after_forgetting(slots, forgotten_file_name);
    prop_assert_eq!(loaded, expected);
    let names = list_file_names(&folder.data_path)?;
    prop_assert!(!names.contains(&forgotten_file_name.to_owned()));
    prop_assert_eq!(names.len(), 2);
    Ok(())
}

fn check_repeating_is_harmless(
    key: &StoreKey,
    forget: ForgetSlot,
    repeats: usize,
) -> Result<(), TestCaseError> {
    let folder = create_device_folder()?;
    let store = open_sealed_store(&folder, key)?;

    for _ in 0..repeats {
        forget(&store).map_err(fail)?;
    }

    prop_assert!(list_file_names(&folder.data_path)?.is_empty());
    Ok(())
}

fn check_a_fresh_save_comes_back(
    key: &StoreKey,
    slots: &SavedSlots,
    forget: ForgetSlot,
) -> Result<(), TestCaseError> {
    let folder = create_device_folder()?;
    let store = open_sealed_store(&folder, key)?;
    save_every_slot(&store, slots)?;

    forget(&store).map_err(fail)?;
    save_every_slot(&store, slots)?;

    let loaded = load_every_slot(&store)?;
    prop_assert_eq!(loaded, expect_every_slot(slots));
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALED_CASE_COUNT))]

    #[test]
    fn test_encrypted_file_identity_store_forget_identity_property_only_its_slot(
        key in any::<StoreKey>(),
        slots in saved_slots_strategy(),
    ) {
        check_forgets_only_its_slot(
            &key,
            &slots,
            EncryptedFileIdentityStore::forget_identity,
            SEALED_IDENTITY_FILE_NAME,
        )?;
    }

    #[test]
    fn test_encrypted_file_identity_store_forget_identity_property_repeats_fine(
        key in any::<StoreKey>(),
        repeats in 1..MOST_REPEATS,
    ) {
        check_repeating_is_harmless(
            &key,
            EncryptedFileIdentityStore::forget_identity,
            repeats,
        )?;
    }

    #[test]
    fn test_encrypted_file_identity_store_forget_identity_property_saves_again(
        key in any::<StoreKey>(),
        slots in saved_slots_strategy(),
    ) {
        check_a_fresh_save_comes_back(
            &key,
            &slots,
            EncryptedFileIdentityStore::forget_identity,
        )?;
    }

    #[test]
    fn test_encrypted_file_identity_store_forget_peer_secret_property_only_its_slot(
        key in any::<StoreKey>(),
        slots in saved_slots_strategy(),
    ) {
        check_forgets_only_its_slot(
            &key,
            &slots,
            EncryptedFileIdentityStore::forget_peer_secret,
            PEER_SECRET_FILE_NAME,
        )?;
    }

    #[test]
    fn test_encrypted_file_identity_store_forget_peer_secret_property_repeats_fine(
        key in any::<StoreKey>(),
        repeats in 1..MOST_REPEATS,
    ) {
        check_repeating_is_harmless(
            &key,
            EncryptedFileIdentityStore::forget_peer_secret,
            repeats,
        )?;
    }

    #[test]
    fn test_encrypted_file_identity_store_forget_peer_secret_property_saves_again(
        key in any::<StoreKey>(),
        slots in saved_slots_strategy(),
    ) {
        check_a_fresh_save_comes_back(
            &key,
            &slots,
            EncryptedFileIdentityStore::forget_peer_secret,
        )?;
    }

    #[test]
    fn test_encrypted_file_identity_store_forget_agent_credential_property_only_its_slot(
        key in any::<StoreKey>(),
        slots in saved_slots_strategy(),
    ) {
        check_forgets_only_its_slot(
            &key,
            &slots,
            EncryptedFileIdentityStore::forget_agent_credential,
            AGENT_CREDENTIAL_FILE_NAME,
        )?;
    }

    #[test]
    fn test_encrypted_file_identity_store_forget_agent_credential_property_repeats_fine(
        key in any::<StoreKey>(),
        repeats in 1..MOST_REPEATS,
    ) {
        check_repeating_is_harmless(
            &key,
            EncryptedFileIdentityStore::forget_agent_credential,
            repeats,
        )?;
    }

    #[test]
    fn test_encrypted_file_identity_store_forget_agent_credential_property_saves_again(
        key in any::<StoreKey>(),
        slots in saved_slots_strategy(),
    ) {
        check_a_fresh_save_comes_back(
            &key,
            &slots,
            EncryptedFileIdentityStore::forget_agent_credential,
        )?;
    }
}
