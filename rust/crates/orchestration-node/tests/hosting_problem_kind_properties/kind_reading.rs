use std::fs;
use std::net::{Ipv4Addr, TcpListener};

use serde_json::Value;
use tempfile::TempDir;

use crate::hosting_problem_steps::{
    FailedHosting, HostedData, HostingFailure, prepare_hosted_data,
    read_status_on, start_after_failure,
};
use crate::runtime_steps::{hosted_record_in, start_runtime};
use crate::support::hosting_steps::pick_free_port;
use crate::support::test_device::describe;

pub const PROBLEM_FIELD: &str = "hosting_problem";
pub const KIND_FIELD: &str = "hosting_problem_kind";
pub const PORT_UNAVAILABLE_KIND: &str = "port_unavailable";
pub const RECORD_DAMAGED_KIND: &str = "record_damaged";
pub const SERVER_FAILED_KIND: &str = "server_failed";
pub const KNOWN_KINDS: [&str; 3] = [
    PORT_UNAVAILABLE_KIND,
    RECORD_DAMAGED_KIND,
    SERVER_FAILED_KIND,
];
const GROUP_FILE_NAME: &str = "server-group.json";
const UNFINISHED_RECORD: &[u8] = b"{";

#[derive(Clone, Copy, Debug)]
pub enum DeviceStage {
    Fresh,
    HealthyHost,
    TakenPort,
    DamagedRecord,
}

pub fn read_kind(status: &Value) -> Value {
    status[KIND_FIELD].clone()
}

pub fn read_problem(status: &Value) -> Value {
    status[PROBLEM_FIELD].clone()
}

pub fn start_with_record_bytes(
    record_bytes: &[u8],
) -> Result<FailedHosting, String> {
    let failure = HostingFailure::DamagedRecord(record_bytes.to_vec());
    start_after_failure(&failure)
}

pub fn start_with_port_held() -> Result<FailedHosting, String> {
    let hosted = prepare_without_group()?;
    let holder = TcpListener::bind((Ipv4Addr::LOCALHOST, hosted.port))
        .map_err(describe)?;
    let runtime = start_runtime(hosted.data_directory.path(), hosted.port)?;
    Ok(FailedHosting {
        hosted,
        runtime,
        occupier: Some(holder),
    })
}

pub fn start_with_record_as_folder() -> Result<FailedHosting, String> {
    let hosted = prepare_without_group()?;
    let data_directory = hosted.data_directory.path();
    let record_path = hosted_record_in(data_directory);
    fs::remove_file(&record_path).map_err(describe)?;
    fs::create_dir(&record_path).map_err(describe)?;
    let runtime = start_runtime(data_directory, hosted.port)?;
    Ok(FailedHosting {
        hosted,
        runtime,
        occupier: None,
    })
}

fn prepare_without_group() -> Result<HostedData, String> {
    let hosted = prepare_hosted_data()?;
    let group_path = hosted.data_directory.path().join(GROUP_FILE_NAME);
    fs::remove_file(group_path).map_err(describe)?;
    Ok(hosted)
}

pub fn read_status_at_stage(stage: DeviceStage) -> Result<Value, String> {
    match stage {
        DeviceStage::Fresh => {
            let data_directory = TempDir::new().map_err(describe)?;
            let runtime =
                start_runtime(data_directory.path(), pick_free_port()?)?;
            read_status_on(&runtime)
        }
        DeviceStage::HealthyHost => {
            let hosted = prepare_hosted_data()?;
            let data_directory = hosted.data_directory.path();
            let runtime = start_runtime(data_directory, hosted.port)?;
            read_status_on(&runtime)
        }
        DeviceStage::TakenPort => {
            let failed = start_after_failure(&HostingFailure::TakenPort)?;
            read_status_on(&failed.runtime)
        }
        DeviceStage::DamagedRecord => {
            let failed = start_with_record_bytes(UNFINISHED_RECORD)?;
            read_status_on(&failed.runtime)
        }
    }
}
