use std::fs;

use orchestration_node::identity_store::{
    FileIdentityStore, IdentityStoreError,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::store_contract::{
    fill_every_secret, forget_secret_of, full_snapshot_strategy,
    kind_strategy, read_secret_of, read_snapshot,
};
use crate::store_desk::{
    STORE_CASE_COUNT, SecretKind, create_case_folder, open_file_desk,
};
use crate::support::test_device::fail;

const HUGE_CREDENTIAL_LENGTH: usize = 1 << 16;
const FOLDER_ENTRY_NAME: &str = "kept-entry";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

    #[test]
    fn test_read_secret_file_property_reads_exact_bytes_of_any_size(
        planted in vec(any::<u8>(), 0..HUGE_CREDENTIAL_LENGTH),
    ) {
        let desk = open_file_desk()?;
        desk.plant(SecretKind::AgentCredential, &planted)?;

        let loaded = read_secret_of(&desk.store, SecretKind::AgentCredential)
            .map_err(fail)?;

        prop_assert_eq!(loaded, Some(planted));
    }

    #[test]
    fn test_read_secret_file_property_folder_in_place_is_a_file_error(
        kind in kind_strategy(),
    ) {
        let desk = open_file_desk()?;
        fs::create_dir(desk.path_of(kind)).map_err(fail)?;

        let loaded = read_secret_of(&desk.store, kind);

        prop_assert!(matches!(loaded, Err(IdentityStoreError::File(_))));
    }

    #[test]
    fn test_remove_secret_file_property_missing_file_is_fine(
        kind in kind_strategy(),
        folder_name in "[a-z]{1,12}",
    ) {
        let folder = create_case_folder()?;
        let missing_folder = folder.path().join(folder_name);
        let store = FileIdentityStore::new(
            missing_folder.join(SecretKind::Identity.file_name()),
        );

        forget_secret_of(&store, kind).map_err(fail)?;

        prop_assert!(!missing_folder.exists());
    }

    #[test]
    fn test_remove_secret_file_property_folder_in_place_is_refused(
        kind in kind_strategy(),
        kept_bytes in vec(any::<u8>(), 0..64),
    ) {
        let desk = open_file_desk()?;
        let folder_in_place = desk.path_of(kind);
        fs::create_dir(&folder_in_place).map_err(fail)?;
        let kept_path = folder_in_place.join(FOLDER_ENTRY_NAME);
        fs::write(&kept_path, &kept_bytes).map_err(fail)?;

        let forgotten = forget_secret_of(&desk.store, kind);

        prop_assert!(matches!(forgotten, Err(IdentityStoreError::File(_))));
        prop_assert_eq!(fs::read(&kept_path).map_err(fail)?, kept_bytes);
    }

    #[test]
    fn test_remove_secret_file_property_keeps_unrelated_files(
        secrets in full_snapshot_strategy(),
        kind in kind_strategy(),
        unrelated_bytes in vec(any::<u8>(), 0..64),
    ) {
        let desk = open_file_desk()?;
        fill_every_secret(&desk.store, &secrets)?;
        let unrelated_path = desk.folder.path().join(FOLDER_ENTRY_NAME);
        fs::write(&unrelated_path, &unrelated_bytes).map_err(fail)?;

        forget_secret_of(&desk.store, kind).map_err(fail)?;

        let still_unrelated = fs::read(&unrelated_path).map_err(fail)?;
        prop_assert_eq!(still_unrelated, unrelated_bytes);
        prop_assert_eq!(
            read_snapshot(&desk.store)?,
            secrets.with_secret(kind, None),
        );
    }
}

#[cfg(unix)]
mod unix_secret_files {
    use std::fs;
    use std::os::unix::fs::{PermissionsExt, symlink};

    use orchestration_node::identity_store::IdentityStoreError;
    use proptest::collection::vec;
    use proptest::prelude::*;

    use crate::store_contract::{
        forget_secret_of, kind_and_secret_strategy, kind_strategy,
        read_secret_of, save_secret_of, secret_strategy_of,
    };
    use crate::store_desk::{
        SECRET_KINDS, STORE_CASE_COUNT, SecretKind, UNFINISHED_FILE_SUFFIX,
        create_case_folder, open_file_desk, read_permission_bits,
    };
    use crate::support::test_device::fail;

    const OWNER_ONLY_MODE: u32 = 0o600;
    const READABLE_BY_ALL_MODE: u32 = 0o644;
    const NO_ACCESS_MODE: u32 = 0o000;
    const OUTSIDE_FILE_NAME: &str = "outside-secret";

    proptest! {
        #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

        #[test]
        fn test_read_secret_file_property_unreadable_file_is_an_error(
            kind in kind_strategy(),
            planted in vec(any::<u8>(), 0..64),
        ) {
            let desk = open_file_desk()?;
            desk.plant(kind, &planted)?;
            let secret_path = desk.path_of(kind);
            let no_access = fs::Permissions::from_mode(NO_ACCESS_MODE);
            fs::set_permissions(&secret_path, no_access).map_err(fail)?;

            let loaded = read_secret_of(&desk.store, kind);

            prop_assert!(matches!(loaded, Err(IdentityStoreError::File(_))));
        }

        #[test]
        fn test_remove_secret_file_property_removes_a_link_not_its_target(
            kind in kind_strategy(),
            outside_bytes in vec(any::<u8>(), 0..64),
        ) {
            let desk = open_file_desk()?;
            let outside_folder = create_case_folder()?;
            let outside_path = outside_folder.path().join(OUTSIDE_FILE_NAME);
            fs::write(&outside_path, &outside_bytes).map_err(fail)?;
            symlink(&outside_path, desk.path_of(kind)).map_err(fail)?;

            forget_secret_of(&desk.store, kind).map_err(fail)?;

            prop_assert!(fs::symlink_metadata(desk.path_of(kind)).is_err());
            let still_outside = fs::read(&outside_path).map_err(fail)?;
            prop_assert_eq!(still_outside, outside_bytes);
        }

        #[test]
        fn test_owner_only_file_options_property_every_secret_is_owner_only(
            identity in secret_strategy_of(SecretKind::Identity),
            peer_secret in secret_strategy_of(SecretKind::PeerSecret),
            credential in secret_strategy_of(SecretKind::AgentCredential),
        ) {
            let desk = open_file_desk()?;
            save_secret_of(&desk.store, SecretKind::Identity, &identity)?;
            save_secret_of(&desk.store, SecretKind::PeerSecret, &peer_secret)?;
            save_secret_of(
                &desk.store,
                SecretKind::AgentCredential,
                &credential,
            )?;

            for kind in SECRET_KINDS {
                let mode = read_permission_bits(&desk.path_of(kind))?;
                prop_assert_eq!(mode, OWNER_ONLY_MODE, "{:?}", kind);
            }
        }

        #[test]
        fn test_owner_only_file_options_property_readable_file_is_tightened(
            (kind, secret) in kind_and_secret_strategy(),
            old_bytes in vec(any::<u8>(), 0..64),
        ) {
            let desk = open_file_desk()?;
            desk.plant(kind, &old_bytes)?;
            let readable = fs::Permissions::from_mode(READABLE_BY_ALL_MODE);
            fs::set_permissions(desk.path_of(kind), readable).map_err(fail)?;

            save_secret_of(&desk.store, kind, &secret)?;

            let mode = read_permission_bits(&desk.path_of(kind))?;
            prop_assert_eq!(mode, OWNER_ONLY_MODE);
        }

        #[test]
        fn test_owner_only_file_options_property_stale_unfinished_not_reused(
            (kind, secret) in kind_and_secret_strategy(),
            stale_bytes in vec(any::<u8>(), 0..64),
        ) {
            let desk = open_file_desk()?;
            let stale_path = desk.path_of(kind).with_extension(
                UNFINISHED_FILE_SUFFIX.trim_start_matches('.'),
            );
            fs::write(&stale_path, &stale_bytes).map_err(fail)?;
            let readable = fs::Permissions::from_mode(READABLE_BY_ALL_MODE);
            fs::set_permissions(&stale_path, readable).map_err(fail)?;

            save_secret_of(&desk.store, kind, &secret)?;

            let mode = read_permission_bits(&desk.path_of(kind))?;
            prop_assert_eq!(mode, OWNER_ONLY_MODE);
            prop_assert_eq!(fs::read(&stale_path).map_err(fail)?, stale_bytes);
            let loaded = read_secret_of(&desk.store, kind).map_err(fail)?;
            prop_assert_eq!(loaded, Some(secret));
        }
    }
}
