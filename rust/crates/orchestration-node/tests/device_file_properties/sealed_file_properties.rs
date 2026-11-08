use std::fs;
use std::sync::Barrier;
use std::thread;

use orchestration_node::identity_store::{
    EncryptedFileIdentityStore, IdentityStore, IdentityStoreError,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::device_folder::{
    create_device_folder, list_file_names, list_unfinished_file_names,
};
use crate::sealed_store_desk::{
    AGENT_CREDENTIAL_FILE_NAME, PEER_SECRET_FILE_NAME, PeerSecretBytes,
    SEALED_CASE_COUNT, SEALED_IDENTITY_FILE_NAME, StoreKey,
    credential_strategy, open_sealed_store,
};
use crate::support::test_device::fail;

const NONCE_LENGTH: usize = 24;
const AUTHENTICATION_TAG_LENGTH: usize = 16;
const SEALING_OVERHEAD: usize = NONCE_LENGTH + AUTHENTICATION_TAG_LENGTH;
const LEAST_WRITERS: usize = 2;
const MOST_WRITERS: usize = 6;
const SAVES_PER_WRITER: usize = 10;
const MOVED_FOLDER_NAME: &str = "moved";

fn save_repeatedly(
    store: &EncryptedFileIdentityStore,
    credential: &[u8],
    start_together: &Barrier,
) -> Result<(), String> {
    start_together.wait();
    for _ in 0..SAVES_PER_WRITER {
        store
            .save_agent_credential(credential)
            .map_err(|error| error.to_string())?;
    }
    Ok(())
}

fn save_in_parallel(
    store: &EncryptedFileIdentityStore,
    credentials: &[Vec<u8>],
) -> Vec<Result<(), String>> {
    let start_together = Barrier::new(credentials.len());
    thread::scope(|scope| {
        let mut writers = Vec::new();
        for credential in credentials {
            let start_together = &start_together;
            writers.push(scope.spawn(move || {
                save_repeatedly(store, credential, start_together)
            }));
        }
        let mut outcomes = Vec::new();
        for writer in writers {
            outcomes.push(
                writer
                    .join()
                    .unwrap_or_else(|_| Err("a writer panicked".to_owned())),
            );
        }
        outcomes
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALED_CASE_COUNT))]

    #[test]
    fn test_write_sealed_property_each_save_uses_a_fresh_nonce(
        key in any::<StoreKey>(),
        peer_secret in any::<PeerSecretBytes>(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        let sealed_path = folder.data_path.join(PEER_SECRET_FILE_NAME);

        store.save_peer_secret(&peer_secret).map_err(fail)?;
        let first_sealed = fs::read(&sealed_path).map_err(fail)?;
        store.save_peer_secret(&peer_secret).map_err(fail)?;
        let second_sealed = fs::read(&sealed_path).map_err(fail)?;

        prop_assert_ne!(first_sealed, second_sealed);
    }

    #[test]
    fn test_write_sealed_property_adds_a_fixed_overhead(
        key in any::<StoreKey>(),
        credential in credential_strategy(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;

        store.save_agent_credential(&credential).map_err(fail)?;

        let sealed_path = folder.data_path.join(AGENT_CREDENTIAL_FILE_NAME);
        let sealed_length = fs::metadata(sealed_path).map_err(fail)?.len();
        let expected_length = credential.len() + SEALING_OVERHEAD;
        let sealed_length = usize::try_from(sealed_length).ok();
        prop_assert_eq!(sealed_length, Some(expected_length));
    }

    #[test]
    fn test_write_sealed_property_parallel_saves_all_succeed(
        key in any::<StoreKey>(),
        credentials in vec(credential_strategy(), LEAST_WRITERS..MOST_WRITERS),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;

        let outcomes = save_in_parallel(&store, &credentials);

        for outcome in outcomes {
            prop_assert!(outcome.is_ok(), "{:?}", outcome);
        }
        let loaded = store.load_agent_credential().map_err(fail)?;
        let loaded_bytes = loaded.map(|loaded| loaded.to_vec());
        let is_saved = loaded_bytes
            .as_ref()
            .is_some_and(|loaded| credentials.contains(loaded));
        prop_assert!(is_saved);
        let unfinished = list_unfinished_file_names(&folder.data_path)?;
        prop_assert!(unfinished.is_empty(), "{:?}", unfinished);
    }

    #[test]
    fn test_read_sealed_property_a_folder_in_place_is_a_file_error(
        key in any::<StoreKey>(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        let sealed_path = folder.data_path.join(PEER_SECRET_FILE_NAME);
        fs::create_dir(&sealed_path).map_err(fail)?;

        let loaded = store.load_peer_secret();

        let is_file_error = matches!(loaded, Err(IdentityStoreError::File(_)));
        prop_assert!(is_file_error, "{:?}", loaded.map(|_| ()));
        prop_assert!(sealed_path.is_dir());
    }

    #[test]
    fn test_read_sealed_property_a_short_file_is_refused_not_missing(
        key in any::<StoreKey>(),
        short_bytes in vec(any::<u8>(), 0..NONCE_LENGTH),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        let sealed_path = folder.data_path.join(AGENT_CREDENTIAL_FILE_NAME);
        fs::write(&sealed_path, &short_bytes).map_err(fail)?;

        let loaded = store.load_agent_credential();

        let is_wrong_key =
            matches!(loaded, Err(IdentityStoreError::WrongStoreKey));
        prop_assert!(is_wrong_key, "{:?}", loaded.map(|_| ()));
    }

    #[test]
    fn test_read_sealed_property_a_moved_data_folder_still_opens(
        key in any::<StoreKey>(),
        peer_secret in any::<PeerSecretBytes>(),
        credential in credential_strategy(),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        store.save_peer_secret(&peer_secret).map_err(fail)?;
        store.save_agent_credential(&credential).map_err(fail)?;
        let names_before = list_file_names(&folder.data_path)?;

        let moved_path = folder.root_path().join(MOVED_FOLDER_NAME);
        fs::rename(&folder.data_path, &moved_path).map_err(fail)?;
        let moved_identity_path = moved_path.join(SEALED_IDENTITY_FILE_NAME);
        let moved_store =
            EncryptedFileIdentityStore::new(moved_identity_path, &key)
                .map_err(fail)?;

        let loaded_peer = moved_store.load_peer_secret().map_err(fail)?;
        prop_assert_eq!(loaded_peer.map(|loaded| *loaded), Some(peer_secret));
        let loaded_credential =
            moved_store.load_agent_credential().map_err(fail)?;
        let loaded_bytes = loaded_credential.map(|loaded| loaded.to_vec());
        prop_assert_eq!(loaded_bytes, Some(credential));
        prop_assert_eq!(list_file_names(&moved_path)?, names_before);
    }
}
