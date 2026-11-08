use std::fs;

use orchestration_security::identity::IDENTITY_SECRET_LENGTH;
use orchestration_server::ServerError;
use proptest::prelude::*;

use crate::storage_desk::{damaged_bytes_strategy, fail, open_storage_desk};

const IDENTITY_FILE_NAME: &str = "server-identity.key";
const IDENTITY_CASES: u32 = 24;
const MOST_LOADS: usize = 4;

fn is_partial_key(key_bytes: &[u8]) -> bool {
    key_bytes.len() != IDENTITY_SECRET_LENGTH
}

fn damaged_key_strategy() -> impl Strategy<Value = Vec<u8>> {
    damaged_bytes_strategy()
        .prop_filter("not a whole key", |key_bytes| is_partial_key(key_bytes))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(IDENTITY_CASES))]

    #[test]
    fn test_load_or_create_identity_property_damage_is_named_and_kept(
        damaged_key in damaged_key_strategy(),
    ) {
        let desk = open_storage_desk()?;
        desk.write_file(IDENTITY_FILE_NAME, &damaged_key)?;

        let loaded = desk.storage.load_or_create_identity();
        let key_after =
            fs::read(desk.path_of(IDENTITY_FILE_NAME)).map_err(fail)?;

        let is_damaged =
            matches!(loaded, Err(ServerError::DamagedSavedData(_)));
        prop_assert!(is_damaged, "{:?}", loaded.map(|key| key.device_id()));
        prop_assert_eq!(key_after, damaged_key);
    }

    #[test]
    fn test_load_or_create_identity_property_an_unopenable_key_is_not_damage(
        folder_depth in 0_usize..3,
    ) {
        let desk = open_storage_desk()?;
        desk.put_folder_at(IDENTITY_FILE_NAME, folder_depth)?;

        let loaded = desk.storage.load_or_create_identity();

        let is_storage_problem =
            matches!(loaded, Err(ServerError::Storage(_)));
        let shown = loaded.map(|key| key.device_id());
        prop_assert!(is_storage_problem, "{shown:?}");
    }

    #[test]
    fn test_load_or_create_identity_property_a_created_key_loads_again(
        load_count in 1..=MOST_LOADS,
    ) {
        let desk = open_storage_desk()?;
        let created = desk.storage.load_or_create_identity().map_err(fail)?;

        for _ in 0..load_count {
            let loaded =
                desk.storage.load_or_create_identity().map_err(fail)?;
            prop_assert_eq!(loaded.device_id(), created.device_id());
        }
    }
}
