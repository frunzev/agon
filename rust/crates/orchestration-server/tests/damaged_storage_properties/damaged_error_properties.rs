use axum::http::StatusCode;
use axum::response::IntoResponse;
use orchestration_server::ServerError;
use proptest::prelude::*;

const ERROR_CASES: u32 = 32;
const DETAIL_PATTERN: &str = "\\PC{0,40}";
const DAMAGED_TEXT: &str = "damaged";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ERROR_CASES))]

    #[test]
    fn test_server_error_status_property_damaged_data_is_internal(
        detail in DETAIL_PATTERN,
    ) {
        let response = ServerError::DamagedSavedData(detail).into_response();

        prop_assert_eq!(response.status(), StatusCode::INTERNAL_SERVER_ERROR);
    }

    #[test]
    fn test_server_error_status_property_damage_matches_storage_status(
        detail in DETAIL_PATTERN,
    ) {
        let damaged = ServerError::DamagedSavedData(detail.clone());
        let storage = ServerError::Storage(detail);

        let damaged_status = damaged.into_response().status();
        let storage_status = storage.into_response().status();

        prop_assert_eq!(damaged_status, storage_status);
    }

    #[test]
    fn test_server_error_status_property_damage_names_itself_and_detail(
        detail in DETAIL_PATTERN,
    ) {
        let shown = ServerError::DamagedSavedData(detail.clone()).to_string();

        prop_assert!(shown.contains(DAMAGED_TEXT), "{shown}");
        prop_assert!(shown.ends_with(&detail), "{shown}");
    }
}
