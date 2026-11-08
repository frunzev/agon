use std::fs;
use std::path::Path;

use orchestration_node::identity_store::EncryptedFileIdentityStore;
use orchestration_node::node::Node;
use orchestration_node::node_configuration::{
    DEFAULT_APP_SERVER_PORT, DEFAULT_TAKEOVER_SECONDS, IdentityStoreChoice,
    NodeConfiguration, PeerRelayChoice,
};
use orchestration_security::sealing::WorkspaceKey;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use tempfile::TempDir;

use crate::support::test_device::fail;

pub const STORE_KEY_LENGTH: usize = 32;
pub const PLAIN_IDENTITY_FILE_NAME: &str = "device-identity.key";
pub const PLAIN_PEER_SECRET_FILE_NAME: &str = "peer-secret.key";
pub const SEALED_IDENTITY_FILE_NAME: &str = "device-identity.sealed";
pub const SEALED_PEER_SECRET_FILE_NAME: &str = "peer-secret.sealed";
const LONGEST_DAMAGED_SECRET: usize = 128;

pub type StoreKey = [u8; STORE_KEY_LENGTH];

pub fn plant(path: &Path, bytes: &[u8]) -> Result<(), TestCaseError> {
    fs::write(path, bytes).map_err(fail)
}

pub fn plant_sealed(
    path: &Path,
    key: &StoreKey,
    bytes: &[u8],
) -> Result<(), TestCaseError> {
    let file_key = WorkspaceKey::from_bytes(key).map_err(fail)?;
    let sealed = file_key.encrypt(bytes).map_err(fail)?;
    plant(path, &sealed)
}

pub fn open_sealed_store(
    directory: &TempDir,
    key: &StoreKey,
) -> Result<EncryptedFileIdentityStore, TestCaseError> {
    let path = directory.path().join(SEALED_IDENTITY_FILE_NAME);
    EncryptedFileIdentityStore::new(path, key).map_err(fail)
}

pub fn wrong_length_strategy(
    right_length: usize,
) -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..LONGEST_DAMAGED_SECRET)
        .prop_filter("a damaged length", move |bytes| {
            bytes.len() != right_length
        })
}

pub fn open_node(
    directory: &TempDir,
    identity_store: IdentityStoreChoice,
) -> Result<Node, String> {
    let configuration = NodeConfiguration {
        data_directory: directory.path().to_path_buf(),
        identity_store,
        runner: None,
        peer_relay: PeerRelayChoice::Disabled,
        app_server_port: DEFAULT_APP_SERVER_PORT,
        server_takeover_seconds: DEFAULT_TAKEOVER_SECONDS,
    };
    Node::open(&configuration).map_err(|error| error.to_string())
}

pub fn sealed_choice(key: &StoreKey) -> IdentityStoreChoice {
    IdentityStoreChoice::EncryptedFile {
        key: hex::encode(key),
    }
}
