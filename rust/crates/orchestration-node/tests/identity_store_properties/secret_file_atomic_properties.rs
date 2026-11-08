use std::fs;
use std::path::Path;
use std::thread;

use orchestration_node::identity_store::{IdentityStore, IdentityStoreError};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::store_contract::{
    apply_step, kind_and_secret_strategy, kind_strategy, read_secret_of,
    read_snapshot, save_secret_of, secret_strategy_of, step_strategy,
};
use crate::store_desk::{
    STORE_CASE_COUNT, SecretKind, UNFINISHED_FILE_SUFFIX, identity_strategy,
    list_file_names, open_file_desk,
};
use crate::support::test_device::fail;

const LONGEST_STEP_RUN: usize = 12;
const CONCURRENT_CASE_COUNT: u32 = 6;
const CONCURRENT_ROUNDS: usize = 40;
const FOLDER_ENTRY_NAME: &str = "kept-entry";

fn find_unfinished_names(folder: &Path) -> Result<Vec<String>, TestCaseError> {
    let mut unfinished_names = Vec::new();
    for name in list_file_names(folder)? {
        if name.ends_with(UNFINISHED_FILE_SUFFIX) {
            unfinished_names.push(name);
        }
    }
    Ok(unfinished_names)
}

fn kind_and_two_secrets_strategy()
-> impl Strategy<Value = (SecretKind, Vec<u8>, Vec<u8>)> {
    kind_strategy().prop_flat_map(|kind| {
        (
            Just(kind),
            secret_strategy_of(kind),
            secret_strategy_of(kind),
        )
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

    #[test]
    fn test_write_secret_file_property_leaves_no_unfinished_files(
        steps in vec(step_strategy(), 1..LONGEST_STEP_RUN),
    ) {
        let desk = open_file_desk()?;

        for step in &steps {
            apply_step(&desk.store, step)?;
        }

        prop_assert!(find_unfinished_names(desk.folder.path())?.is_empty());
    }

    #[test]
    fn test_write_secret_file_property_failed_rename_cleans_up(
        (kind, secret) in kind_and_secret_strategy(),
        kept_bytes in vec(any::<u8>(), 0..64),
    ) {
        let desk = open_file_desk()?;
        let folder_in_place = desk.path_of(kind);
        fs::create_dir(&folder_in_place).map_err(fail)?;
        let kept_path = folder_in_place.join(FOLDER_ENTRY_NAME);
        fs::write(&kept_path, &kept_bytes).map_err(fail)?;

        let saved = save_secret_of(&desk.store, kind, &secret);

        prop_assert!(saved.is_err());
        let names = list_file_names(desk.folder.path())?;
        prop_assert_eq!(names, vec![kind.file_name().to_owned()]);
        prop_assert_eq!(fs::read(&kept_path).map_err(fail)?, kept_bytes);
    }
}

#[cfg(unix)]
proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

    #[test]
    fn test_write_secret_file_property_failed_write_keeps_the_old_secret(
        (kind, old_secret, new_secret) in kind_and_two_secrets_strategy(),
    ) {
        use std::os::unix::fs::PermissionsExt;

        const READ_ONLY_FOLDER_MODE: u32 = 0o500;
        const OWNER_FOLDER_MODE: u32 = 0o700;
        let desk = open_file_desk()?;
        save_secret_of(&desk.store, kind, &old_secret)?;
        let folder_path = desk.folder.path();
        let read_only = fs::Permissions::from_mode(READ_ONLY_FOLDER_MODE);
        fs::set_permissions(folder_path, read_only).map_err(fail)?;

        let saved = save_secret_of(&desk.store, kind, &new_secret);
        let names = list_file_names(folder_path);
        let loaded = read_secret_of(&desk.store, kind);

        let writable = fs::Permissions::from_mode(OWNER_FOLDER_MODE);
        fs::set_permissions(folder_path, writable).map_err(fail)?;
        prop_assert!(saved.is_err());
        prop_assert_eq!(names?, vec![kind.file_name().to_owned()]);
        prop_assert_eq!(loaded.map_err(fail)?, Some(old_secret));
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CONCURRENT_CASE_COUNT))]

    #[test]
    fn test_write_secret_file_property_readers_never_see_half_a_secret(
        first_identity in identity_strategy(),
        second_identity in identity_strategy(),
    ) {
        let desk = open_file_desk()?;
        desk.store.save_identity(&first_identity).map_err(fail)?;
        let first_secret = first_identity.secret_bytes().to_vec();
        let second_secret = second_identity.secret_bytes().to_vec();

        let loaded_secrets = thread::scope(|scope| {
            let writer = scope.spawn(|| {
                for round in 0..CONCURRENT_ROUNDS {
                    let identity = if round % 2 == 0 {
                        &second_identity
                    } else {
                        &first_identity
                    };
                    desk.store.save_identity(identity)?;
                }
                Ok::<(), IdentityStoreError>(())
            });
            let mut loaded_secrets = Vec::new();
            for _ in 0..CONCURRENT_ROUNDS {
                let loaded = read_secret_of(&desk.store, SecretKind::Identity);
                let described =
                    loaded.map_err(|problem| problem.to_string());
                loaded_secrets.push(described);
            }
            let written = writer.join();
            (loaded_secrets, written.is_ok_and(|outcome| outcome.is_ok()))
        });

        let (loaded_secrets, is_written) = loaded_secrets;
        prop_assert!(is_written);
        for loaded in loaded_secrets {
            let loaded = loaded.map_err(fail)?;
            let is_whole = loaded.as_ref() == Some(&first_secret)
                || loaded.as_ref() == Some(&second_secret);
            prop_assert!(is_whole, "{:?}", loaded);
        }
    }

    #[test]
    fn test_write_secret_file_property_concurrent_saves_keep_one_whole(
        first_identity in identity_strategy(),
        second_identity in identity_strategy(),
    ) {
        let desk = open_file_desk()?;

        let are_saved = thread::scope(|scope| {
            let first_writer = scope.spawn(|| {
                for _ in 0..CONCURRENT_ROUNDS {
                    desk.store.save_identity(&first_identity)?;
                }
                Ok::<(), IdentityStoreError>(())
            });
            let second_writer = scope.spawn(|| {
                for _ in 0..CONCURRENT_ROUNDS {
                    desk.store.save_identity(&second_identity)?;
                }
                Ok::<(), IdentityStoreError>(())
            });
            let first_saved = first_writer.join();
            let second_saved = second_writer.join();
            first_saved.is_ok_and(|outcome| outcome.is_ok())
                && second_saved.is_ok_and(|outcome| outcome.is_ok())
        });

        prop_assert!(are_saved);
        let stored = read_snapshot(&desk.store)?.identity;
        let first_secret = first_identity.secret_bytes().to_vec();
        let second_secret = second_identity.secret_bytes().to_vec();
        let is_whole = stored.as_ref() == Some(&first_secret)
            || stored.as_ref() == Some(&second_secret);
        prop_assert!(is_whole);
        prop_assert!(find_unfinished_names(desk.folder.path())?.is_empty());
    }
}
