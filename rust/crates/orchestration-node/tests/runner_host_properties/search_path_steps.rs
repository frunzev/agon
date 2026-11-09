use std::env;
use std::fs;
use std::os::unix::fs::{PermissionsExt, symlink};
use std::path::{Path, PathBuf};
use std::time::Duration;

use serde_json::{Value, json};
use tempfile::TempDir;

use crate::support::node_process::{NodeProcess, ProcessSetup};
use crate::support::test_device::describe;
use crate::support::test_server::TestServer;
use crate::support::waiting::wait_for;

pub const XCODE_PROGRAM: &str = "xcodebuild";
pub const XCODE_LABEL: &str = "xcode";
pub const EXECUTABLE_MODE: u32 = 0o755;
const SEARCH_PATH_VARIABLE: &str = "PATH";
const PROGRAM_SCRIPT: &str = "#!/bin/sh\nexit 0\n";
const SETTINGS_LIMIT: Duration = Duration::from_secs(60);
const LABELS_POINTER: &str = "/runner_settings/labels";

pub fn write_program(program_path: &Path, mode: u32) -> Result<(), String> {
    fs::write(program_path, PROGRAM_SCRIPT).map_err(describe)?;
    let permissions = fs::Permissions::from_mode(mode);
    fs::set_permissions(program_path, permissions).map_err(describe)
}

pub fn place_program_folder(folder: &Path) -> Result<(), String> {
    let program_path = folder.join(XCODE_PROGRAM);
    fs::create_dir(&program_path).map_err(describe)?;
    let permissions = fs::Permissions::from_mode(EXECUTABLE_MODE);
    fs::set_permissions(&program_path, permissions).map_err(describe)
}

pub fn place_program_link(folder: &Path, target: &Path) -> Result<(), String> {
    symlink(target, folder.join(XCODE_PROGRAM)).map_err(describe)
}

fn join_search_path(folders: &[PathBuf]) -> Result<String, String> {
    let joined = env::join_paths(folders).map_err(describe)?;
    joined
        .into_string()
        .map_err(|_not_text| "the search path is not text".to_owned())
}

fn read_labels(status: &Value) -> Option<Vec<String>> {
    let labels = status.pointer(LABELS_POINTER)?.as_array()?;
    let mut label_texts = Vec::new();
    for label in labels {
        label_texts.push(label.as_str()?.to_owned());
    }
    Some(label_texts)
}

pub fn read_detected_labels(
    search_path_folders: &[PathBuf],
) -> Result<Vec<String>, String> {
    let server = TestServer::start()?;
    let data = TempDir::new().map_err(describe)?;
    let configuration = json!({
        "data_directory": data.path(),
        "identity_store": "file",
        "peer_relay": "disabled",
    });
    let search_path = join_search_path(search_path_folders)?;
    let environment = vec![(SEARCH_PATH_VARIABLE, search_path)];
    let runner = NodeProcess::start(&ProcessSetup {
        configuration: &configuration,
        environment: &environment,
    })?;
    runner.run(&json!({
        "command": "create_account",
        "server_address": server.address,
        "setup_code": server.read_setup_code()?,
        "device_name": "build-box",
        "role": "client_and_runner",
        "workspace_name": "acme",
    }))?;

    let labels = wait_for(SETTINGS_LIMIT, "the detected settings", || {
        let status = runner.run(&json!({ "command": "status" }))?;
        Ok(read_labels(&status))
    })?;
    runner.stop()?;
    Ok(labels)
}
