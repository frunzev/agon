use orchestration_core::identifiers::DeviceId;
use orchestration_core::local_folders::{
    LocalFolder, parse_local_address, render_local_address,
};
use orchestration_core::repository_address::parse_repository_address;
use proptest::prelude::*;
use serde::Deserialize;

const SHARED_FOLDER_CASES: &str =
    include_str!("../fixtures/local_folder_address_cases.json");
const SURROUNDING_WHITE_SPACE: &str = "[ \t\r\n\u{a0}\u{3000}]{0,3}";

#[derive(Debug, Deserialize)]
struct SharedFolderTable {
    addresses: Vec<SharedAddressCase>,
    renderings: Vec<SharedRenderingCase>,
}

#[derive(Debug, Deserialize)]
struct SharedAddressCase {
    address: String,
    device_id: Option<String>,
    path: Option<String>,
    canonical: Option<String>,
}

#[derive(Debug, Deserialize)]
struct SharedRenderingCase {
    device_id: String,
    path: String,
    address: Option<String>,
}

fn read_shared_table() -> Result<SharedFolderTable, serde_json::Error> {
    serde_json::from_str(SHARED_FOLDER_CASES)
}

fn parse_parts(address: &str) -> (Option<String>, Option<String>) {
    match parse_local_address(address) {
        Ok(folder) => (Some(folder.device_id.0), Some(folder.path)),
        Err(_) => (None, None),
    }
}

#[test]
fn test_parse_local_address_property_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_table()?.addresses {
        let parsed = parse_parts(&case.address);

        let expected = (case.device_id, case.path);
        assert_eq!(parsed, expected, "{:?}", case.address);
    }
    Ok(())
}

#[test]
fn test_parse_repository_address_property_agrees_on_local_addresses()
-> Result<(), serde_json::Error> {
    for case in read_shared_table()?.addresses {
        let canonical = parse_repository_address(&case.address).ok();

        assert_eq!(canonical, case.canonical, "{:?}", case.address);
    }
    Ok(())
}

#[test]
fn test_render_local_address_property_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_table()?.renderings {
        let folder = LocalFolder {
            device_id: DeviceId(case.device_id.clone()),
            path: case.path.clone(),
        };

        let rendered = render_local_address(&folder).ok();

        assert_eq!(rendered, case.address, "{case:?}");
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_parse_repository_address_property_local_rows_ignore_padding(
        case_position in any::<prop::sample::Index>(),
        leading_space in SURROUNDING_WHITE_SPACE,
        trailing_space in SURROUNDING_WHITE_SPACE,
    ) {
        let table = read_shared_table()?;
        let cases = &table.addresses;
        let case = &cases[case_position.index(cases.len())];
        let address = &case.address;
        let padded = format!("{leading_space}{address}{trailing_space}");

        let canonical = parse_repository_address(&padded).ok();

        prop_assert_eq!(canonical, case.canonical.clone());
    }
}
