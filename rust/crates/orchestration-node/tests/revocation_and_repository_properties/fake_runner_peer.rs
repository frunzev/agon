use std::sync::{Arc, Mutex, OnceLock, PoisonError};
use std::time::Duration;

use chrono::Utc;
use orchestration_api::accounts::PublishPeerAddressRequest;
use orchestration_api::work::HeartbeatRequest;
use orchestration_core::peer_address::PeerAddress;
use orchestration_node::live_link_messages::{
    ClientMessage, FileRequest, RunnerMessage, decode_link_message,
    encode_link_message,
};
use orchestration_node::node_error::NodeError;
use orchestration_node::server_address::ServerAddress;
use orchestration_node::server_client::{PeerDialer, ServerClient};
use orchestration_p2p::peer_address::add_same_machine_addresses;
use orchestration_p2p::peer_configuration::{PeerConfiguration, RelayChoice};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use orchestration_p2p::peer_error::PeerError;
use orchestration_p2p::peer_link::PeerLink;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::peer_addresses::sign_peer_address;
use serde_json::{Value, json};
use tokio::runtime::Runtime;
use tokio::time::sleep;

use crate::fake_peer_answers::{
    CONFUSED_ADDRESS, HONEST_ADDRESS, answer_file_request,
};
use crate::support::command_builders::{PreparedWorkspace, prepare_workspace};
use crate::support::runner_access::{sample_heartbeat, test_runtime};
use crate::support::test_device::{TestDevice, describe, read_text};

type AskedRequests = Arc<Mutex<Vec<FileRequest>>>;

const FAKE_PEER_SECRET: [u8; 32] = [57; 32];
const RUNNER_NAME: &str = "fake-runner";
const RUNNER_ROLE: &str = "runner";
const HEARTBEAT_PAUSE: Duration = Duration::from_secs(10);
const CLOSED_BEFORE_ASKING: &str = "the client closed the link";
const NOT_A_FILE_QUESTION: &str = "the client asked no file question";
const FAILED_ANSWER_START: &str = "the fake runner peer could not answer: ";
const FAILED_HEARTBEAT_START: &str = "the fake runner heartbeat failed: ";

static SHARED_PEER: OnceLock<Result<FakeRunnerPeer, String>> = OnceLock::new();

#[derive(Debug)]
pub struct FakeRunnerPeer {
    pub prepared: PreparedWorkspace,
    pub device_id: String,
    asked_requests: AskedRequests,
    _runtime: Runtime,
}

#[derive(Debug)]
pub struct CountedReply {
    pub reply: Result<Value, String>,
    pub new_requests: usize,
}

#[derive(Debug)]
struct PairedRunner {
    device_id: String,
    identity: DeviceIdentity,
}

pub fn shared_fake_runner_peer() -> Result<&'static FakeRunnerPeer, String> {
    let peer = SHARED_PEER.get_or_init(start_fake_runner_peer);
    peer.as_ref().map_err(Clone::clone)
}

impl FakeRunnerPeer {
    pub fn ask_counting(&self, command: &Value, branch: &str) -> CountedReply {
        let requests_before = self.count_requests_on_branch(branch);
        let reply = self.prepared.device.run(command);
        let requests_after = self.count_requests_on_branch(branch);
        CountedReply {
            reply,
            new_requests: requests_after - requests_before,
        }
    }

    fn count_requests_on_branch(&self, branch: &str) -> usize {
        let asked = self
            .asked_requests
            .lock()
            .unwrap_or_else(PoisonError::into_inner);
        let mut count = 0;
        for request in asked.iter() {
            let asked_branch = match request {
                FileRequest::ListBranches { .. } => continue,
                FileRequest::ListFolder { branch, .. }
                | FileRequest::ReadFile { branch, .. } => branch,
            };
            if asked_branch == branch {
                count += 1;
            }
        }
        count
    }
}

fn start_fake_runner_peer() -> Result<FakeRunnerPeer, String> {
    let prepared = prepare_workspace()?;
    add_confused_repository(&prepared)?;
    let paired = pair_a_runner(&prepared)?;
    let runtime = test_runtime()?;
    let endpoint = bind_fake_endpoint(&runtime)?;
    let address = add_same_machine_addresses(endpoint.peer_address());
    let server = connect_to_server(&prepared)?;
    runtime
        .block_on(announce_runner(&server, &paired.identity, &address))
        .map_err(describe)?;

    let asked_requests = AskedRequests::default();
    runtime.spawn(keep_heartbeating(server, paired.identity));
    runtime.spawn(answer_every_link(endpoint, Arc::clone(&asked_requests)));
    Ok(FakeRunnerPeer {
        prepared,
        device_id: paired.device_id,
        asked_requests,
        _runtime: runtime,
    })
}

fn bind_fake_endpoint(runtime: &Runtime) -> Result<PeerEndpoint, String> {
    let configuration = PeerConfiguration {
        secret_key: FAKE_PEER_SECRET,
        relay: RelayChoice::Disabled,
    };
    runtime
        .block_on(PeerEndpoint::bind(configuration))
        .map_err(describe)
}

fn connect_to_server(
    prepared: &PreparedWorkspace,
) -> Result<ServerClient, String> {
    let server_address =
        ServerAddress::parse(&prepared.server.address).map_err(describe)?;
    let dialer = Arc::new(PeerDialer::new(RelayChoice::Disabled));
    ServerClient::connect(&server_address, &dialer).map_err(describe)
}

fn add_confused_repository(
    prepared: &PreparedWorkspace,
) -> Result<(), String> {
    prepared.device.run(&json!({
        "command": "create_repository",
        "project_id": prepared.project_id,
        "repository": {
            "address": CONFUSED_ADDRESS,
            "default_branch": "main",
            "agent_access": "read_only",
        },
    }))?;
    Ok(())
}

fn pair_a_runner(
    prepared: &PreparedWorkspace,
) -> Result<PairedRunner, String> {
    let joining = TestDevice::start()?;
    let session = prepared
        .device
        .run(&json!({ "command": "start_pairing" }))?;
    joining.run(&json!({
        "command": "join_with_code",
        "server_address": prepared.server.address,
        "code": read_text(&session, "/display_code")?,
        "device_name": RUNNER_NAME,
        "role": RUNNER_ROLE,
    }))?;
    prepared.device.run(&json!({
        "command": "approve_pairing",
        "code": session["code"],
        "workspace_ids": [prepared.workspace_id],
    }))?;
    let joined = joining.run(&json!({ "command": "join_status" }))?;
    let device_id = read_text(&joined, "/device/id")?;
    let identity = joining.load_identity()?;
    drop(joining.stop());
    Ok(PairedRunner {
        device_id,
        identity,
    })
}

fn build_heartbeat() -> HeartbeatRequest {
    HeartbeatRequest {
        cached_repositories: vec![
            HONEST_ADDRESS.to_owned(),
            CONFUSED_ADDRESS.to_owned(),
        ],
        ..sample_heartbeat()
    }
}

async fn announce_runner(
    server: &ServerClient,
    identity: &DeviceIdentity,
    address: &PeerAddress,
) -> Result<(), NodeError> {
    let request = PublishPeerAddressRequest {
        address: sign_peer_address(identity, address, Utc::now()),
    };
    server
        .signed(identity)
        .publish_peer_address(&request)
        .await?;
    server
        .signed(identity)
        .send_heartbeat(&build_heartbeat())
        .await?;
    Ok(())
}

async fn keep_heartbeating(server: ServerClient, identity: DeviceIdentity) {
    let heartbeat = build_heartbeat();
    loop {
        sleep(HEARTBEAT_PAUSE).await;
        let sent = server.signed(&identity).send_heartbeat(&heartbeat).await;
        if let Err(problem) = sent {
            eprintln!("{FAILED_HEARTBEAT_START}{problem}");
        }
    }
}

async fn answer_every_link(endpoint: PeerEndpoint, asked: AskedRequests) {
    loop {
        match endpoint.accept().await {
            Ok(link) => {
                tokio::spawn(answer_one_link(link, Arc::clone(&asked)));
            }
            Err(PeerError::EndpointClosed) => return,
            Err(problem) => eprintln!("{FAILED_ANSWER_START}{problem}"),
        }
    }
}

async fn answer_one_link(link: PeerLink, asked: AskedRequests) {
    if let Err(problem) = exchange_one_answer(link, &asked).await {
        eprintln!("{FAILED_ANSWER_START}{problem}");
    }
}

async fn exchange_one_answer(
    link: PeerLink,
    asked: &AskedRequests,
) -> Result<(), String> {
    let PeerLink {
        mut sender,
        mut receiver,
    } = link;
    let frame = receiver.receive_frame().await.map_err(describe)?;
    let frame = frame.ok_or(CLOSED_BEFORE_ASKING)?;
    let message: ClientMessage =
        decode_link_message(&frame).map_err(describe)?;
    let ClientMessage::Browse { request } = message else {
        return Err(NOT_A_FILE_QUESTION.to_owned());
    };
    let answer = answer_file_request(&request);
    asked
        .lock()
        .unwrap_or_else(PoisonError::into_inner)
        .push(request);
    let reply = RunnerMessage::Answered { answer };
    let reply_frame = encode_link_message(&reply).map_err(describe)?;
    sender.send_frame(&reply_frame).await.map_err(describe)?;
    sender.close().await.map_err(describe)
}
