use orchestration_node::node_runtime::NodeRuntime;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::test_device::{describe, read_text};
use crate::test_server::TestServer;

pub const FEATURELESS_CASES: u32 = 6;
pub const NOT_A_RUNNER_PROBLEM: &str = "this device cannot run tasks";
pub const ERROR_KIND_FIELD: &str = "error_kind";
const CASE_ROOT: &str = env!("CARGO_TARGET_TMPDIR");
const PROJECT_REPOSITORY: &str = "https://github.com/acme/app.git";

#[derive(Debug)]
pub struct FeaturelessNode {
    runtime: NodeRuntime,
    pub data_directory: TempDir,
}

#[derive(Debug)]
pub struct ServedNode {
    _server: TestServer,
    pub node: FeaturelessNode,
    pub device_id: String,
    pub project_id: String,
    pub repository_address: String,
}

impl FeaturelessNode {
    pub fn start() -> Result<Self, String> {
        std::fs::create_dir_all(CASE_ROOT).map_err(describe)?;
        let data_directory = TempDir::new_in(CASE_ROOT).map_err(describe)?;
        let configuration = json!({
            "data_directory": data_directory.path(),
            "identity_store": "file",
            "peer_relay": "disabled",
        });
        let runtime = NodeRuntime::start(&configuration.to_string())
            .map_err(describe)?;
        Ok(Self {
            runtime,
            data_directory,
        })
    }

    pub fn send(&self, command: &Value) -> Value {
        let reply_text = self.runtime.handle_command(&command.to_string());
        serde_json::from_str(&reply_text).unwrap_or(Value::Null)
    }

    pub fn run(&self, command: &Value) -> Result<Value, String> {
        let reply = self.send(command);
        if let Some(success) = reply.get("ok") {
            return Ok(success.clone());
        }
        let problem = reply.get("error").and_then(Value::as_str);
        Err(problem.unwrap_or("the reply has no outcome").to_owned())
    }
}

pub fn create_account(
    node: &FeaturelessNode,
    server: &TestServer,
) -> Result<Value, String> {
    node.run(&json!({
        "command": "create_account",
        "server_address": server.address,
        "setup_code": server.read_setup_code()?,
        "device_name": "air-laptop",
        "role": "client",
        "workspace_name": "acme",
    }))
}

pub fn start_served_node() -> Result<ServedNode, String> {
    let server = TestServer::start()?;
    let node = FeaturelessNode::start()?;
    let account = create_account(&node, &server)?;
    let device_id = read_text(&account, "/device/id")?;
    let workspace_id = read_text(&account, "/workspaces/0/id")?;
    let project = node.run(&json!({
        "command": "create_project",
        "workspace_id": workspace_id,
        "name": "acme-app",
        "repositories": [{
            "address": PROJECT_REPOSITORY,
            "default_branch": "main",
            "agent_access": "read_only",
        }],
    }))?;
    let project_id = read_text(&project, "/id")?;
    let repository_address = read_text(&project, "/repositories/0/address")?;
    Ok(ServedNode {
        _server: server,
        node,
        device_id,
        project_id,
        repository_address,
    })
}
