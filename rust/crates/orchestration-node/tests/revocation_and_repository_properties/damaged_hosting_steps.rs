use std::fs;
use std::path::PathBuf;

use orchestration_node::node_runtime::NodeRuntime;
use proptest::prelude::*;
use serde_json::Value;

use crate::hosting_problem_steps::{
    HostedData, damaged_record_strategy, prepare_hosted_data, read_status_on,
};
use crate::runtime_steps::{hosted_directory_in, start_runtime};
use crate::support::test_device::describe;

pub const SERVER_KEY_FILE_NAME: &str = "server-identity.key";
pub const PEER_SECRET_FILE_NAME: &str = "peer-secret.key";
pub const STATE_FILE_NAME: &str = "state.json";
pub const PEER_PORT_FILE_NAME: &str = "peer-port.json";
pub const HOSTED_FILE_NAMES: [&str; 4] = [
    SERVER_KEY_FILE_NAME,
    PEER_SECRET_FILE_NAME,
    STATE_FILE_NAME,
    PEER_PORT_FILE_NAME,
];
pub const RECORD_DAMAGED_KIND: &str = "record_damaged";
pub const SERVER_FAILED_KIND: &str = "server_failed";
pub const KIND_FIELD: &str = "hosting_problem_kind";
pub const PROBLEM_FIELD: &str = "hosting_problem";
const GROUP_FILE_NAME: &str = "server-group.json";
const WHOLE_KEY_LENGTHS: [usize; 2] = [32, 64];

#[derive(Debug)]
pub struct DamagedHosting {
    pub hosted: HostedData,
    pub runtime: NodeRuntime,
}

impl DamagedHosting {
    pub fn read_status(&self) -> Result<Value, String> {
        read_status_on(&self.runtime)
    }

    pub fn path_of(&self, file_name: &str) -> PathBuf {
        find_hosted_file(&self.hosted, file_name)
    }

    pub fn start_again(self) -> Result<Self, String> {
        let Self { hosted, runtime } = self;
        drop(runtime);
        let runtime =
            start_runtime(hosted.data_directory.path(), hosted.port)?;
        Ok(Self { hosted, runtime })
    }
}

pub fn find_hosted_file(hosted: &HostedData, file_name: &str) -> PathBuf {
    hosted_directory_in(hosted.data_directory.path()).join(file_name)
}

pub fn prepare_hosted_data_without_group() -> Result<HostedData, String> {
    let hosted = prepare_hosted_data()?;
    let group_path = hosted.data_directory.path().join(GROUP_FILE_NAME);
    fs::remove_file(group_path).map_err(describe)?;
    Ok(hosted)
}

pub fn start_with_file_bytes(
    file_name: &str,
    file_bytes: &[u8],
) -> Result<DamagedHosting, String> {
    let hosted = prepare_hosted_data_without_group()?;
    fs::write(find_hosted_file(&hosted, file_name), file_bytes)
        .map_err(describe)?;
    let runtime = start_runtime(hosted.data_directory.path(), hosted.port)?;
    Ok(DamagedHosting { hosted, runtime })
}

pub fn start_with_folder_instead_of(
    file_name: &str,
) -> Result<DamagedHosting, String> {
    let hosted = prepare_hosted_data_without_group()?;
    let file_path = find_hosted_file(&hosted, file_name);
    fs::remove_file(&file_path).map_err(describe)?;
    fs::create_dir(&file_path).map_err(describe)?;
    let runtime = start_runtime(hosted.data_directory.path(), hosted.port)?;
    Ok(DamagedHosting { hosted, runtime })
}

pub fn read_kind_text(status: &Value) -> String {
    status[KIND_FIELD].as_str().unwrap_or_default().to_owned()
}

pub fn read_problem_text(status: &Value) -> String {
    status[PROBLEM_FIELD]
        .as_str()
        .unwrap_or_default()
        .to_owned()
}

fn damages_every_hosted_file(damaged_bytes: &[u8]) -> bool {
    let is_whole_key = WHOLE_KEY_LENGTHS.contains(&damaged_bytes.len());
    let parsed: Result<Value, _> = serde_json::from_slice(damaged_bytes);
    let is_json_object =
        parsed.is_ok_and(|parsed_value| parsed_value.is_object());
    !is_whole_key && !is_json_object
}

pub fn damaged_hosted_bytes_strategy() -> impl Strategy<Value = Vec<u8>> {
    damaged_record_strategy()
        .prop_filter("damage for every hosted file", |damaged_bytes| {
            damages_every_hosted_file(damaged_bytes)
        })
}

pub fn hosted_file_strategy() -> impl Strategy<Value = &'static str> {
    prop::sample::select(HOSTED_FILE_NAMES.to_vec())
}
