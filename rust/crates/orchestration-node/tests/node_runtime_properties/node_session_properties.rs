use std::collections::BTreeSet;
use std::fs;
use std::sync::Arc;

use orchestration_core::identifiers::DeviceId;
use orchestration_node::content_sealing::WorkspaceKeyring;
use orchestration_node::node::{DeviceSession, Node};
use orchestration_node::node_error::NodeError;
use orchestration_security::identity::DeviceIdentity;
use proptest::prelude::*;

use crate::access_node::open_node;
use crate::damaged_server_records::SERVER_RECORD_NAME;
use crate::support::runner_access::test_runtime;
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

const SESSION_CASES: u32 = 3;
const MOST_CALLS: usize = 5;
const WORKSPACE_NAME: &str = "acme";
const NOT_PAIRED_REASON: &str = "the device is not paired";

fn start_with_account() -> Result<(TestServer, TestDevice), TestCaseError> {
    let server = TestServer::start().map_err(fail)?;
    let device = TestDevice::start().map_err(fail)?;
    device
        .create_account(&server, WORKSPACE_NAME)
        .map_err(fail)?;
    Ok((server, device))
}

fn list_device_ids(node: &Node) -> Result<BTreeSet<DeviceId>, String> {
    let session =
        node.open_session().map_err(|problem| problem.to_string())?;
    let runtime = test_runtime()?;
    let client = session.client();
    let devices = runtime
        .block_on(client.list_devices())
        .map_err(|problem| problem.to_string())?;
    let mut device_ids = BTreeSet::new();
    for device in devices {
        device_ids.insert(device.id);
    }
    Ok(device_ids)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SESSION_CASES))]

    #[test]
    fn test_open_session_property_names_this_device_and_its_server(
        open_count in 1..MOST_CALLS,
    ) {
        let (server, device) = start_with_account()?;
        let node = open_node(&device.data_directory).map_err(fail)?;

        for _ in 0..open_count {
            let session = node.open_session().map_err(fail)?;
            prop_assert_eq!(
                session.identity.device_id(),
                session.account.device.id.clone()
            );
            prop_assert_eq!(session.server.address().to_string(),
                server.address.clone());
        }
    }

    #[test]
    fn test_open_session_property_a_missing_server_record_is_refused(
        _seed in any::<u8>(),
    ) {
        let (_server, device) = start_with_account()?;
        let data_path = device.data_directory.path();
        let record_path = data_path.join(SERVER_RECORD_NAME);
        fs::remove_file(record_path).map_err(fail)?;

        let node = open_node(&device.data_directory).map_err(fail)?;
        let opened = node.open_session();

        prop_assert!(matches!(opened, Err(NodeError::NoAppServer)));
    }

    #[test]
    fn test_device_session_client_property_lists_this_device(
        list_count in 1..MOST_CALLS,
    ) {
        let (_server, device) = start_with_account()?;
        let node = open_node(&device.data_directory).map_err(fail)?;
        let own_id = node.open_session().map_err(fail)?.identity.device_id();

        let mut listings = Vec::new();
        for _ in 0..list_count {
            listings.push(list_device_ids(&node).map_err(fail)?);
        }

        for listing in &listings {
            prop_assert!(listing.contains(&own_id));
            prop_assert_eq!(listing, &listings[0]);
        }
    }

    #[test]
    fn test_device_session_client_property_signs_as_the_session_device(
        _seed in any::<u8>(),
    ) {
        let (_server, device) = start_with_account()?;
        let node = open_node(&device.data_directory).map_err(fail)?;
        let session = node.open_session().map_err(fail)?;
        let stranger = DeviceIdentity::generate().map_err(fail)?;
        let stranger_session = DeviceSession {
            identity: Arc::new(stranger),
            account: session.account.clone(),
            keyring: WorkspaceKeyring::default(),
            server: session.server.clone(),
        };

        let runtime = test_runtime().map_err(fail)?;
        let client = stranger_session.client();
        let listed = runtime.block_on(client.list_devices());

        let refusal = listed.err().map(|problem| problem.to_string());
        let refusal = refusal.unwrap_or_default();
        prop_assert!(refusal.contains(NOT_PAIRED_REASON), "{}", refusal);
    }

    #[test]
    fn test_device_session_client_property_agrees_across_sessions(
        session_count in 2..MOST_CALLS,
    ) {
        let (_server, device) = start_with_account()?;
        let first_node = open_node(&device.data_directory).map_err(fail)?;

        let mut listings = Vec::new();
        for _ in 0..session_count {
            let node = open_node(&device.data_directory).map_err(fail)?;
            listings.push(list_device_ids(&node).map_err(fail)?);
        }

        let first_listing = list_device_ids(&first_node).map_err(fail)?;
        for listing in &listings {
            prop_assert_eq!(listing, &first_listing);
        }
    }
}
