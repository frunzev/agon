use std::fs;
use std::net::{Ipv4Addr, TcpListener};
use std::time::{Duration, Instant};

use orchestration_node::node_configuration::{
    DEFAULT_TAKEOVER_SECONDS, IdentityStoreChoice, NodeConfiguration,
    PeerRelayChoice,
};
use orchestration_node::node_runtime::NodeRuntime;
use proptest::prelude::*;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::configuration_samples::INVALID_CONFIGURATION_START;
use crate::hosting_problem_steps::read_status_on;
use crate::runtime_steps::{host_on, start_runtime};
use crate::support::hosting_steps::pick_free_port;
use crate::support::test_device::fail;

const LIFECYCLE_CASES: u32 = 3;
const MOST_RESTARTS: usize = 4;
const DROP_LIMIT: Duration = Duration::from_secs(6);
const STRAY_NAME_PATTERN: &str = "[a-z]{1,10}_[a-z]{1,10}";

fn configure_folder(data_directory: &TempDir, port: u16) -> NodeConfiguration {
    NodeConfiguration {
        data_directory: data_directory.path().to_path_buf(),
        identity_store: IdentityStoreChoice::File,
        runner: None,
        peer_relay: PeerRelayChoice::Disabled,
        app_server_port: port,
        server_takeover_seconds: DEFAULT_TAKEOVER_SECONDS,
    }
}

fn list_folder_names(data_directory: &TempDir) -> Result<Vec<String>, String> {
    let mut names = Vec::new();
    let entries = fs::read_dir(data_directory.path())
        .map_err(|problem| problem.to_string())?;
    for entry in entries {
        let entry = entry.map_err(|problem| problem.to_string())?;
        names.push(entry.file_name().to_string_lossy().into_owned());
    }
    names.sort();
    Ok(names)
}

fn is_port_free(port: u16) -> bool {
    TcpListener::bind((Ipv4Addr::LOCALHOST, port)).is_ok()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LIFECYCLE_CASES))]

    #[test]
    fn test_start_property_a_stray_field_starts_nothing(
        stray_name in STRAY_NAME_PATTERN,
        stray_value in any::<u16>(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let mut configuration = json!({
            "data_directory": data_directory.path(),
            "identity_store": "file",
            "peer_relay": "disabled",
        });
        configuration[&stray_name] = json!(stray_value);

        let started = NodeRuntime::start(&configuration.to_string());

        let problem = started.err().map(|problem| problem.to_string());
        let problem = problem.unwrap_or_default();
        prop_assert!(
            problem.starts_with(INVALID_CONFIGURATION_START),
            "{}",
            problem
        );
        prop_assert!(problem.contains(&stray_name), "{}", problem);
        prop_assert_eq!(list_folder_names(&data_directory), Ok(Vec::new()));
    }

    #[test]
    fn test_start_property_restarts_keep_the_device_and_free_the_port(
        restart_count in 1..=MOST_RESTARTS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let first = start_runtime(data_directory.path(), port).map_err(fail)?;
        host_on(&first).map_err(fail)?;
        let first_status = read_status_on(&first).map_err(fail)?;
        drop(first);

        for _ in 0..restart_count {
            prop_assert!(is_port_free(port), "port {} is still taken", port);
            let restarted =
                start_runtime(data_directory.path(), port).map_err(fail)?;
            let status = read_status_on(&restarted).map_err(fail)?;
            prop_assert_eq!(&status["device_id"], &first_status["device_id"]);
            prop_assert_eq!(&status["hosting_problem"], &Value::Null);
            prop_assert!(status["hosted_server_address"].is_string());
            drop(restarted);
        }
        prop_assert!(is_port_free(port), "port {} is still taken", port);
    }

    #[test]
    fn test_start_configured_property_agrees_with_starting_from_json(
        is_configured_first in any::<bool>(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let configuration = configure_folder(&data_directory, port);

        let first = if is_configured_first {
            NodeRuntime::start_configured(&configuration).map_err(fail)?
        } else {
            start_runtime(data_directory.path(), port).map_err(fail)?
        };
        let first_status = read_status_on(&first).map_err(fail)?;
        drop(first);
        let second = if is_configured_first {
            start_runtime(data_directory.path(), port).map_err(fail)?
        } else {
            NodeRuntime::start_configured(&configuration).map_err(fail)?
        };
        let second_status = read_status_on(&second).map_err(fail)?;

        prop_assert_eq!(&first_status["device_id"], &Value::Null);
        prop_assert_eq!(&first_status["account"], &Value::Null);
        prop_assert!(first_status["peer"].is_object(), "{}", first_status);
        prop_assert_eq!(&second_status["device_id"], &Value::Null);
        prop_assert!(second_status["peer"].is_object(), "{}", second_status);
    }

    #[test]
    fn test_start_configured_property_refuses_a_file_as_the_data_folder(
        file_text in "\\PC{0,20}",
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let file_path = data_directory.path().join("not-a-folder");
        fs::write(&file_path, &file_text).map_err(fail)?;
        let mut configuration = configure_folder(&data_directory, 0);
        configuration.data_directory = file_path.clone();

        let started = NodeRuntime::start_configured(&configuration);

        prop_assert!(started.is_err());
        let kept_text = fs::read_to_string(&file_path).map_err(fail)?;
        prop_assert_eq!(kept_text, file_text);
    }

    #[test]
    fn test_start_configured_property_starts_again_after_each_stop(
        restart_count in 1..=MOST_RESTARTS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let configuration = configure_folder(&data_directory, port);

        let mut device_ids = Vec::new();
        for _ in 0..restart_count {
            let runtime = NodeRuntime::start_configured(&configuration)
                .map_err(fail)?;
            let status = read_status_on(&runtime).map_err(fail)?;
            device_ids.push(status["device_id"].clone());
        }

        for device_id in &device_ids {
            prop_assert_eq!(device_id, &Value::Null);
        }
        let names = list_folder_names(&data_directory).map_err(fail)?;
        prop_assert!(!names.is_empty());
    }

    #[test]
    fn test_node_runtime_drop_property_frees_the_hosted_port(
        is_hosting in any::<bool>(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let runtime =
            start_runtime(data_directory.path(), port).map_err(fail)?;
        if is_hosting {
            host_on(&runtime).map_err(fail)?;
            prop_assert!(!is_port_free(port));
        }

        drop(runtime);

        prop_assert!(is_port_free(port), "port {} is still taken", port);
    }

    #[test]
    fn test_node_runtime_drop_property_finishes_within_the_close_limit(
        is_hosting in any::<bool>(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let runtime =
            start_runtime(data_directory.path(), port).map_err(fail)?;
        if is_hosting {
            host_on(&runtime).map_err(fail)?;
        }

        let stopping_started = Instant::now();
        drop(runtime);
        let stopping_time = stopping_started.elapsed();

        prop_assert!(stopping_time < DROP_LIMIT, "{:?}", stopping_time);
    }
}
