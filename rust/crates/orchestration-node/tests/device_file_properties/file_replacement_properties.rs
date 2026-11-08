use std::fs;
use std::sync::atomic::{AtomicBool, Ordering};
use std::thread;

use orchestration_node::identity_store::{
    EncryptedFileIdentityStore, FileIdentityStore, IdentityStore,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::device_folder::{
    SERVER_FILE_NAME, create_device_folder, list_file_names,
    list_unfinished_file_names, open_device_files,
};
use crate::record_strategies::{account_strategy, app_server_strategy};
use crate::sealed_store_desk::{
    PEER_SECRET_FILE_NAME, PeerSecretBytes, SEALED_CASE_COUNT, StoreKey,
    credential_strategy, open_sealed_store,
};
use crate::support::test_device::fail;

const LEAST_SAVES: usize = 2;
const MOST_SAVES: usize = 8;
const KEPT_FILE_NAME: &str = "kept.bin";
const PLAIN_IDENTITY_FILE_NAME: &str = "device-identity.key";
const PLAIN_CREDENTIAL_FILE_NAME: &str = "agent-credential.key";
const LONGEST_LARGE_CONTENT: usize = 1 << 20;

fn read_credentials_until_done(
    store: &EncryptedFileIdentityStore,
    allowed: &[Vec<u8>],
    is_writing: &AtomicBool,
) -> Result<usize, String> {
    let mut read_count = 0;
    while is_writing.load(Ordering::Acquire) {
        let loaded = store
            .load_agent_credential()
            .map_err(|error| error.to_string())?;
        let loaded_bytes = loaded.map(|loaded| loaded.to_vec());
        let is_saved = loaded_bytes
            .as_ref()
            .is_some_and(|loaded| allowed.contains(loaded));
        if !is_saved {
            return Err("a load found a credential nobody saved".to_owned());
        }
        read_count += 1;
    }
    Ok(read_count)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALED_CASE_COUNT))]

    #[test]
    fn test_replace_file_atomically_property_a_failure_leaves_no_stray(
        key in any::<StoreKey>(),
        peer_secret in any::<PeerSecretBytes>(),
        kept_content in vec(any::<u8>(), 0..64),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        let blocking_folder = folder.data_path.join(PEER_SECRET_FILE_NAME);
        fs::create_dir(&blocking_folder).map_err(fail)?;
        let kept_file = blocking_folder.join(KEPT_FILE_NAME);
        fs::write(&kept_file, &kept_content).map_err(fail)?;

        let saved = store.save_peer_secret(&peer_secret);

        prop_assert!(saved.is_err());
        let names = list_file_names(&folder.data_path)?;
        prop_assert_eq!(names, vec![PEER_SECRET_FILE_NAME.to_owned()]);
        prop_assert_eq!(fs::read(&kept_file).map_err(fail)?, kept_content);
    }

    #[test]
    fn test_replace_file_atomically_property_readers_see_whole_secrets(
        key in any::<StoreKey>(),
        credentials in vec(credential_strategy(), LEAST_SAVES..MOST_SAVES),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        store.save_agent_credential(&credentials[0]).map_err(fail)?;
        let is_writing = AtomicBool::new(true);

        let (save_outcome, reader_outcome) = thread::scope(|scope| {
            let reader = scope.spawn(|| {
                read_credentials_until_done(&store, &credentials, &is_writing)
            });
            let mut save_outcome = Ok(());
            for credential in &credentials {
                save_outcome = save_outcome
                    .and_then(|()| store.save_agent_credential(credential));
            }
            is_writing.store(false, Ordering::Release);
            let reader_outcome = reader
                .join()
                .unwrap_or_else(|_| Err("the reader panicked".to_owned()));
            (save_outcome, reader_outcome)
        });

        prop_assert!(save_outcome.is_ok(), "{:?}", save_outcome);
        prop_assert!(reader_outcome.is_ok(), "{:?}", reader_outcome);
        let unfinished = list_unfinished_file_names(&folder.data_path)?;
        prop_assert!(unfinished.is_empty(), "{:?}", unfinished);
    }

    #[test]
    fn test_replace_file_atomically_property_a_vanished_folder_stays_gone(
        account in account_strategy(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        fs::remove_dir_all(&folder.data_path).map_err(fail)?;

        let saved = files.save_account(&account);

        prop_assert!(saved.is_err(), "{:?}", saved);
        prop_assert!(!folder.data_path.exists());
    }

    #[test]
    fn test_write_then_rename_property_writes_the_exact_bytes(
        credential in vec(any::<u8>(), 0..LONGEST_LARGE_CONTENT),
    ) {
        let folder = create_device_folder()?;
        open_device_files(&folder)?;
        let identity_path = folder.data_path.join(PLAIN_IDENTITY_FILE_NAME);
        let store = FileIdentityStore::new(identity_path);

        store.save_agent_credential(&credential).map_err(fail)?;

        let stored_path = folder.data_path.join(PLAIN_CREDENTIAL_FILE_NAME);
        prop_assert_eq!(fs::read(stored_path).map_err(fail)?, credential);
    }

    #[test]
    fn test_write_then_rename_property_a_shorter_record_leaves_no_tail(
        longer in app_server_strategy(),
        shorter in app_server_strategy(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;

        files.save_app_server(&longer).map_err(fail)?;
        files.save_app_server(&shorter).map_err(fail)?;

        let stored_path = folder.data_path.join(SERVER_FILE_NAME);
        let stored_bytes = fs::read(stored_path).map_err(fail)?;
        let expected_bytes =
            serde_json::to_vec_pretty(&shorter).map_err(fail)?;
        prop_assert_eq!(stored_bytes, expected_bytes);
    }
}
