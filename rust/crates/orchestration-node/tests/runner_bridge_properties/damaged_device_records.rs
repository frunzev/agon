use std::fs;

use orchestration_api::accounts::AccountView;
use orchestration_core::server_group::ServerGroup;
use orchestration_node::device_files::PendingJoin;
use proptest::prelude::*;

use crate::support::test_device::{TestDevice, describe};
use crate::support::test_server::TestServer;

pub const ACCOUNT_RECORD_NAME: &str = "account.json";
pub const SERVER_GROUP_RECORD_NAME: &str = "server-group.json";
pub const PENDING_JOIN_RECORD_NAME: &str = "pending-join.json";
const WORKSPACE_NAME: &str = "acme";
const DAMAGED_TEXT_PATTERN: &str = "\\PC{0,40}";
const MOST_DAMAGED_BYTES: usize = 48;

#[derive(Clone, Debug)]
pub struct DamagedRecord {
    pub record_name: &'static str,
    pub damaged_bytes: Vec<u8>,
}

fn holds_an_account(bytes: &[u8]) -> bool {
    serde_json::from_slice::<AccountView>(bytes).is_ok()
}

fn holds_a_server_group(bytes: &[u8]) -> bool {
    serde_json::from_slice::<ServerGroup>(bytes).is_ok()
}

fn holds_a_pending_join(bytes: &[u8]) -> bool {
    serde_json::from_slice::<PendingJoin>(bytes).is_ok()
}

fn damaged_bytes_strategy(
    is_usable: fn(&[u8]) -> bool,
) -> impl Strategy<Value = Vec<u8>> {
    let damaged_text = DAMAGED_TEXT_PATTERN.prop_map(String::into_bytes);
    let damaged_bytes =
        prop::collection::vec(any::<u8>(), 0..MOST_DAMAGED_BYTES);
    let wrong_shapes = prop::sample::select(vec![
        b"{}".to_vec(),
        b"[]".to_vec(),
        b"null".to_vec(),
        b"{\"device\": 7}".to_vec(),
    ]);
    prop_oneof![damaged_text, damaged_bytes, wrong_shapes]
        .prop_filter("not a usable record", move |bytes| !is_usable(bytes))
}

pub fn damaged_account_strategy() -> impl Strategy<Value = DamagedRecord> {
    damaged_bytes_strategy(holds_an_account).prop_map(|damaged_bytes| {
        DamagedRecord {
            record_name: ACCOUNT_RECORD_NAME,
            damaged_bytes,
        }
    })
}

pub fn damaged_server_group_strategy() -> impl Strategy<Value = DamagedRecord>
{
    damaged_bytes_strategy(holds_a_server_group).prop_map(|damaged_bytes| {
        DamagedRecord {
            record_name: SERVER_GROUP_RECORD_NAME,
            damaged_bytes,
        }
    })
}

pub fn damaged_pending_join_strategy() -> impl Strategy<Value = DamagedRecord>
{
    damaged_bytes_strategy(holds_a_pending_join).prop_map(|damaged_bytes| {
        DamagedRecord {
            record_name: PENDING_JOIN_RECORD_NAME,
            damaged_bytes,
        }
    })
}

pub fn damaged_device_record_strategy() -> impl Strategy<Value = DamagedRecord>
{
    prop_oneof![
        damaged_account_strategy(),
        damaged_server_group_strategy(),
        damaged_pending_join_strategy(),
    ]
}

pub fn start_with_damaged_device_record(
    damaged: &DamagedRecord,
) -> Result<TestDevice, String> {
    let server = TestServer::start()?;
    let device = TestDevice::start()?;
    device.create_account(&server, WORKSPACE_NAME)?;
    let record_path = device.data_directory.path().join(damaged.record_name);
    fs::write(record_path, &damaged.damaged_bytes).map_err(describe)?;
    device.stop_and_start_again()
}
