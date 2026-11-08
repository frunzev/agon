use std::fs::{self, Permissions};
use std::io::ErrorKind;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;

use orchestration_node::identity_store::{IdentityStore, IdentityStoreError};
use orchestration_security::identity::DeviceIdentity;
use proptest::prelude::*;

use crate::store_desk::{
    FileDesk, IDENTITY_FILE_NAME, STORE_CASE_COUNT, identity_strategy,
    list_file_names, open_file_desk,
};
use crate::support::test_device::fail;

const UNLISTABLE_FOLDER_MODE: u32 = 0o300;
const OWNER_FOLDER_MODE: u32 = 0o700;

type SaveOutcome = Result<(), IdentityStoreError>;

fn set_folder_mode(folder: &Path, mode: u32) -> Result<(), TestCaseError> {
    fs::set_permissions(folder, Permissions::from_mode(mode)).map_err(fail)
}

fn save_in_unlistable_folder(
    desk: &FileDesk,
    identity: &DeviceIdentity,
) -> Result<SaveOutcome, TestCaseError> {
    let folder = desk.folder.path();
    set_folder_mode(folder, UNLISTABLE_FOLDER_MODE)?;
    let saved = desk.store.save_identity(identity);
    set_folder_mode(folder, OWNER_FOLDER_MODE)?;
    Ok(saved)
}

fn read_stored_secret(
    desk: &FileDesk,
) -> Result<Option<Vec<u8>>, TestCaseError> {
    let loaded = desk.store.load_identity().map_err(fail)?;
    Ok(loaded.map(|identity| identity.secret_bytes().to_vec()))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

    #[test]
    fn test_sync_parent_folder_property_an_unopenable_folder_fails_the_save(
        identity in identity_strategy(),
    ) {
        let desk = open_file_desk()?;

        let saved = save_in_unlistable_folder(&desk, &identity)?;

        let Err(IdentityStoreError::File(error)) = saved else {
            return Err(TestCaseError::fail(format!("{saved:?}")));
        };
        prop_assert_eq!(error.kind(), ErrorKind::PermissionDenied);
    }

    #[test]
    fn test_sync_parent_folder_property_a_failed_sync_leaves_no_stray_file(
        old_identity in identity_strategy(),
        new_identity in identity_strategy(),
    ) {
        let desk = open_file_desk()?;
        desk.store.save_identity(&old_identity).map_err(fail)?;

        let saved = save_in_unlistable_folder(&desk, &new_identity)?;

        prop_assert!(saved.is_err(), "{:?}", saved);
        let names = list_file_names(desk.folder.path())?;
        prop_assert_eq!(names, vec![IDENTITY_FILE_NAME.to_owned()]);
    }

    #[test]
    fn test_sync_parent_folder_property_a_failed_sync_keeps_a_whole_secret(
        old_identity in identity_strategy(),
        new_identity in identity_strategy(),
    ) {
        let desk = open_file_desk()?;
        desk.store.save_identity(&old_identity).map_err(fail)?;

        let saved = save_in_unlistable_folder(&desk, &new_identity)?;

        prop_assert!(saved.is_err(), "{:?}", saved);
        let stored_secret = read_stored_secret(&desk)?;
        let whole_secrets = [
            Some(old_identity.secret_bytes().to_vec()),
            Some(new_identity.secret_bytes().to_vec()),
        ];
        prop_assert!(whole_secrets.contains(&stored_secret));
    }
}
