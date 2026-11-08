use std::fs;
use std::os::unix::fs::PermissionsExt;

use orchestration_node::device_files::HostedServerRecord;
use orchestration_node::identity_store::{FileIdentityStore, IdentityStore};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::device_folder::{
    DeviceFolder, HOSTED_SERVER_FILE_NAME, create_device_folder,
    link_to_outside_file, open_device_files,
};
use crate::record_strategies::account_strategy;
use crate::sealed_store_desk::{
    PEER_SECRET_FILE_NAME, PeerSecretBytes, SEALED_CASE_COUNT, StoreKey,
    credential_strategy, identity_strategy, open_sealed_store,
    read_permission_bits,
};
use crate::support::test_device::fail;

const OWNER_ONLY_BITS: u32 = 0o600;
const OWNER_READ_WRITE_BITS: u32 = 0o600;
const SHARED_BITS: u32 = 0o666;
const LOCKED_FOLDER_BITS: u32 = 0o500;
const OPEN_FOLDER_BITS: u32 = 0o700;
const MOST_STALE_FILES: usize = 4;
const MOST_SAVES: usize = 5;
const PLAIN_CREDENTIAL_FILE_NAME: &str = "agent-credential.key";
const PLAIN_SECRET_FILE_NAMES: [&str; 3] = [
    "device-identity.key",
    "peer-secret.key",
    PLAIN_CREDENTIAL_FILE_NAME,
];
const STALE_FILE_PATTERN: &str = "account\\.[0-9a-f]{32}\\.incomplete";

fn open_plain_store(
    folder: &DeviceFolder,
) -> Result<FileIdentityStore, TestCaseError> {
    let files = open_device_files(folder)?;
    Ok(FileIdentityStore::new(files.identity_path()))
}

fn set_permission_bits(
    path: &std::path::Path,
    bits: u32,
) -> Result<(), TestCaseError> {
    fs::set_permissions(path, fs::Permissions::from_mode(bits)).map_err(fail)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALED_CASE_COUNT))]

    #[test]
    fn test_write_then_rename_property_a_linked_secret_stays_inside(
        key in any::<StoreKey>(),
        peer_secret in any::<PeerSecretBytes>(),
        outside_content in vec(any::<u8>(), 0..64),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        let outside_file = link_to_outside_file(
            &folder,
            PEER_SECRET_FILE_NAME,
            &outside_content,
        )?;

        store.save_peer_secret(&peer_secret).map_err(fail)?;

        let kept = fs::read(&outside_file).map_err(fail)?;
        prop_assert_eq!(kept, outside_content);
        let loaded = store.load_peer_secret().map_err(fail)?;
        prop_assert_eq!(loaded.map(|loaded| *loaded), Some(peer_secret));
    }

    #[test]
    fn test_new_file_options_property_stale_unfinished_files_never_block(
        stale_names in vec(STALE_FILE_PATTERN, 1..MOST_STALE_FILES),
        stale_content in vec(any::<u8>(), 0..64),
        account in account_strategy(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        for stale_name in &stale_names {
            fs::write(folder.data_path.join(stale_name), &stale_content)
                .map_err(fail)?;
        }

        files.save_account(&account).map_err(fail)?;

        prop_assert_eq!(files.load_account().map_err(fail)?, Some(account));
        for stale_name in &stale_names {
            let kept = fs::read(folder.data_path.join(stale_name))
                .map_err(fail)?;
            prop_assert_eq!(&kept, &stale_content);
        }
    }

    #[test]
    fn test_new_file_options_property_the_owner_can_read_and_write(
        port in any::<u16>(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;

        files.save_hosted_server(&HostedServerRecord { port }).map_err(fail)?;

        let record_path = folder.data_path.join(HOSTED_SERVER_FILE_NAME);
        let permission_bits = read_permission_bits(&record_path)?;
        let owner_bits = permission_bits & OWNER_READ_WRITE_BITS;
        prop_assert_eq!(owner_bits, OWNER_READ_WRITE_BITS);
    }

    #[test]
    fn test_new_file_options_property_a_locked_folder_keeps_the_record(
        first_port in any::<u16>(),
        second_port in any::<u16>(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        let first_record = HostedServerRecord { port: first_port };
        files.save_hosted_server(&first_record).map_err(fail)?;
        set_permission_bits(&folder.data_path, LOCKED_FOLDER_BITS)?;

        let second_record = HostedServerRecord { port: second_port };
        let saved = files.save_hosted_server(&second_record);
        let loaded = files.load_hosted_server();

        set_permission_bits(&folder.data_path, OPEN_FOLDER_BITS)?;
        prop_assert!(saved.is_err(), "{:?}", saved);
        prop_assert_eq!(loaded.map_err(fail)?, Some(first_record));
    }

    #[test]
    fn test_owner_only_file_options_property_plain_secrets_are_private(
        identity in identity_strategy(),
        peer_secret in any::<PeerSecretBytes>(),
        credential in credential_strategy(),
    ) {
        let folder = create_device_folder()?;
        let store = open_plain_store(&folder)?;

        store.save_identity(&identity).map_err(fail)?;
        store.save_peer_secret(&peer_secret).map_err(fail)?;
        store.save_agent_credential(&credential).map_err(fail)?;

        for secret_name in PLAIN_SECRET_FILE_NAMES {
            let secret_path = folder.data_path.join(secret_name);
            let permission_bits = read_permission_bits(&secret_path)?;
            prop_assert_eq!(
                permission_bits,
                OWNER_ONLY_BITS,
                "{}",
                secret_name
            );
        }
    }

    #[test]
    fn test_owner_only_file_options_property_a_shared_file_becomes_private(
        key in any::<StoreKey>(),
        peer_secret in any::<PeerSecretBytes>(),
        older_bytes in vec(any::<u8>(), 0..64),
    ) {
        let folder = create_device_folder()?;
        let store = open_sealed_store(&folder, &key)?;
        let sealed_path = folder.data_path.join(PEER_SECRET_FILE_NAME);
        fs::write(&sealed_path, &older_bytes).map_err(fail)?;
        set_permission_bits(&sealed_path, SHARED_BITS)?;

        store.save_peer_secret(&peer_secret).map_err(fail)?;

        prop_assert_eq!(read_permission_bits(&sealed_path)?, OWNER_ONLY_BITS);
    }

    #[test]
    fn test_owner_only_file_options_property_every_save_stays_private(
        credentials in vec(credential_strategy(), 1..MOST_SAVES),
        forget_between in vec(any::<bool>(), MOST_SAVES),
    ) {
        let folder = create_device_folder()?;
        let store = open_plain_store(&folder)?;
        let credential_path =
            folder.data_path.join(PLAIN_CREDENTIAL_FILE_NAME);

        let save_steps = credentials.iter().zip(&forget_between);
        for (credential, should_forget) in save_steps {
            if *should_forget {
                store.forget_agent_credential().map_err(fail)?;
            }
            store.save_agent_credential(credential).map_err(fail)?;
            let permission_bits = read_permission_bits(&credential_path)?;
            prop_assert_eq!(permission_bits, OWNER_ONLY_BITS);
        }
    }
}
