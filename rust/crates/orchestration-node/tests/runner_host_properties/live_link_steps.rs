use std::sync::{LazyLock, Mutex, MutexGuard, PoisonError};
use std::time::Duration;

use orchestration_api::work::RunEvent;
use orchestration_core::device::RunnerLink;
use orchestration_core::identifiers::RunId;
use orchestration_node::live_link_messages::{
    ClientMessage, RunnerMessage, decode_link_message, encode_link_message,
};
use orchestration_p2p::peer_configuration::{PeerConfiguration, RelayChoice};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use orchestration_p2p::peer_link::PeerLink;
use tokio::runtime::{Builder, Runtime};
use tokio::time::{Instant, timeout};

use crate::file_host_fixture::{FileHost, file_host};
use crate::run_view_steps::finish_new_run;
use crate::support::test_device::describe;

pub const REPLY_LIMIT: Duration = Duration::from_secs(20);
pub const QUIET_PERIOD: Duration = Duration::from_secs(3);
const LINK_LIMIT: Duration = Duration::from_secs(30);
const LINK_WORKER_THREADS: usize = 4;
const STRANGER_SECRET: [u8; 32] = [91; 32];
const RUNNER_HUNG_UP: &str = "the runner hung up";
const LINK_STAYED_OPEN: &str = "the runner kept the link open";

#[derive(Debug)]
pub struct LinkSide {
    pub host: &'static FileHost,
    pub runtime: Runtime,
    pub client: PeerEndpoint,
    pub stranger: PeerEndpoint,
    pub shared_run: RunId,
    pub lone_run: RunId,
    lone_run_turn: Mutex<()>,
}

impl LinkSide {
    pub fn take_lone_run_turn(&self) -> MutexGuard<'_, ()> {
        self.lone_run_turn
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
    }
}

static LINK_SIDE: LazyLock<Result<LinkSide, String>> =
    LazyLock::new(open_link_side);

pub fn link_side() -> Result<&'static LinkSide, String> {
    LINK_SIDE.as_ref().map_err(Clone::clone)
}

async fn bind_endpoint(secret_key: [u8; 32]) -> Result<PeerEndpoint, String> {
    let configuration = PeerConfiguration {
        secret_key,
        relay: RelayChoice::Disabled,
    };
    PeerEndpoint::bind(configuration).await.map_err(describe)
}

fn open_link_side() -> Result<LinkSide, String> {
    let host = file_host()?;
    let runtime = Builder::new_multi_thread()
        .worker_threads(LINK_WORKER_THREADS)
        .enable_all()
        .build()
        .map_err(describe)?;
    let client = runtime.block_on(bind_endpoint(host.client_secret))?;
    let stranger = runtime.block_on(bind_endpoint(STRANGER_SECRET))?;
    let shared_run = finish_new_run(host)?;
    let lone_run = finish_new_run(host)?;
    Ok(LinkSide {
        host,
        runtime,
        client,
        stranger,
        shared_run,
        lone_run,
        lone_run_turn: Mutex::new(()),
    })
}

pub async fn open_link(
    endpoint: &PeerEndpoint,
    host: &FileHost,
) -> Result<PeerLink, String> {
    let connecting = endpoint.connect(&host.runner_address);
    let connected = timeout(LINK_LIMIT, connecting).await.map_err(describe)?;
    connected.map_err(describe)
}

pub async fn send_frame(
    link: &mut PeerLink,
    frame: &[u8],
) -> Result<(), String> {
    link.sender.send_frame(frame).await.map_err(describe)
}

pub async fn send_client_message(
    link: &mut PeerLink,
    message: &ClientMessage,
) -> Result<(), String> {
    let frame = encode_link_message(message).map_err(describe)?;
    send_frame(link, &frame).await
}

pub async fn receive_message(
    link: &mut PeerLink,
) -> Result<RunnerMessage, String> {
    let receiving = link.receiver.receive_frame();
    let received = timeout(REPLY_LIMIT, receiving).await.map_err(describe)?;
    let frame = received.map_err(describe)?;
    let frame = frame.ok_or_else(|| RUNNER_HUNG_UP.to_owned())?;
    decode_link_message(&frame).map_err(describe)
}

pub async fn count_frames_until_end(
    link: &mut PeerLink,
) -> Result<usize, String> {
    let deadline = Instant::now() + REPLY_LIMIT;
    let mut frame_count = 0;
    loop {
        let remaining = deadline.saturating_duration_since(Instant::now());
        let receiving = link.receiver.receive_frame();
        let Ok(received) = timeout(remaining, receiving).await else {
            return Err(LINK_STAYED_OPEN.to_owned());
        };
        match received {
            Ok(Some(_frame)) => frame_count += 1,
            Ok(None) | Err(_) => return Ok(frame_count),
        }
    }
}

pub async fn ask(
    endpoint: &PeerEndpoint,
    host: &FileHost,
    message: &ClientMessage,
) -> Result<RunnerMessage, String> {
    let mut link = open_link(endpoint, host).await?;
    send_client_message(&mut link, message).await?;
    receive_message(&mut link).await
}

pub async fn watch(
    side: &LinkSide,
    run_id: RunId,
) -> Result<PeerLink, String> {
    let mut link = open_link(&side.client, side.host).await?;
    send_client_message(&mut link, &ClientMessage::Watch { run_id }).await?;
    let reply = receive_message(&mut link).await?;
    if reply != RunnerMessage::Accepted {
        return Err(format!("the watch was not accepted: {reply:?}"));
    }
    Ok(link)
}

pub async fn close_link(link: PeerLink) -> Result<(), String> {
    let closing = link.sender.close();
    let closed = timeout(LINK_LIMIT, closing).await.map_err(describe)?;
    closed.map_err(describe)
}

pub fn read_chat_texts(message: &RunnerMessage) -> Vec<String> {
    let mut texts = Vec::new();
    let RunnerMessage::Events { events } = message else {
        return texts;
    };
    for event in events {
        if let RunEvent::ChatAppended { message } = event {
            texts.push(message.text.clone());
        }
    }
    texts
}

pub fn has_chat(message: &RunnerMessage, text: &str) -> bool {
    let texts = read_chat_texts(message);
    texts.iter().any(|known| known == text)
}

pub fn is_direct_link_change(message: &RunnerMessage) -> bool {
    let RunnerMessage::Events { events } = message else {
        return false;
    };
    let direct = RunEvent::LinkChanged {
        link: RunnerLink::Direct,
    };
    events.contains(&direct)
}

pub async fn wait_for_direct_link_change(
    link: &mut PeerLink,
) -> Result<(), String> {
    loop {
        let message = receive_message(link).await?;
        if is_direct_link_change(&message) {
            return Ok(());
        }
    }
}

pub async fn wait_for_chat(
    link: &mut PeerLink,
    text: &str,
) -> Result<Vec<RunnerMessage>, String> {
    let mut received = Vec::new();
    loop {
        let message = receive_message(link).await?;
        let is_found = has_chat(&message, text);
        received.push(message);
        if is_found {
            return Ok(received);
        }
    }
}

pub async fn collect_for(
    link: &mut PeerLink,
    period: Duration,
) -> Result<Vec<RunnerMessage>, String> {
    let deadline = Instant::now() + period;
    let mut received = Vec::new();
    loop {
        let remaining = deadline.saturating_duration_since(Instant::now());
        let receiving = link.receiver.receive_frame();
        let Ok(frame) = timeout(remaining, receiving).await else {
            return Ok(received);
        };
        let Some(frame) = frame.map_err(describe)? else {
            return Ok(received);
        };
        received.push(decode_link_message(&frame).map_err(describe)?);
    }
}
