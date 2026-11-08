use std::collections::BTreeSet;
use std::io::{Error, ErrorKind};

use orchestration_node::identity_store::{
    FileIdentityStore, IdentityStore, IdentityStoreError,
};
use orchestration_node::node_configuration::IdentityStoreChoice;
use orchestration_security::identity::IDENTITY_SECRET_LENGTH;
use proptest::prelude::*;
use tempfile::TempDir;

use crate::identity_files::{
    PLAIN_IDENTITY_FILE_NAME, StoreKey, open_node, open_sealed_store, plant,
    sealed_choice, wrong_length_strategy,
};
use crate::support::test_device::fail;

const OPENING_CASES: u32 = 16;
const MOST_IDENTITY_CALLS: usize = 4;
const MESSAGE_PATTERN: &str = "[a-z][a-z ]{0,30}";
const INVALID_KEY_PATTERN: &str =
    "[0-9a-fA-F]{0,62}|[0-9a-f]{65,80}|[g-z ]{1,64}|[0-9a-f]{63}";

fn every_error() -> Vec<IdentityStoreError> {
    vec![
        IdentityStoreError::Keychain("locked".to_owned()),
        IdentityStoreError::File(Error::other("disk")),
        IdentityStoreError::DamagedIdentity,
        IdentityStoreError::DamagedPeerSecret,
        IdentityStoreError::DamagedAgentCredential,
        IdentityStoreError::InvalidStoreKey,
        IdentityStoreError::WrongStoreKey,
        IdentityStoreError::SealingFailed,
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(OPENING_CASES))]

    #[test]
    fn test_identity_store_error_fmt_property_every_message_is_distinct(
        message in MESSAGE_PATTERN,
    ) {
        let mut texts = BTreeSet::new();
        for error in every_error() {
            let text = error.to_string();
            let first_character = text.chars().next().unwrap_or('X');
            prop_assert!(first_character.is_lowercase(), "{}", text);
            texts.insert(text);
        }

        prop_assert_eq!(texts.len(), every_error().len());
        let keychain = IdentityStoreError::Keychain(message.clone());
        prop_assert!(keychain.to_string().ends_with(&message));
    }

    #[test]
    fn test_identity_store_error_fmt_property_a_file_error_keeps_its_cause(
        message in MESSAGE_PATTERN,
    ) {
        let cause = Error::new(ErrorKind::PermissionDenied, message.clone());

        let error = IdentityStoreError::from(cause);

        let IdentityStoreError::File(kept) = &error else {
            return Err(fail("not a file error"));
        };
        prop_assert_eq!(kept.kind(), ErrorKind::PermissionDenied);
        prop_assert!(error.to_string().ends_with(&message));
    }

    #[test]
    fn test_identity_store_error_fmt_property_never_shows_secret_bytes(
        secret in wrong_length_strategy(IDENTITY_SECRET_LENGTH),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let plain_path = directory.path().join(PLAIN_IDENTITY_FILE_NAME);
        plant(&plain_path, &secret)?;

        let loaded = FileIdentityStore::new(plain_path).load_identity();

        let text = loaded.err().map(|error| error.to_string());
        let expected = IdentityStoreError::DamagedIdentity.to_string();
        prop_assert_eq!(text, Some(expected));
    }

    #[test]
    fn test_open_identity_store_property_a_file_choice_uses_the_key_file(
        call_count in 1..MOST_IDENTITY_CALLS,
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let node =
            open_node(&directory, IdentityStoreChoice::File).map_err(fail)?;

        let created = node.find_or_create_identity().map_err(fail)?;
        for _ in 1..call_count {
            let again = node.find_or_create_identity().map_err(fail)?;
            prop_assert_eq!(again.device_id(), created.device_id());
        }

        let identity_path = node.device_files().identity_path();
        let stored = FileIdentityStore::new(identity_path).load_identity();
        let stored = stored.map_err(fail)?.ok_or_else(|| fail("none"))?;
        prop_assert_eq!(stored.device_id(), created.device_id());
        let sealed_path = node.device_files().sealed_identity_path();
        prop_assert!(!sealed_path.exists());
    }

    #[test]
    fn test_open_identity_store_property_a_sealed_choice_seals_with_the_key(
        key in any::<StoreKey>(),
        is_uppercase in any::<bool>(),
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let node =
            open_node(&directory, sealed_choice(&key)).map_err(fail)?;
        let created = node.find_or_create_identity().map_err(fail)?;
        drop(node);

        let mut key_text = hex::encode(key);
        if is_uppercase {
            key_text = key_text.to_uppercase();
        }
        let choice = IdentityStoreChoice::EncryptedFile { key: key_text };
        let reopened = open_node(&directory, choice).map_err(fail)?;
        let found = reopened.find_identity().map_err(fail)?;

        let found = found.ok_or_else(|| fail("the identity is gone"))?;
        prop_assert_eq!(found.device_id(), created.device_id());
        let sealed = open_sealed_store(&directory, &key)?.load_identity();
        let sealed = sealed.map_err(fail)?.ok_or_else(|| fail("none"))?;
        prop_assert_eq!(sealed.device_id(), created.device_id());
        let plain_path = reopened.device_files().identity_path();
        prop_assert!(!plain_path.exists());
    }

    #[test]
    fn test_open_identity_store_property_a_bad_key_stops_the_node(
        key_text in INVALID_KEY_PATTERN,
    ) {
        let directory = TempDir::new().map_err(fail)?;
        let choice = IdentityStoreChoice::EncryptedFile {
            key: key_text.clone(),
        };

        let opened = open_node(&directory, choice);

        let refusal = opened.err().unwrap_or_default();
        let expected = IdentityStoreError::InvalidStoreKey.to_string();
        prop_assert!(refusal.contains(&expected), "{}: {}", key_text, refusal);
    }
}
