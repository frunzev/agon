use std::collections::BTreeSet;
use std::fs;

use orchestration_node::commands::dispatch_command;
use orchestration_node::device_files::AppServerRecord;
use orchestration_node::node::Node;
use orchestration_node::node_error::NodeError;
use proptest::prelude::*;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::access_node::open_node;
use crate::damaged_server_records::{
    PROBLEM_FIELD, SERVER_RECORD_NAME, damaged_server_record_strategy,
};
use crate::support::address_strategies::server_address_strategy;
use crate::support::group_strategies::group_strategy;
use crate::support::runner_access::test_runtime;
use crate::support::test_device::{fail, read_success};

const RECORD_CASES: u32 = 16;
const MOST_CALLS: usize = 5;

fn read_bare_status(node: &Node) -> Result<Value, TestCaseError> {
    let runtime = test_runtime().map_err(fail)?;
    let command = json!({ "command": "status" }).to_string();
    let reply_text = runtime.block_on(dispatch_command(node, &command));
    let reply: Value = serde_json::from_str(&reply_text).map_err(fail)?;
    read_success(&reply).map_err(fail)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RECORD_CASES))]

    #[test]
    fn test_open_session_property_a_device_without_account_is_refused(
        has_identity in any::<bool>(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        if has_identity {
            node.find_or_create_identity().map_err(fail)?;
        }

        let opened = node.open_session();

        prop_assert!(matches!(opened, Err(NodeError::NoAccount)));
    }

    #[test]
    fn test_find_or_create_peer_secret_property_repeats_give_one_secret(
        call_count in 1..MOST_CALLS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        let first = node.find_or_create_peer_secret().map_err(fail)?;
        for _ in 1..call_count {
            let repeated = node.find_or_create_peer_secret().map_err(fail)?;
            prop_assert_eq!(*repeated, *first);
        }
        let reopened = open_node(&data_directory).map_err(fail)?;
        let kept = reopened.find_or_create_peer_secret().map_err(fail)?;
        prop_assert_eq!(*kept, *first);
    }

    #[test]
    fn test_find_or_create_peer_secret_property_folders_never_share(
        folder_count in 2..MOST_CALLS,
    ) {
        let mut secrets = BTreeSet::new();
        for _ in 0..folder_count {
            let data_directory = TempDir::new().map_err(fail)?;
            let node = open_node(&data_directory).map_err(fail)?;
            let secret = node.find_or_create_peer_secret().map_err(fail)?;
            secrets.insert(*secret);
        }

        prop_assert_eq!(secrets.len(), folder_count);
    }

    #[test]
    fn test_find_or_create_peer_secret_property_forgetting_makes_a_new_one(
        forget_count in 1..MOST_CALLS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        let first_secret = node.find_or_create_peer_secret().map_err(fail)?;
        let mut secrets = vec![*first_secret];
        for _ in 0..forget_count {
            node.forget_device_records().map_err(fail)?;
            secrets.push(*node.find_or_create_peer_secret().map_err(fail)?);
        }

        let unique_secrets: BTreeSet<_> = secrets.iter().copied().collect();
        prop_assert_eq!(unique_secrets.len(), secrets.len());
    }

    #[test]
    fn test_forget_device_records_property_removes_records_keeps_identity(
        address in server_address_strategy(),
        group in group_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        let identity = node.find_or_create_identity().map_err(fail)?;
        let record = AppServerRecord {
            server_address: address.to_string(),
        };
        node.device_files().save_app_server(&record).map_err(fail)?;
        node.device_files().save_server_group(&group).map_err(fail)?;

        node.forget_device_records().map_err(fail)?;

        let files = node.device_files();
        prop_assert_eq!(files.load_app_server().map_err(fail)?, None);
        prop_assert_eq!(files.load_server_group().map_err(fail)?, None);
        prop_assert_eq!(files.load_account().map_err(fail)?, None);
        prop_assert_eq!(files.load_pending_join().map_err(fail)?, None);
        let kept = node.find_identity().map_err(fail)?;
        let kept_id = kept.map(|found| found.device_id());
        prop_assert_eq!(kept_id, Some(identity.device_id()));
    }

    #[test]
    fn test_forget_device_records_property_clears_a_damaged_record_problem(
        damaged_bytes in damaged_server_record_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let record_path = data_directory.path().join(SERVER_RECORD_NAME);
        fs::write(&record_path, &damaged_bytes).map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        let damaged_status = read_bare_status(&node)?;

        node.forget_device_records().map_err(fail)?;

        let status = read_bare_status(&node)?;
        prop_assert!(damaged_status[PROBLEM_FIELD].is_string());
        prop_assert_eq!(&status[PROBLEM_FIELD], &Value::Null);
        prop_assert_eq!(&status["server_address"], &Value::Null);
        prop_assert!(!record_path.exists());
    }

    #[test]
    fn test_forget_device_records_property_repeating_changes_nothing(
        repeat_count in 1..MOST_CALLS,
        address in server_address_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        let server = node.connect_to_server(&address).map_err(fail)?;
        node.remember_app_server(&server).map_err(fail)?;

        for _ in 0..repeat_count {
            node.forget_device_records().map_err(fail)?;
            let app_server = node.app_server();
            prop_assert!(matches!(app_server, Err(NodeError::NoAppServer)));
            let files = node.device_files();
            prop_assert_eq!(files.load_app_server().map_err(fail)?, None);
        }
    }

    #[test]
    fn test_device_files_property_saves_inside_the_configured_folder(
        address in server_address_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        let record = AppServerRecord {
            server_address: address.to_string(),
        };

        node.device_files().save_app_server(&record).map_err(fail)?;

        let record_path = data_directory.path().join(SERVER_RECORD_NAME);
        prop_assert!(record_path.is_file());
        let loaded = node.device_files().load_app_server().map_err(fail)?;
        prop_assert_eq!(loaded, Some(record));
    }

    #[test]
    fn test_device_files_property_reopening_reads_the_same_files(
        address in server_address_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        let record = AppServerRecord {
            server_address: address.to_string(),
        };
        node.device_files().save_app_server(&record).map_err(fail)?;

        let reopened = open_node(&data_directory).map_err(fail)?;

        let loaded = reopened.device_files().load_app_server().map_err(fail)?;
        prop_assert_eq!(loaded, Some(record));
    }

    #[test]
    fn test_device_files_property_separate_folders_share_nothing(
        address in server_address_strategy(),
    ) {
        let first_directory = TempDir::new().map_err(fail)?;
        let second_directory = TempDir::new().map_err(fail)?;
        let first = open_node(&first_directory).map_err(fail)?;
        let second = open_node(&second_directory).map_err(fail)?;
        let record = AppServerRecord {
            server_address: address.to_string(),
        };

        first.device_files().save_app_server(&record).map_err(fail)?;

        let loaded = second.device_files().load_app_server().map_err(fail)?;
        prop_assert_eq!(loaded, None);
    }
}
