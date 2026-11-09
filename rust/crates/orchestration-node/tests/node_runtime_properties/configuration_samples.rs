use std::path::PathBuf;

use orchestration_node::node_configuration::{
    IdentityStoreChoice, NodeConfiguration, PeerRelayChoice,
};
use orchestration_node::runner_settings::{RunnerChoice, RunnerOff};
use proptest::prelude::*;
use serde_json::{Map, Value, json};

pub const INVALID_CONFIGURATION_START: &str =
    "the node could not start: invalid configuration: ";
pub const KNOWN_FIELDS: [&str; 6] = [
    "data_directory",
    "identity_store",
    "runner",
    "peer_relay",
    "app_server_port",
    "server_takeover_seconds",
];
pub const REQUIRED_FIELDS: [&str; 2] = ["data_directory", "identity_store"];
const FOLDER_PATTERN: &str = "[a-z]{1,8}(/[a-z0-9 ._-]{1,8}){0,3}";
const KEY_PATTERN: &str = "\\PC{0,24}";
const RELAY_PATTERN: &str = "https://[a-z]{1,8}\\.test";

pub fn identity_store_strategy() -> impl Strategy<Value = IdentityStoreChoice>
{
    prop_oneof![
        Just(IdentityStoreChoice::Keychain),
        Just(IdentityStoreChoice::File),
        KEY_PATTERN.prop_map(|key| IdentityStoreChoice::EncryptedFile { key }),
    ]
}

pub fn peer_relay_strategy() -> impl Strategy<Value = PeerRelayChoice> {
    prop_oneof![
        Just(PeerRelayChoice::Default),
        Just(PeerRelayChoice::Disabled),
        RELAY_PATTERN.prop_map(PeerRelayChoice::Custom),
    ]
}

type ConfigurationParts =
    (String, IdentityStoreChoice, bool, PeerRelayChoice, u16, u64);

fn build_configuration(parts: ConfigurationParts) -> NodeConfiguration {
    let (folder, identity_store, is_runner_off, peer_relay, port, seconds) =
        parts;
    let runner = is_runner_off.then_some(RunnerChoice::Off(RunnerOff::Off));
    NodeConfiguration {
        data_directory: PathBuf::from(folder),
        identity_store,
        runner,
        peer_relay,
        app_server_port: port,
        server_takeover_seconds: seconds,
    }
}

pub fn configuration_strategy() -> impl Strategy<Value = NodeConfiguration> {
    (
        FOLDER_PATTERN,
        identity_store_strategy(),
        any::<bool>(),
        peer_relay_strategy(),
        any::<u16>(),
        any::<u64>(),
    )
        .prop_map(build_configuration)
}

fn write_identity_store(identity_store: &IdentityStoreChoice) -> Value {
    match identity_store {
        IdentityStoreChoice::Keychain => json!("keychain"),
        IdentityStoreChoice::File => json!("file"),
        IdentityStoreChoice::EncryptedFile { key } => {
            json!({ "encrypted_file": { "key": key } })
        }
    }
}

fn write_peer_relay(peer_relay: &PeerRelayChoice) -> Value {
    match peer_relay {
        PeerRelayChoice::Default => json!("default"),
        PeerRelayChoice::Disabled => json!("disabled"),
        PeerRelayChoice::Custom(relay_url) => json!({ "custom": relay_url }),
    }
}

pub fn write_configuration(
    configuration: &NodeConfiguration,
) -> Map<String, Value> {
    let mut fields = Map::new();
    fields.insert(
        "data_directory".to_owned(),
        json!(configuration.data_directory),
    );
    fields.insert(
        "identity_store".to_owned(),
        write_identity_store(&configuration.identity_store),
    );
    if configuration.runner.is_some() {
        fields.insert("runner".to_owned(), json!("off"));
    }
    fields.insert(
        "peer_relay".to_owned(),
        write_peer_relay(&configuration.peer_relay),
    );
    fields.insert(
        "app_server_port".to_owned(),
        json!(configuration.app_server_port),
    );
    fields.insert(
        "server_takeover_seconds".to_owned(),
        json!(configuration.server_takeover_seconds),
    );
    fields
}

pub fn parse_fields(
    fields: Map<String, Value>,
) -> Result<NodeConfiguration, String> {
    let configuration_json = Value::Object(fields).to_string();
    NodeConfiguration::from_json(&configuration_json)
        .map_err(|problem| problem.to_string())
}
