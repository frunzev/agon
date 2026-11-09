use std::fs;
use std::path::{Path, PathBuf};

use orchestration_node::server_address::ServerAddress;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::test_device::{TestDevice, describe};
use crate::support::test_server::TestServer;

pub const SERVER_RECORD_NAME: &str = "app-server.json";
pub const PROBLEM_FIELD: &str = "hosting_problem";
pub const KIND_FIELD: &str = "hosting_problem_kind";
pub const RECORD_DAMAGED_KIND: &str = "record_damaged";
const ADDRESS_FIELD: &str = "server_address";
const WORKSPACE_NAME: &str = "acme";
const ADDRESS_TEXT_PATTERN: &str = "\\PC{0,30}";
const DAMAGED_TEXT_PATTERN: &str = "\\PC{0,40}";
const MOST_DAMAGED_BYTES: usize = 48;

pub fn server_record_in(data_directory: &Path) -> PathBuf {
    data_directory.join(SERVER_RECORD_NAME)
}

pub fn damaged_server_record_strategy() -> impl Strategy<Value = Vec<u8>> {
    let unparsable_address = ADDRESS_TEXT_PATTERN
        .prop_filter("not a server address", |text| {
            ServerAddress::parse(text).is_err()
        })
        .prop_map(|text| json!({ ADDRESS_FIELD: text }).to_string());
    let damaged_text = DAMAGED_TEXT_PATTERN.prop_map(String::into_bytes);
    let damaged_bytes =
        prop::collection::vec(any::<u8>(), 0..MOST_DAMAGED_BYTES);
    prop_oneof![
        unparsable_address.prop_map(String::into_bytes),
        damaged_text,
        damaged_bytes,
    ]
    .prop_filter("not a usable server record", |bytes| {
        !may_hold_a_server_address(bytes)
    })
}

fn may_hold_a_server_address(bytes: &[u8]) -> bool {
    let parsed: Result<Value, _> = serde_json::from_slice(bytes);
    let Ok(record) = parsed else {
        return false;
    };
    let address_text = record.get(ADDRESS_FIELD).and_then(Value::as_str);
    address_text.is_some_and(|text| ServerAddress::parse(text).is_ok())
}

pub fn start_with_damaged_record(
    damaged_bytes: &[u8],
) -> Result<TestDevice, String> {
    let server = TestServer::start()?;
    let device = TestDevice::start()?;
    device.create_account(&server, WORKSPACE_NAME)?;
    let record_path = server_record_in(device.data_directory.path());
    fs::write(record_path, damaged_bytes).map_err(describe)?;
    device.stop_and_start_again()
}

pub fn read_status(device: &TestDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "status" }))
}

pub fn forget_device(device: &TestDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "forget_this_device" }))
}

pub fn set_up_again(device: &TestDevice) -> Result<TestServer, String> {
    let fresh_server = TestServer::start()?;
    device.create_account(&fresh_server, WORKSPACE_NAME)?;
    Ok(fresh_server)
}
