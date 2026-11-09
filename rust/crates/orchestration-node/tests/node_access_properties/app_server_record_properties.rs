use std::fs;
use std::thread;

use orchestration_node::node_error::NodeError;
use orchestration_node::server_address::ServerAddress;
use proptest::collection::vec;
use proptest::prelude::*;
use tempfile::TempDir;

use crate::access_node::{
    ACCESS_CASES, has_no_app_server, open_node, read_app_server_address,
    remember_address, save_record,
};
use crate::support::address_strategies::server_address_strategy;
use crate::support::group_strategies::group_strategy;
use crate::support::test_device::fail;

const MOST_ADDRESSES: usize = 5;
const READS_PER_WRITE: usize = 4;
const RECORD_FILE_NAME: &str = "app-server.json";

fn damaged_address_strategy() -> impl Strategy<Value = String> {
    "[\\PC]{0,30}".prop_filter("the text is no server address", |text| {
        ServerAddress::parse(text).is_err()
    })
}

fn read_while_remembering(
    addresses: &[ServerAddress],
) -> Result<Vec<Result<ServerAddress, NodeError>>, TestCaseError> {
    let data_directory = TempDir::new().map_err(fail)?;
    let node = open_node(&data_directory).map_err(fail)?;
    let read_count = addresses.len() * READS_PER_WRITE;
    thread::scope(|scope| {
        let reading = scope.spawn(|| {
            let mut reads = Vec::new();
            for _ in 0..read_count {
                reads.push(read_app_server_address(&node));
            }
            reads
        });
        for address in addresses {
            remember_address(&node, address)?;
        }
        reading
            .join()
            .map_err(|_| TestCaseError::fail("the reader stopped"))
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ACCESS_CASES))]

    #[test]
    fn test_remember_server_group_property_a_repeat_changes_nothing(
        group in group_strategy(),
        address in server_address_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        remember_address(&node, &address)?;
        node.remember_server_group(&group).map_err(fail)?;

        let repeated = node.remember_server_group(&group);

        prop_assert!(repeated.is_ok(), "{:?}", repeated);
        let stored = node.device_files().load_server_group().map_err(fail)?;
        prop_assert_eq!(stored, Some(group));
        let kept = read_app_server_address(&node).map_err(fail)?;
        prop_assert_eq!(kept, address);
    }

    #[test]
    fn test_remember_server_group_property_keeps_the_primary_address(
        groups in vec(group_strategy(), 1..MOST_ADDRESSES),
        address in server_address_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        remember_address(&node, &address)?;

        for group in &groups {
            node.remember_server_group(group).map_err(fail)?;
            let kept = read_app_server_address(&node).map_err(fail)?;
            prop_assert_eq!(&kept, &address);
        }
    }

    #[test]
    fn test_reconnect_app_server_property_reads_the_record_on_disk(
        address in server_address_strategy(),
        group in group_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        save_record(&node, &address.to_string())?;

        node.remember_server_group(&group).map_err(fail)?;

        let connected = read_app_server_address(&node).map_err(fail)?;
        prop_assert_eq!(connected, address);
    }

    #[test]
    fn test_reconnect_app_server_property_no_record_stays_empty(
        group in group_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        node.remember_server_group(&group).map_err(fail)?;

        prop_assert!(has_no_app_server(&node));
    }

    #[test]
    fn test_reconnect_app_server_property_a_removed_record_clears_it(
        address in server_address_strategy(),
        group in group_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        remember_address(&node, &address)?;
        let record_path = data_directory.path().join(RECORD_FILE_NAME);
        fs::remove_file(record_path).map_err(fail)?;

        node.remember_server_group(&group).map_err(fail)?;

        prop_assert!(has_no_app_server(&node));
    }

    #[test]
    fn test_write_app_server_property_readers_see_only_remembered_ones(
        addresses in vec(server_address_strategy(), 1..MOST_ADDRESSES),
    ) {
        let reads = read_while_remembering(&addresses)?;

        for read in reads {
            match read {
                Ok(address) => prop_assert!(addresses.contains(&address)),
                Err(NodeError::NoAppServer) => {}
                Err(problem) => prop_assert!(false, "{problem}"),
            }
        }
    }

    #[test]
    fn test_write_app_server_property_forgetting_clears_any_history(
        addresses in vec(server_address_strategy(), 1..MOST_ADDRESSES),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        for address in &addresses {
            remember_address(&node, address)?;
        }

        node.forget_device_records().map_err(fail)?;

        prop_assert!(has_no_app_server(&node));
    }

    #[test]
    fn test_write_app_server_property_remembering_after_forgetting_works(
        first in server_address_strategy(),
        second in server_address_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        remember_address(&node, &first)?;
        node.forget_device_records().map_err(fail)?;

        remember_address(&node, &second)?;

        let kept = read_app_server_address(&node).map_err(fail)?;
        prop_assert_eq!(kept, second);
    }

    #[test]
    fn test_connect_recorded_server_property_opens_the_recorded_address(
        address in server_address_strategy(),
        group in proptest::option::of(group_strategy()),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let first_node = open_node(&data_directory).map_err(fail)?;
        save_record(&first_node, &address.to_string())?;
        if let Some(group) = &group {
            first_node.device_files().save_server_group(group).map_err(fail)?;
        }
        drop(first_node);

        let node = open_node(&data_directory).map_err(fail)?;

        let connected = read_app_server_address(&node).map_err(fail)?;
        prop_assert_eq!(connected, address);
    }

    #[test]
    fn test_connect_recorded_server_property_a_group_alone_opens_none(
        group in group_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let first_node = open_node(&data_directory).map_err(fail)?;
        first_node.device_files().save_server_group(&group).map_err(fail)?;
        drop(first_node);

        let node = open_node(&data_directory).map_err(fail)?;

        prop_assert!(has_no_app_server(&node));
    }

    #[test]
    fn test_connect_recorded_server_property_a_damaged_record_opens_none(
        damaged in damaged_address_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let first_node = open_node(&data_directory).map_err(fail)?;
        save_record(&first_node, &damaged)?;
        drop(first_node);

        let opened = open_node(&data_directory);

        let node = opened.map_err(fail)?;
        prop_assert!(has_no_app_server(&node));
    }
}
