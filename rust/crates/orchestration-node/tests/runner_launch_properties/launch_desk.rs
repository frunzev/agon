use std::time::Duration;

use orchestration_core::identifiers::RunId;
use orchestration_core::peer_address::PeerAddress;
use orchestration_node::live_link_messages::{
    ClientMessage, RunnerMessage, decode_link_message, encode_link_message,
};
use orchestration_p2p::peer_configuration::{PeerConfiguration, RelayChoice};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use orchestration_security::peer_addresses::generate_peer_secret;
use serde_json::{Value, json};
use tokio::time::timeout;
use uuid::Uuid;

use crate::engine_desk::{CLAIM_PATH, HEARTBEAT_PATH, RUNNER_LIMIT};
use crate::support::runner_access::test_runtime;
use crate::support::test_device::{TestDevice, describe};
use crate::support::test_server::TestServer;
use crate::support::waiting::wait_for;

pub const LAUNCH_CASES: u32 = 1;
pub const QUIET_PERIOD: Duration = Duration::from_secs(2);
pub const SILENCE_LIMIT: Duration = Duration::from_secs(5);
const ANSWER_LIMIT: Duration = Duration::from_secs(20);
const RUNNER_HUNG_UP: &str = "the runner hung up";

#[derive(Debug)]
pub struct LaunchDesk {
    pub server: TestServer,
    pub device: TestDevice,
}

pub fn local_settings(labels: &[String], slot_capacity: u32) -> Value {
    json!({
        "labels": labels,
        "slot_capacity": slot_capacity,
        "sandbox": { "kind": "local_process" },
    })
}

pub fn open_launch_desk(
    settings: &Value,
    role: &str,
) -> Result<LaunchDesk, String> {
    let server = TestServer::start()?;
    let device = TestDevice::start_runner(settings)?;
    device.create_account_with_role(&server, "acme", role)?;
    Ok(LaunchDesk { server, device })
}

pub fn count_runner_requests(server: &TestServer) -> usize {
    let mut runner_request_count = 0;
    for request in server.recorded_requests() {
        if request.path == HEARTBEAT_PATH || request.path == CLAIM_PATH {
            runner_request_count += 1;
        }
    }
    runner_request_count
}

pub fn read_heartbeats(server: &TestServer) -> Vec<Value> {
    let mut heartbeats = Vec::new();
    for request in server.recorded_requests() {
        if request.path != HEARTBEAT_PATH {
            continue;
        }
        if let Ok(body) = serde_json::from_slice(&request.body) {
            heartbeats.push(body);
        }
    }
    heartbeats
}

pub fn wait_for_first_heartbeat(server: &TestServer) -> Result<Value, String> {
    wait_for(RUNNER_LIMIT, "the first heartbeat", || {
        Ok(read_heartbeats(server).first().cloned())
    })
}

pub fn read_own_address(devices: &Value) -> Result<PeerAddress, String> {
    let listed = devices.as_array().cloned().unwrap_or_default();
    let own = listed
        .into_iter()
        .find(|device| device["is_this_device"] == true)
        .ok_or("this device is not listed")?;
    let address = own["device"]["peer_address"]["address"].clone();
    serde_json::from_value(address).map_err(describe)
}

pub fn wait_for_own_address(
    device: &TestDevice,
) -> Result<PeerAddress, String> {
    wait_for(RUNNER_LIMIT, "the published peer address", || {
        let devices = device.run(&json!({ "command": "list_devices" }))?;
        Ok(read_own_address(&devices).ok())
    })
}

pub fn unknown_run_refusal(number: u128) -> RunnerMessage {
    RunnerMessage::Refused {
        reason: format!(
            "claimed run {} was not found",
            Uuid::from_u128(number)
        ),
    }
}

async fn ask_over_a_fresh_endpoint(
    address: &PeerAddress,
    number: u128,
) -> Result<RunnerMessage, String> {
    let peer_secret = generate_peer_secret().map_err(describe)?;
    let configuration = PeerConfiguration {
        secret_key: *peer_secret,
        relay: RelayChoice::Disabled,
    };
    let endpoint =
        PeerEndpoint::bind(configuration).await.map_err(describe)?;
    let mut link = endpoint.connect(address).await.map_err(describe)?;
    let watch = ClientMessage::Watch {
        run_id: RunId(Uuid::from_u128(number)),
    };
    let frame = encode_link_message(&watch).map_err(describe)?;
    link.sender.send_frame(&frame).await.map_err(describe)?;
    let reply = link.receiver.receive_frame().await.map_err(describe)?;
    let reply = reply.ok_or_else(|| RUNNER_HUNG_UP.to_owned())?;
    decode_link_message(&reply).map_err(describe)
}

pub fn ask_live_host(
    address: &PeerAddress,
    number: u128,
    limit: Duration,
) -> Result<RunnerMessage, String> {
    let runtime = test_runtime()?;
    let asking = ask_over_a_fresh_endpoint(address, number);
    let answered = runtime.block_on(async { timeout(limit, asking).await });
    answered.map_err(describe)?
}

pub fn ask_live_host_patiently(
    address: &PeerAddress,
    number: u128,
) -> Result<RunnerMessage, String> {
    ask_live_host(address, number, ANSWER_LIMIT)
}
