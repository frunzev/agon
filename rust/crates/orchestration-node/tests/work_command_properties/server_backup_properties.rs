use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::handler_desk::{NO_ACCOUNT_PROBLEM, read_own_device_id};
use crate::support::hosting_steps::{
    HostingDevice, pick_free_port, read_hosted_address, read_status,
    start_hosting_device,
};
use crate::support::server_backups::{
    pair_client_at, start_server_backup, stop_server_backup,
};
use crate::support::test_device::{TestDevice, fail, read_text};
use crate::support::test_server::TestServer;
use crate::work_desk::CheckOutcome;

const BACKUP_CASES: u32 = 3;
const MOST_ATTEMPTS: usize = 3;
const STEADY_TAKEOVER_SECONDS: u64 = 3600;
const RUNNER_REFUSAL: &str =
    "only a client device can keep a backup of the app server";
const NO_BACKUPS_REFUSAL: &str = "the app server keeps no backups";
const NOT_KEEPING_REFUSAL: &str = "this device keeps no app server";
const HOSTED_SERVER_DIRECTORY: &str = "hosted-app-server";
const BACKUP_DEVICE_NAME: &str = "studio-mac";

fn check_attempts<Check>(role: Option<&str>, check: Check)
where
    Check: Fn(&TestServer, &TestDevice, usize) -> CheckOutcome,
{
    let mut runner = TestRunner::new(Config::with_cases(BACKUP_CASES));
    let outcome = runner.run(&(1..=MOST_ATTEMPTS), |attempts| {
        let server = TestServer::start().map_err(fail)?;
        let port = pick_free_port().map_err(fail)?;
        let device = TestDevice::start_keeping(port, STEADY_TAKEOVER_SECONDS)
            .map_err(fail)?;
        if let Some(role) = role {
            device
                .create_account_with_role(&server, "acme", role)
                .map_err(fail)?;
        }
        check(&server, &device, attempts)
    });
    assert!(outcome.is_ok(), "{outcome:?}");
}

fn has_hosted_directory(device: &TestDevice) -> bool {
    device
        .data_directory
        .path()
        .join(HOSTED_SERVER_DIRECTORY)
        .exists()
}

fn list_server_ids(app_servers: &Value) -> Vec<Value> {
    let mut device_ids = Vec::new();
    for server in app_servers["servers"]
        .as_array()
        .cloned()
        .unwrap_or_default()
    {
        device_ids.push(server["device_id"].clone());
    }
    device_ids.sort_by_key(ToString::to_string);
    device_ids
}

#[test]
fn test_start_backup_here_property_a_runner_device_is_refused_at_once() {
    check_attempts(Some("runner"), |server, device, attempts| {
        let requests_before = server.recorded_requests().len();

        for _ in 0..attempts {
            let refused = start_server_backup(device);
            prop_assert_eq!(refused, Err(RUNNER_REFUSAL.to_owned()));
        }

        prop_assert_eq!(server.recorded_requests().len(), requests_before);
        prop_assert!(!has_hosted_directory(device));
        Ok(())
    });
}

#[test]
fn test_start_backup_here_property_a_lone_server_keeps_no_backups() {
    check_attempts(Some("client"), |_server, device, attempts| {
        for _ in 0..attempts {
            let refused = start_server_backup(device);
            prop_assert_eq!(refused, Err(NO_BACKUPS_REFUSAL.to_owned()));
        }

        let stopped = stop_server_backup(device);
        prop_assert_eq!(stopped, Err(NOT_KEEPING_REFUSAL.to_owned()));
        prop_assert!(!has_hosted_directory(device));
        Ok(())
    });
}

#[test]
fn test_start_backup_here_property_a_device_without_account_is_refused() {
    check_attempts(None, |_server, device, attempts| {
        for _ in 0..attempts {
            let refused = start_server_backup(device);
            prop_assert_eq!(refused, Err(NO_ACCOUNT_PROBLEM.to_owned()));
        }

        prop_assert!(!has_hosted_directory(device));
        Ok(())
    });
}

#[test]
fn test_stop_backup_here_property_keeping_nothing_sends_nothing() {
    check_attempts(Some("client"), |server, device, attempts| {
        let requests_before = server.recorded_requests().len();

        for _ in 0..attempts {
            let refused = stop_server_backup(device);
            prop_assert_eq!(refused, Err(NOT_KEEPING_REFUSAL.to_owned()));
        }

        prop_assert_eq!(server.recorded_requests().len(), requests_before);
        Ok(())
    });
}

#[test]
fn test_stop_backup_here_property_a_device_without_account_is_refused() {
    check_attempts(None, |_server, device, attempts| {
        for _ in 0..attempts {
            let refused = stop_server_backup(device);
            prop_assert_eq!(refused, Err(NO_ACCOUNT_PROBLEM.to_owned()));
        }

        prop_assert!(!has_hosted_directory(device));
        Ok(())
    });
}

#[test]
fn test_stop_backup_here_property_a_runner_device_keeps_nothing() {
    check_attempts(Some("runner"), |server, device, attempts| {
        let requests_before = server.recorded_requests().len();

        for _ in 0..attempts {
            let refused = stop_server_backup(device);
            prop_assert_eq!(refused, Err(NOT_KEEPING_REFUSAL.to_owned()));
        }

        prop_assert_eq!(server.recorded_requests().len(), requests_before);
        Ok(())
    });
}

struct BackupPair {
    hosting: HostingDevice,
    backup: TestDevice,
}

fn pair_backup_device() -> Result<BackupPair, String> {
    let hosting = start_hosting_device()?;
    let workspace_id = read_text(&hosting.account, "/workspaces/0/id")?;
    let address = read_hosted_address(&hosting.device)?;
    let backup =
        TestDevice::start_keeping(pick_free_port()?, STEADY_TAKEOVER_SECONDS)?;
    pair_client_at(
        &hosting.device,
        &backup,
        &address,
        &workspace_id,
        BACKUP_DEVICE_NAME,
    )?;
    Ok(BackupPair { hosting, backup })
}

fn read_standing_and_servers(app_servers: &Value) -> (Value, Vec<Value>) {
    (
        app_servers["this_device"].clone(),
        list_server_ids(app_servers),
    )
}

fn read_status_servers(device: &TestDevice) -> Result<Value, String> {
    let status = read_status(device)?;
    Ok(status["app_servers"].clone())
}

#[test]
fn test_handle_server_backup_command_property_replies_the_fresh_group() {
    let mut runner = TestRunner::new(Config::with_cases(1));
    let outcome = runner.run(&(1..=2_usize), |cycles| {
        let pair = pair_backup_device().map_err(fail)?;
        let backup_id = json!(read_own_device_id(&pair.backup).map_err(fail)?);
        let hosting_id =
            json!(read_own_device_id(&pair.hosting.device).map_err(fail)?);

        for _ in 0..cycles {
            let started = start_server_backup(&pair.backup).map_err(fail)?;
            let started_status =
                read_status_servers(&pair.backup).map_err(fail)?;
            let stopped = stop_server_backup(&pair.backup).map_err(fail)?;
            let stopped_status =
                read_status_servers(&pair.backup).map_err(fail)?;

            prop_assert_eq!(&started["this_device"], "backup");
            let started_ids = list_server_ids(&started);
            prop_assert!(started_ids.contains(&backup_id));
            prop_assert!(started_ids.contains(&hosting_id));
            prop_assert_eq!(
                read_standing_and_servers(&started),
                read_standing_and_servers(&started_status)
            );
            prop_assert_eq!(&stopped["this_device"], "none");
            prop_assert_eq!(
                list_server_ids(&stopped),
                vec![hosting_id.clone()]
            );
            prop_assert_eq!(
                read_standing_and_servers(&stopped),
                read_standing_and_servers(&stopped_status)
            );
        }
        Ok(())
    });
    assert!(outcome.is_ok(), "{outcome:?}");
}
