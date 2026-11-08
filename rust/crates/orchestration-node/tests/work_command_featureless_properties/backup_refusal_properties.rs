use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};

use crate::featureless_node::{FEATURELESS_CASES, FeaturelessNode};
use crate::test_device::fail;
use crate::test_server::TestServer;

const HOSTING_UNAVAILABLE: &str = "this device cannot host the app server";
const ROLE_NAMES: [&str; 3] = ["client", "runner", "client_and_runner"];
const MOST_ATTEMPTS: usize = 3;
const START_COMMAND: &str = "start_server_backup";
const STOP_COMMAND: &str = "stop_server_backup";
const HOSTED_SERVER_DIRECTORY: &str = "hosted-app-server";

fn create_account_with_role(
    node: &FeaturelessNode,
    server: &TestServer,
    role: &str,
) -> Result<Value, String> {
    node.run(&json!({
        "command": "create_account",
        "server_address": server.address,
        "setup_code": server.read_setup_code()?,
        "device_name": "air-laptop",
        "role": role,
        "workspace_name": "acme",
    }))
}

fn refuse_every_attempt(
    node: &FeaturelessNode,
    command_name: &str,
    attempts: usize,
) -> Result<(), TestCaseError> {
    for _ in 0..attempts {
        let refused = node.run(&json!({ "command": command_name }));
        prop_assert_eq!(refused, Err(HOSTING_UNAVAILABLE.to_owned()));
    }
    Ok(())
}

fn refuse_with_role(
    command_name: &str,
    role: &str,
    attempts: usize,
) -> Result<(), TestCaseError> {
    let server = TestServer::start().map_err(fail)?;
    let node = FeaturelessNode::start().map_err(fail)?;
    create_account_with_role(&node, &server, role).map_err(fail)?;
    let requests_before = server.recorded_requests().len();

    refuse_every_attempt(&node, command_name, attempts)?;

    prop_assert_eq!(server.recorded_requests().len(), requests_before);
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FEATURELESS_CASES))]

    #[test]
    fn test_start_backup_here_property_without_hosting_every_role_is_refused(
        role in select(ROLE_NAMES.to_vec()),
        attempts in 1..=MOST_ATTEMPTS,
    ) {
        refuse_with_role(START_COMMAND, role, attempts)?;
    }

    #[test]
    fn test_start_backup_here_property_without_hosting_even_with_no_account(
        attempts in 1..=MOST_ATTEMPTS,
    ) {
        let node = FeaturelessNode::start().map_err(fail)?;

        refuse_every_attempt(&node, START_COMMAND, attempts)?;
    }

    #[test]
    fn test_start_backup_here_property_without_hosting_stop_stays_refused(
        role in select(ROLE_NAMES.to_vec()),
        attempts in 1..=MOST_ATTEMPTS,
    ) {
        refuse_with_role(START_COMMAND, role, 1)?;
        refuse_with_role(STOP_COMMAND, role, attempts)?;
    }

    #[test]
    fn test_stop_backup_here_property_without_hosting_every_role_is_refused(
        role in select(ROLE_NAMES.to_vec()),
        attempts in 1..=MOST_ATTEMPTS,
    ) {
        refuse_with_role(STOP_COMMAND, role, attempts)?;
    }

    #[test]
    fn test_stop_backup_here_property_without_hosting_even_with_no_account(
        attempts in 1..=MOST_ATTEMPTS,
    ) {
        let node = FeaturelessNode::start().map_err(fail)?;

        refuse_every_attempt(&node, STOP_COMMAND, attempts)?;
    }

    #[test]
    fn test_stop_backup_here_property_without_hosting_leaves_no_server_files(
        attempts in 1..=MOST_ATTEMPTS,
    ) {
        let node = FeaturelessNode::start().map_err(fail)?;

        refuse_every_attempt(&node, STOP_COMMAND, attempts)?;
        refuse_every_attempt(&node, START_COMMAND, attempts)?;

        let hosted_directory =
            node.data_directory.path().join(HOSTED_SERVER_DIRECTORY);
        prop_assert!(!hosted_directory.exists());
    }
}
