use std::fs;

use orchestration_node::identity_store::{FileIdentityStore, IdentityStore};
use proptest::prelude::*;

use crate::store_contract::{
    fill_every_secret, full_snapshot_strategy, read_snapshot,
};
use crate::store_desk::{
    AGENT_CREDENTIAL_FILE_NAME, STORE_CASE_COUNT, SecretKind,
    create_case_folder, credential_strategy, list_file_names, open_file_desk,
};
use crate::support::test_device::fail;

const FOLDER_NAME_PATTERN: &str = "[a-z][a-z0-9 ._-]{0,11}";
const IDENTITY_NAME_PATTERN: &str = "[a-z][a-z0-9_]{0,11}\\.(key|secret|id)";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

    #[test]
    fn test_file_identity_store_save_agent_credential_property_round_trip(
        credential in credential_strategy(),
    ) {
        let desk = open_file_desk()?;

        desk.store.save_agent_credential(&credential).map_err(fail)?;

        let loaded = desk.store.load_agent_credential().map_err(fail)?;
        prop_assert_eq!(loaded.map(|found| found.to_vec()), Some(credential));
    }

    #[test]
    fn test_file_identity_store_save_agent_credential_property_last_wins(
        first_credential in credential_strategy(),
        second_credential in credential_strategy(),
    ) {
        let desk = open_file_desk()?;

        desk.store.save_agent_credential(&first_credential).map_err(fail)?;
        desk.store.save_agent_credential(&second_credential).map_err(fail)?;

        let stored = fs::read(desk.path_of(SecretKind::AgentCredential))
            .map_err(fail)?;
        prop_assert_eq!(stored, second_credential);
    }

    #[test]
    fn test_file_identity_store_save_agent_credential_property_keeps_others(
        secrets in full_snapshot_strategy(),
        credential in credential_strategy(),
    ) {
        let desk = open_file_desk()?;
        fill_every_secret(&desk.store, &secrets)?;

        desk.store.save_agent_credential(&credential).map_err(fail)?;

        let expected = secrets
            .with_secret(SecretKind::AgentCredential, Some(credential));
        prop_assert_eq!(read_snapshot(&desk.store)?, expected);
    }

    #[test]
    fn test_file_identity_store_load_agent_credential_property_verbatim(
        planted in credential_strategy(),
    ) {
        let desk = open_file_desk()?;
        desk.plant(SecretKind::AgentCredential, &planted)?;

        let loaded = desk.store.load_agent_credential().map_err(fail)?;

        prop_assert_eq!(loaded.map(|found| found.to_vec()), Some(planted));
    }

    #[test]
    fn test_file_identity_store_load_agent_credential_property_repeatable(
        planted in credential_strategy(),
        load_count in 2_usize..5,
    ) {
        let desk = open_file_desk()?;
        desk.plant(SecretKind::AgentCredential, &planted)?;

        for _ in 0..load_count {
            let loaded = desk.store.load_agent_credential().map_err(fail)?;
            prop_assert_eq!(
                loaded.map(|found| found.to_vec()),
                Some(planted.clone()),
            );
        }
    }

    #[test]
    fn test_file_identity_store_load_agent_credential_property_absent_none(
        secrets in full_snapshot_strategy(),
    ) {
        let desk = open_file_desk()?;
        fill_every_secret(&desk.store, &secrets)?;
        fs::remove_file(desk.path_of(SecretKind::AgentCredential))
            .map_err(fail)?;

        let loaded = desk.store.load_agent_credential().map_err(fail)?;

        prop_assert!(loaded.is_none());
    }

    #[test]
    fn test_find_agent_credential_path_property_named_agent_credential_key(
        identity_name in IDENTITY_NAME_PATTERN,
        credential in credential_strategy(),
    ) {
        let folder = create_case_folder()?;
        let store = FileIdentityStore::new(folder.path().join(identity_name));

        store.save_agent_credential(&credential).map_err(fail)?;

        let names = list_file_names(folder.path())?;
        prop_assert_eq!(names, vec![AGENT_CREDENTIAL_FILE_NAME]);
    }

    #[test]
    fn test_find_agent_credential_path_property_follows_identity_folder(
        folder_name in FOLDER_NAME_PATTERN,
        credential in credential_strategy(),
    ) {
        let folder = create_case_folder()?;
        let nested_folder = folder.path().join(&folder_name);
        fs::create_dir(&nested_folder).map_err(fail)?;
        let store = FileIdentityStore::new(
            nested_folder.join(SecretKind::Identity.file_name()),
        );

        store.save_agent_credential(&credential).map_err(fail)?;

        let stored = fs::read(nested_folder.join(AGENT_CREDENTIAL_FILE_NAME))
            .map_err(fail)?;
        prop_assert_eq!(stored, credential);
        prop_assert_eq!(list_file_names(folder.path())?, vec![folder_name]);
    }

    #[test]
    fn test_find_agent_credential_path_property_identity_name_is_irrelevant(
        first_identity_name in IDENTITY_NAME_PATTERN,
        second_identity_name in IDENTITY_NAME_PATTERN,
        credential in credential_strategy(),
    ) {
        let folder = create_case_folder()?;
        let first_store =
            FileIdentityStore::new(folder.path().join(first_identity_name));
        let second_store =
            FileIdentityStore::new(folder.path().join(second_identity_name));

        first_store.save_agent_credential(&credential).map_err(fail)?;

        let loaded = second_store.load_agent_credential().map_err(fail)?;
        prop_assert_eq!(loaded.map(|found| found.to_vec()), Some(credential));
    }
}
