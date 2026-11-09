use std::sync::{Arc, Mutex, MutexGuard, PoisonError};

use orchestration_node::live_link_messages::{
    ClientMessage, RunnerMessage, decode_link_message, encode_link_message,
};
use orchestration_p2p::peer_address::{
    PeerAddress, add_same_machine_addresses,
};
use orchestration_p2p::peer_configuration::{PeerConfiguration, RelayChoice};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use orchestration_p2p::peer_link::{
    PeerLink, PeerLinkReceiver, PeerLinkSender,
};
use orchestration_security::peer_addresses::generate_peer_secret;
use tokio::runtime::Runtime;
use tokio::sync::Mutex as AsyncMutex;

use crate::support::runner_access::test_runtime;
use crate::support::test_device::describe;

type ReceivedMessages = Arc<Mutex<Vec<ClientMessage>>>;
type OpenLinks = Arc<AsyncMutex<Vec<PeerLinkSender>>>;

#[derive(Clone, Debug)]
pub enum Opening {
    Accept,
    AcceptThenSend(Vec<RunnerMessage>),
    AcceptThenClose,
}

#[derive(Debug)]
pub struct ScriptedRunner {
    pub address: PeerAddress,
    received: ReceivedMessages,
    open_links: OpenLinks,
    runtime: Runtime,
}

impl ScriptedRunner {
    pub fn start(opening: Opening) -> Result<Self, String> {
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
        let open_links = OpenLinks::default();
        runtime.spawn(accept_every_link(
            endpoint,
            Arc::clone(&received),
            Arc::clone(&open_links),
            opening,
        ));
        Ok(Self {
            address,
            received,
            open_links,
            runtime,
        })
    }

    pub fn received(&self) -> Vec<ClientMessage> {
        lock_received(&self.received).clone()
    }

    pub fn count_watches(&self) -> usize {
        let mut watch_count = 0;
        for message in self.received() {
            if matches!(message, ClientMessage::Watch { .. }) {
                watch_count += 1;
            }
        }
        watch_count
    }

    pub fn send_to_every_link(&self, message: &RunnerMessage) {
        let Ok(frame) = encode_link_message(message) else {
            return;
        };
        self.send_frame_to_every_link(&frame);
    }

    pub fn send_frame_to_every_link(&self, frame: &[u8]) {
        let open_links = Arc::clone(&self.open_links);
        let sending = async move {
            let mut senders = open_links.lock().await;
            for sender in senders.iter_mut() {
                let _sent = sender.send_frame(frame).await;
            }
        };
        self.runtime.block_on(sending);
    }

    pub fn close_every_link(&self) {
        let open_links = Arc::clone(&self.open_links);
        let closing = async move {
            let senders = std::mem::take(&mut *open_links.lock().await);
            for sender in senders {
                let _closed = sender.close().await;
            }
        };
        self.runtime.block_on(closing);
    }
}

async fn accept_every_link(
    endpoint: PeerEndpoint,
    received: ReceivedMessages,
    open_links: OpenLinks,
    opening: Opening,
) {
    while let Ok(link) = endpoint.accept().await {
        open_link(link, &received, &open_links, &opening).await;
    }
}

async fn open_link(
    mut link: PeerLink,
    received: &ReceivedMessages,
    open_links: &OpenLinks,
    opening: &Opening,
) {
    let Ok(Some(frame)) = link.receiver.receive_frame().await else {
        return;
    };
    if let Ok(message) = decode_link_message::<ClientMessage>(&frame) {
        lock_received(received).push(message);
    }
    let Ok(accepted) = encode_link_message(&RunnerMessage::Accepted) else {
        return;
    };
    if link.sender.send_frame(&accepted).await.is_err() {
        return;
    }
    match opening {
        Opening::Accept => {}
        Opening::AcceptThenSend(messages) => {
            for message in messages {
                let Ok(frame) = encode_link_message(message) else {
                    return;
                };
                let _sent = link.sender.send_frame(&frame).await;
            }
        }
        Opening::AcceptThenClose => {
            let _closed = link.sender.close().await;
            return;
        }
    }
    let PeerLink { sender, receiver } = link;
    tokio::spawn(record_messages(receiver, Arc::clone(received)));
    open_links.lock().await.push(sender);
}

async fn record_messages(
    mut link_receiver: PeerLinkReceiver,
    received: ReceivedMessages,
) {
    while let Ok(Some(frame)) = link_receiver.receive_frame().await {
        if let Ok(message) = decode_link_message::<ClientMessage>(&frame) {
            lock_received(&received).push(message);
        }
    }
}

fn lock_received(
    received: &ReceivedMessages,
) -> MutexGuard<'_, Vec<ClientMessage>> {
    received.lock().unwrap_or_else(PoisonError::into_inner)
}
