use std::collections::BTreeSet;
use std::fs;

use orchestration_api::accounts::AccountView;
use orchestration_node::device_files::DeviceFiles;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::prepare_workspace;
use crate::support::pairing_steps::pair_into_workspace;
use crate::support::test_device::{TestDevice, describe, fail, read_text};
use crate::support::test_server::TestServer;

const ACCOUNT_CASES: u32 = 3;
const NAME_PATTERN: &str = "[a-z][a-z0-9-]{0,16}";
const ACCOUNT_FILE_NAME: &str = "account.json";
const ACCOUNT_EXISTS: &str = "this device already has an account";
const MOST_STATUS_READS: usize = 2;
const SPENT_SETUP_CODE: &str = "spent-setup-code";

fn load_saved_account(device: &TestDevice) -> Result<AccountView, String> {
    let files =
        DeviceFiles::open(device.data_directory.path()).map_err(describe)?;
    let account = files.load_account().map_err(describe)?;
    account.ok_or_else(|| "the device saved no account".to_owned())
}

fn create_account(
    server: &TestServer,
    device: &TestDevice,
    device_name: &str,
    workspace_name: &str,
) -> Result<Value, String> {
    let setup_code = server.read_setup_code()?;
    create_account_with_code(
        server,
        device,
        &setup_code,
        (device_name, workspace_name),
    )
}

fn create_account_with_code(
    server: &TestServer,
    device: &TestDevice,
    setup_code: &str,
    names: (&str, &str),
) -> Result<Value, String> {
    let (device_name, workspace_name) = names;
    device.run(&json!({
        "command": "create_account",
        "server_address": server.address,
        "setup_code": setup_code,
        "device_name": device_name,
        "role": "client_and_runner",
        "workspace_name": workspace_name,
    }))
}

fn read_saved_key_ids(account: &AccountView) -> BTreeSet<String> {
    let mut key_ids = BTreeSet::new();
    for sealed_key in &account.sealed_workspace_keys {
        key_ids.insert(sealed_key.workspace_id.0.to_string());
    }
    key_ids
}

fn check_names<Check>(check: Check)
where
    Check: Fn(String, String) -> Result<(), TestCaseError>,
{
    let mut runner = TestRunner::new(Config::with_cases(ACCOUNT_CASES));
    let cases = (NAME_PATTERN, NAME_PATTERN);
    let outcome = runner.run(&cases, |(device_name, workspace_name)| {
        check(device_name, workspace_name)
    });
    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_save_known_account_property_a_new_account_is_saved_as_answered() {
    check_names(|device_name, workspace_name| {
        let server = TestServer::start().map_err(fail)?;
        let device = TestDevice::start().map_err(fail)?;

        let summary =
            create_account(&server, &device, &device_name, &workspace_name)
                .map_err(fail)?;

        let saved = load_saved_account(&device).map_err(fail)?;
        let saved_json = serde_json::to_value(&saved).map_err(fail)?;
        prop_assert_eq!(&saved_json["device"], &summary["device"]);
        prop_assert_eq!(&saved_json["workspaces"], &summary["workspaces"]);
        prop_assert_eq!(&summary["device"]["name"], &json!(device_name));
        let workspace_id =
            read_text(&summary, "/workspaces/0/id").map_err(fail)?;
        let expected_keys = BTreeSet::from([workspace_id]);
        prop_assert_eq!(read_saved_key_ids(&saved), expected_keys);
        Ok(())
    });
}

#[test]
fn test_save_known_account_property_a_second_creation_keeps_the_first() {
    check_names(|device_name, workspace_name| {
        let server = TestServer::start().map_err(fail)?;
        let device = TestDevice::start().map_err(fail)?;
        create_account(&server, &device, "air-laptop", "acme")
            .map_err(fail)?;
        let account_path =
            device.data_directory.path().join(ACCOUNT_FILE_NAME);
        let bytes_before = fs::read(&account_path).map_err(fail)?;

        let refused = create_account_with_code(
            &server,
            &device,
            SPENT_SETUP_CODE,
            (&device_name, &workspace_name),
        );

        prop_assert_eq!(refused, Err(ACCOUNT_EXISTS.to_owned()));
        let bytes_after = fs::read(&account_path).map_err(fail)?;
        prop_assert_eq!(bytes_after, bytes_before);
        Ok(())
    });
}

#[test]
fn test_save_known_account_property_a_joined_account_holds_the_key() {
    let mut runner = TestRunner::new(Config::with_cases(ACCOUNT_CASES));
    let outcome = runner.run(&(0..=MOST_STATUS_READS), |status_reads| {
        let prepared = prepare_workspace().map_err(fail)?;
        let joining_device = TestDevice::start().map_err(fail)?;

        let joined_device_id =
            pair_into_workspace(&prepared, &joining_device).map_err(fail)?;
        for _ in 0..status_reads {
            joining_device
                .run(&json!({ "command": "status" }))
                .map_err(fail)?;
        }

        let saved = load_saved_account(&joining_device).map_err(fail)?;
        prop_assert_eq!(&saved.device.id.0, &joined_device_id);
        let expected_keys = BTreeSet::from([prepared.workspace_id.clone()]);
        prop_assert_eq!(read_saved_key_ids(&saved), expected_keys);
        Ok(())
    });
    assert!(outcome.is_ok(), "{outcome:?}");
}
