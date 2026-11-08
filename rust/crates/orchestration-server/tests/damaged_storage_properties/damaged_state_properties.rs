use orchestration_server::{ServerError, StoredState};
use proptest::prelude::*;

use crate::storage_desk::{damaged_bytes_strategy, fail, open_storage_desk};

const STATE_FILE_NAME: &str = "state.json";
const STATE_CASES: u32 = 24;
const LARGEST_COUNT: u64 = 1_000_000;

fn fails_to_decode(state_bytes: &[u8]) -> bool {
    let decoded: Result<StoredState, _> = serde_json::from_slice(state_bytes);
    decoded.is_err()
}

fn damaged_state_strategy() -> impl Strategy<Value = Vec<u8>> {
    damaged_bytes_strategy().prop_filter("not a stored state", |state_bytes| {
        fails_to_decode(state_bytes)
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STATE_CASES))]

    #[test]
    fn test_load_state_property_damaged_bytes_are_named_damaged(
        damaged_state in damaged_state_strategy(),
    ) {
        let desk = open_storage_desk()?;
        desk.write_file(STATE_FILE_NAME, &damaged_state)?;

        let loaded = desk.storage.load_state();

        let is_damaged =
            matches!(loaded, Err(ServerError::DamagedSavedData(_)));
        prop_assert!(is_damaged, "{loaded:?}");
    }

    #[test]
    fn test_load_state_property_an_unopenable_file_is_not_damage(
        folder_depth in 0_usize..3,
    ) {
        let desk = open_storage_desk()?;
        desk.put_folder_at(STATE_FILE_NAME, folder_depth)?;

        let loaded = desk.storage.load_state();

        let is_storage_problem =
            matches!(loaded, Err(ServerError::Storage(_)));
        prop_assert!(is_storage_problem, "{loaded:?}");
    }

    #[test]
    fn test_load_state_property_a_saved_state_loads_back(
        revision in 0..LARGEST_COUNT,
        latest_sequence in 0..LARGEST_COUNT,
    ) {
        let desk = open_storage_desk()?;
        let saved_state = StoredState {
            revision,
            latest_sequence,
            ..StoredState::default()
        };
        desk.storage.save_state(&saved_state).map_err(fail)?;

        let loaded = desk.storage.load_state();

        prop_assert_eq!(loaded.ok(), Some(saved_state));
    }
}
