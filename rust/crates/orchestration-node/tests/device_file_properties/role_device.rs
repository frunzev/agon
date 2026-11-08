use orchestration_node::node_runtime::NodeRuntime;
use serde_json::{Value, json};

use crate::device_folder::{DeviceFolder, create_device_folder};
use crate::support::test_device::{describe, read_success};
use crate::support::test_server::TestServer;

pub const ROLE_NAMES: [&str; 3] = ["client", "runner", "client_and_runner"];
pub const RUNNER_ROLE_NAMES: [&str; 2] = ["runner", "client_and_runner"];
pub const CLIENT_ROLE_NAMES: [&str; 2] = ["client", "client_and_runner"];
const FIRST_WORKSPACE_NAME: &str = "acme";
const DEVICE_NAME: &str = "air-laptop";

#[derive(Debug)]
pub struct RoleDevice {
    runtime: NodeRuntime,
    server: TestServer,
    _folder: DeviceFolder,
}

impl RoleDevice {
    pub fn start(role: &str) -> Result<Self, String> {
        let server = TestServer::start()?;
        let folder = create_device_folder().map_err(describe)?;
        let configuration = json!({
            "data_directory": folder.data_path,
            "identity_store": "file",
            "peer_relay": "disabled",
            "runner": "off",
        });
        let runtime = NodeRuntime::start(&configuration.to_string())
            .map_err(describe)?;
        let device = Self {
            runtime,
            server,
            _folder: folder,
        };
        device.run(&json!({
            "command": "create_account",
            "server_address": device.server.address,
            "setup_code": device.server.read_setup_code()?,
            "device_name": DEVICE_NAME,
            "role": role,
            "workspace_name": FIRST_WORKSPACE_NAME,
        }))?;
        Ok(device)
    }

    pub fn run(&self, command: &Value) -> Result<Value, String> {
        let reply_text = self.runtime.handle_command(&command.to_string());
        let reply: Value =
            serde_json::from_str(&reply_text).map_err(describe)?;
        read_success(&reply)
    }

    pub fn list(&self, command_name: &str) -> Result<Vec<Value>, String> {
        let listed = self.run(&json!({ "command": command_name }))?;
        let Value::Array(views) = listed else {
            return Err(format!("{command_name} gave no list"));
        };
        Ok(views)
    }
}
