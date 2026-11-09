use orchestration_node::device_files::AppServerRecord;
use orchestration_node::node::Node;
use orchestration_node::node_configuration::{
    DEFAULT_APP_SERVER_PORT, DEFAULT_TAKEOVER_SECONDS, IdentityStoreChoice,
    NodeConfiguration, PeerRelayChoice,
};
use orchestration_node::node_error::NodeError;
use orchestration_node::server_address::ServerAddress;
use proptest::test_runner::TestCaseError;
use tempfile::TempDir;

use crate::support::test_device::fail;

pub const ACCESS_CASES: u32 = 24;

pub fn open_node(data_directory: &TempDir) -> Result<Node, NodeError> {
    let configuration = NodeConfiguration {
        data_directory: data_directory.path().to_path_buf(),
        identity_store: IdentityStoreChoice::File,
        runner: None,
        peer_relay: PeerRelayChoice::Disabled,
        app_server_port: DEFAULT_APP_SERVER_PORT,
        server_takeover_seconds: DEFAULT_TAKEOVER_SECONDS,
    };
    Node::open(&configuration)
}

pub fn remember_address(
    node: &Node,
    address: &ServerAddress,
) -> Result<(), TestCaseError> {
    let server = node.connect_to_server(address).map_err(fail)?;
    node.remember_app_server(&server).map_err(fail)
}

pub fn read_app_server_address(
    node: &Node,
) -> Result<ServerAddress, NodeError> {
    let server = node.app_server()?;
    Ok(server.address().clone())
}

pub fn save_record(
    node: &Node,
    server_address: &str,
) -> Result<(), TestCaseError> {
    let record = AppServerRecord {
        server_address: server_address.to_owned(),
    };
    node.device_files().save_app_server(&record).map_err(fail)
}

pub fn has_no_app_server(node: &Node) -> bool {
    matches!(node.app_server(), Err(NodeError::NoAppServer))
}
