use orchestration_node::server_address::ServerAddress;
use proptest::collection::vec;
use proptest::prelude::*;
use tempfile::TempDir;

use crate::access_node::{
    ACCESS_CASES, has_no_app_server, open_node, read_app_server_address,
    remember_address,
};
use crate::support::address_strategies::server_address_strategy;
use crate::support::test_device::fail;

const MOST_ADDRESSES: usize = 5;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ACCESS_CASES))]

    #[test]
    fn test_app_server_property_a_fresh_node_has_none(_round in 0_u8..4) {
        let data_directory = TempDir::new().map_err(fail)?;

        let node = open_node(&data_directory).map_err(fail)?;

        prop_assert!(has_no_app_server(&node));
    }

    #[test]
    fn test_app_server_property_names_the_remembered_address(
        address in server_address_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        remember_address(&node, &address)?;

        let kept = read_app_server_address(&node).map_err(fail)?;
        prop_assert_eq!(kept, address);
    }

    #[test]
    fn test_app_server_property_forgetting_the_device_clears_it(
        address in server_address_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        remember_address(&node, &address)?;

        node.forget_device_records().map_err(fail)?;

        prop_assert!(has_no_app_server(&node));
        let reopened = open_node(&data_directory).map_err(fail)?;
        prop_assert!(has_no_app_server(&reopened));
    }

    #[test]
    fn test_connect_to_server_property_keeps_the_given_address(
        address in server_address_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        let server = node.connect_to_server(&address).map_err(fail)?;

        prop_assert_eq!(server.address(), &address);
    }

    #[test]
    fn test_connect_to_server_property_remembers_nothing(
        address in server_address_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        let _server = node.connect_to_server(&address).map_err(fail)?;

        prop_assert!(has_no_app_server(&node));
        let record = node.device_files().load_app_server().map_err(fail)?;
        prop_assert_eq!(record, None);
    }

    #[test]
    fn test_connect_to_server_property_leaves_the_remembered_server(
        remembered in server_address_strategy(),
        other in server_address_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        remember_address(&node, &remembered)?;

        let server = node.connect_to_server(&other).map_err(fail)?;

        prop_assert_eq!(server.address(), &other);
        let kept = read_app_server_address(&node).map_err(fail)?;
        prop_assert_eq!(kept, remembered);
    }

    #[test]
    fn test_remember_app_server_property_survives_reopening(
        address in server_address_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        remember_address(&node, &address)?;
        drop(node);

        let reopened = open_node(&data_directory).map_err(fail)?;

        let kept = read_app_server_address(&reopened).map_err(fail)?;
        prop_assert_eq!(kept, address);
    }

    #[test]
    fn test_remember_app_server_property_the_last_one_wins(
        addresses in vec(server_address_strategy(), 1..MOST_ADDRESSES),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        for address in &addresses {
            remember_address(&node, address)?;
        }

        let kept = read_app_server_address(&node).map_err(fail)?;
        prop_assert_eq!(Some(&kept), addresses.last());
    }

    #[test]
    fn test_remember_app_server_property_the_record_parses_back(
        address in server_address_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        remember_address(&node, &address)?;

        let record = node.device_files().load_app_server().map_err(fail)?;
        let record = record.ok_or_else(|| fail("no record was saved"))?;
        let parsed =
            ServerAddress::parse(&record.server_address).map_err(fail)?;
        prop_assert_eq!(parsed, address);
    }
}
