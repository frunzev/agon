use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

use orchestration_node::live_link_messages::{
    ClientMessage, RunnerMessage, decode_link_message, encode_link_message,
};
use orchestration_p2p::peer_address::{
    PeerAddress, add_same_machine_addresses,
};
use orchestration_p2p::peer_configuration::{PeerConfiguration, RelayChoice};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use orchestration_p2p::peer_link::PeerLink;
use orchestration_security::peer_addresses::generate_peer_secret;
use tokio::runtime::Runtime;

use crate::support::runner_access::test_runtime;
use crate::support::test_device::describe;

type ReceivedMessages = Arc<Mutex<Vec<ClientMessage>>>;

#[derive(Clone, Debug)]
pub enum RunnerAnswer {
    Reply(RunnerMessage),
    CloseTheLink,
    StaySilent,
}

#[derive(Debug)]
pub struct FakeRunner {
    pub address: PeerAddress,
    received: ReceivedMessages,
    _answering_runtime: Runtime,
}

impl FakeRunner {
    pub fn start(answer: RunnerAnswer) -> Result<Self, String> {
        let runtime = test_runtime()?;
        let peer_secret = generate_peer_secret().map_err(describe)?;
        let configuration = PeerConfiguration {
            secret_key: *peer_secret,
            relay: RelayChoice::Disabled,
        };
        let binding = PeerEndpoint::bind(configuration);
        let endpoint = runtime.block_on(binding).map_err(describe)?;
        let address = add_same_machine_addresses(endpoint.peer_address());
        let received = ReceivedMessages::default();
        runtime.spawn(answer_every_link(
            endpoint,
            Arc::clone(&received),
            answer,
        ));
        Ok(Self {
            address,
            received,
            _answering_runtime: runtime,
        })
    }

    pub fn received(&self) -> Vec<ClientMessage> {
        lock_received(&self.received).clone()
    }
}

async fn answer_every_link(
    endpoint: PeerEndpoint,
    received: ReceivedMessages,
    answer: RunnerAnswer,
) {
    let mut held_links = Vec::new();
    while let Ok(link) = endpoint.accept().await {
        if let Some(kept_link) = answer_link(link, &received, &answer).await {
            held_links.push(kept_link);
        }
    }
}

async fn answer_link(
    mut link: PeerLink,
    received: &ReceivedMessages,
    answer: &RunnerAnswer,
) -> Option<PeerLink> {
    let Ok(Some(frame)) = link.receiver.receive_frame().await else {
        return None;
    };
    if let Ok(message) = decode_link_message::<ClientMessage>(&frame) {
        lock_received(received).push(message);
    }
    match answer {
        RunnerAnswer::Reply(message) => {
            let reply = encode_link_message(message).ok()?;
            link.sender.send_frame(&reply).await.ok()?;
            Some(link)
        }
        RunnerAnswer::CloseTheLink => {
            let _closed = link.sender.close().await;
            None
        }
        RunnerAnswer::StaySilent => Some(link),
    }
}

fn lock_received(
    received: &ReceivedMessages,
) -> MutexGuard<'_, Vec<ClientMessage>> {
    received.lock().unwrap_or_else(PoisonError::into_inner)
}
