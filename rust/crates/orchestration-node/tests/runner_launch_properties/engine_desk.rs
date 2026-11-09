use std::fs;
use std::path::PathBuf;
use std::thread;
use std::time::Duration;

use serde_json::{Value, json};
use tempfile::TempDir;

use crate::engine_scripts::{
    EngineAnswers, EngineManner, read_calls, write_engine,
};
use crate::support::node_process::{
    EnvironmentVariable, NodeProcess, ProcessSetup,
};
use crate::support::test_device::describe;
use crate::support::test_server::TestServer;
use crate::support::waiting::wait_for;

pub const HEARTBEAT_PATH: &str = "/runners/heartbeat";
pub const CLAIM_PATH: &str = "/runners/claim";
pub const RUNNER_LIMIT: Duration = Duration::from_secs(20);
pub const LONGER_THAN_A_CLAIM_INTERVAL: Duration = Duration::from_secs(7);
pub const LONGER_THAN_AN_IMAGE_RECHECK: Duration =
    Duration::from_millis(10_500);
pub const READY_ENGINE: EngineAnswers = EngineAnswers {
    info_exit_code: 0,
    image_exit_code: 0,
};
pub const MISSING_IMAGE: EngineAnswers = EngineAnswers {
    info_exit_code: 0,
    image_exit_code: 1,
};
pub const STOPPED_ENGINE: EngineAnswers = EngineAnswers {
    info_exit_code: 1,
    image_exit_code: 1,
};
pub const API_KEY: &str = "sk-ant-launch-properties-key";
pub const IMAGE: &str = "agents-orchestration-runner:latest";
const SEARCH_PATH_VARIABLE: &str = "PATH";
const ENGINE_PROGRAM: &str = "docker";
const SETTLING_PAUSE: Duration = Duration::from_millis(500);

#[derive(Debug)]
pub struct EngineDesk {
    pub server: TestServer,
    pub runner: NodeProcess,
    engine_path: PathBuf,
    configuration: Value,
    environment: Vec<EnvironmentVariable>,
    _engine_folder: TempDir,
    _data: TempDir,
}

pub fn local_sandbox() -> Value {
    json!({ "kind": "local_process" })
}

pub fn container_sandbox(allowed_hosts: &[String]) -> Value {
    json!({
        "kind": "container",
        "engine": ENGINE_PROGRAM,
        "image": IMAGE,
        "allowed_hosts": allowed_hosts,
    })
}

pub fn runner_settings(sandbox: &Value, labels: &[String]) -> Value {
    json!({
        "labels": labels,
        "slot_capacity": 1,
        "sandbox": sandbox,
    })
}

fn write_docker(
    folder: &TempDir,
    answers: EngineAnswers,
) -> Result<PathBuf, String> {
    let written = write_engine(folder.path(), answers, EngineManner::Plain)?;
    let docker_path = folder.path().join(ENGINE_PROGRAM);
    fs::rename(written, &docker_path).map_err(describe)?;
    Ok(docker_path)
}

pub fn open_engine_desk(
    settings: &Value,
    answers: EngineAnswers,
) -> Result<EngineDesk, String> {
    let server = TestServer::start()?;
    let engine_folder = TempDir::new().map_err(describe)?;
    let engine_path = write_docker(&engine_folder, answers)?;
    let data = TempDir::new().map_err(describe)?;
    let inherited_path =
        std::env::var(SEARCH_PATH_VARIABLE).map_err(describe)?;
    let search_path =
        format!("{}:{inherited_path}", engine_folder.path().display());
    let configuration = json!({
        "data_directory": data.path(),
        "identity_store": "file",
        "peer_relay": "disabled",
        "runner": settings,
    });
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
    Ok(EngineDesk {
        server,
        runner,
        engine_path,
        configuration,
        environment,
        _engine_folder: engine_folder,
        _data: data,
    })
}

impl EngineDesk {
    pub fn restart(self) -> Result<Self, String> {
        let Self {
            server,
            runner,
            engine_path,
            configuration,
            environment,
            _engine_folder: engine_folder,
            _data: data,
        } = self;
        runner.stop()?;
        let fresh_runner = NodeProcess::start(&ProcessSetup {
            configuration: &configuration,
            environment: &environment,
        })?;
        Ok(Self {
            server,
            runner: fresh_runner,
            engine_path,
            configuration,
            environment,
            _engine_folder: engine_folder,
            _data: data,
        })
    }

    pub fn count_engine_calls(&self) -> usize {
        read_calls(&self.engine_path).len()
    }

    pub fn count_runner_requests(&self) -> usize {
        let requests = self.server.recorded_requests();
        let mut runner_request_count = 0;
        for request in requests {
            if request.path == HEARTBEAT_PATH || request.path == CLAIM_PATH {
                runner_request_count += 1;
            }
        }
        runner_request_count
    }

    pub fn read_heartbeats(&self) -> Vec<Value> {
        let mut heartbeats = Vec::new();
        for request in self.server.recorded_requests() {
            if request.path != HEARTBEAT_PATH {
                continue;
            }
            if let Ok(body) = serde_json::from_slice(&request.body) {
                heartbeats.push(body);
            }
        }
        heartbeats
    }

    pub fn wait_for_heartbeat_after(
        &self,
        seen_count: usize,
    ) -> Result<Value, String> {
        self.wait_for_heartbeat_within(seen_count, RUNNER_LIMIT)
    }

    pub fn wait_for_heartbeat_within(
        &self,
        seen_count: usize,
        limit: Duration,
    ) -> Result<Value, String> {
        wait_for(limit, "a new heartbeat", || {
            let heartbeats = self.read_heartbeats();
            Ok(heartbeats.get(seen_count).cloned())
        })
    }

    pub fn wait_for_offers(&self, expected: &Value) -> Result<(), String> {
        wait_for(RUNNER_LIMIT, "a heartbeat with the offers", || {
            let heartbeats = self.read_heartbeats();
            let last = heartbeats.last().map(|heartbeat| &heartbeat["offers"]);
            Ok((last == Some(expected)).then_some(()))
        })
    }

    pub fn choose_offers(&self, offers: &Value) -> Result<Value, String> {
        self.runner.run(&json!({
            "command": "choose_agent_offers",
            "offers": offers,
        }))
    }

    pub fn save_api_key(&self) -> Result<Value, String> {
        self.runner.run(&json!({
            "command": "save_agent_api_key",
            "api_key": API_KEY,
        }))
    }

    pub fn read_status(&self) -> Result<Value, String> {
        self.runner.run(&json!({ "command": "status" }))
    }

    pub fn list_checked_offers(&self) -> Result<Value, String> {
        let runners = self.runner.run(&json!({
            "command": "list_runners",
            "workspace_id": "00000000-0000-0000-0000-000000000000",
        }))?;
        Ok(runners["this_device_offers"].clone())
    }

    pub fn stays_quiet_for(&self, period: Duration) -> bool {
        thread::sleep(SETTLING_PAUSE);
        let before = self.count_runner_requests();
        thread::sleep(period);
        self.count_runner_requests() == before
    }
}
