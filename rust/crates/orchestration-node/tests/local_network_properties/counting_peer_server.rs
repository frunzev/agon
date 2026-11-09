use std::sync::{Arc, Mutex, PoisonError};

use orchestration_core::peer_address::PeerAddress;
use orchestration_node::server_address::ServerAddress;
use orchestration_p2p::peer_configuration::{PeerConfiguration, RelayChoice};
use orchestration_p2p::peer_connection::{PeerConnection, PeerStream};
use orchestration_p2p::peer_error::PeerError;
use orchestration_p2p::service_endpoint::{
    APP_SERVER_PROTOCOL_NAME, ServiceEndpoint,
};
use orchestration_security::peer_addresses::generate_peer_secret;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::runtime::Runtime;

use crate::support::runner_access::test_runtime;
use crate::support::test_device::describe;

const READ_BUFFER_LENGTH: usize = 1024;
const HEAD_END: &str = "\r\n\r\n";
const CONTENT_LENGTH_PREFIX: &str = "content-length:";
const REFUSAL_ANSWER: &[u8] =
    b"HTTP/1.1 404 Not Found\r\ncontent-length: 0\r\n\r\n";
const CODE_GROUP_SEPARATOR: &str = "-";

type ReceivedConnections = Arc<Mutex<Vec<Vec<u8>>>>;

#[derive(Debug)]
pub struct CountingPeerServer {
    runtime: Runtime,
    endpoint: Arc<ServiceEndpoint>,
    received_connections: ReceivedConnections,
}

impl CountingPeerServer {
    pub fn start() -> Result<Self, String> {
        let runtime = test_runtime()?;
        let secret_key = generate_peer_secret().map_err(describe)?;
        let configuration = PeerConfiguration {
            secret_key: *secret_key,
            relay: RelayChoice::Disabled,
        };
        let protocols = vec![APP_SERVER_PROTOCOL_NAME.to_vec()];
        let binding = ServiceEndpoint::bind(configuration, protocols);
        let endpoint = runtime.block_on(binding).map_err(describe)?;
        let endpoint = Arc::new(endpoint);
        let received_connections = ReceivedConnections::default();
        let accepting = accept_and_refuse(
            Arc::clone(&endpoint),
            Arc::clone(&received_connections),
        );
        runtime.spawn(accepting);
        Ok(Self {
            runtime,
            endpoint,
            received_connections,
        })
    }

    pub fn peer_address(&self) -> PeerAddress {
        self.endpoint.peer_address()
    }

    pub fn announced_address(&self) -> String {
        let address = ServerAddress::Peer(self.peer_address());
        address.without_direct_addresses().to_string()
    }

    pub fn ipv4_port(&self) -> Result<u16, String> {
        self.endpoint.bound_ipv4_port().map_err(describe)
    }

    pub fn count_connections(&self) -> usize {
        let received = self
            .received_connections
            .lock()
            .unwrap_or_else(PoisonError::into_inner);
        received.len()
    }

    pub fn count_connections_with_code(&self, code: &str) -> usize {
        let wire_code = code.replace(CODE_GROUP_SEPARATOR, "");
        let received = self
            .received_connections
            .lock()
            .unwrap_or_else(PoisonError::into_inner);
        let mut count = 0;
        for received_bytes in received.iter() {
            let received_text = String::from_utf8_lossy(received_bytes);
            if received_text.contains(&wire_code) {
                count += 1;
            }
        }
        count
    }
}

impl Drop for CountingPeerServer {
    fn drop(&mut self) {
        self.runtime.block_on(self.endpoint.close());
    }
}

async fn accept_and_refuse(
    endpoint: Arc<ServiceEndpoint>,
    received_connections: ReceivedConnections,
) {
    loop {
        match endpoint.accept().await {
            Ok(connection) => {
                let received = Arc::clone(&received_connections);
                tokio::spawn(record_connection(connection, received));
            }
            Err(PeerError::EndpointClosed) => return,
            Err(_) => {}
        }
    }
}

fn open_connection_record(
    received_connections: &ReceivedConnections,
) -> usize {
    let mut received = received_connections
        .lock()
        .unwrap_or_else(PoisonError::into_inner);
    received.push(Vec::new());
    received.len() - 1
}

fn keep_received_bytes(
    received_connections: &ReceivedConnections,
    connection_number: usize,
    received_bytes: &[u8],
) {
    let mut received = received_connections
        .lock()
        .unwrap_or_else(PoisonError::into_inner);
    if let Some(connection_bytes) = received.get_mut(connection_number) {
        connection_bytes.extend_from_slice(received_bytes);
    }
}

async fn record_connection(
    connection: PeerConnection,
    received_connections: ReceivedConnections,
) {
    let connection_number = open_connection_record(&received_connections);
    while let Ok(stream) = connection.accept_stream().await {
        refuse_request(stream, &received_connections, connection_number).await;
    }
}

async fn refuse_request(
    mut stream: PeerStream,
    received_connections: &ReceivedConnections,
    connection_number: usize,
) {
    let mut request_bytes = Vec::new();
    let mut buffer = [0_u8; READ_BUFFER_LENGTH];
    while !is_request_complete(&request_bytes) {
        let Ok(read_length) = stream.read(&mut buffer).await else {
            return;
        };
        if read_length == 0 {
            return;
        }
        let received_bytes = &buffer[..read_length];
        request_bytes.extend_from_slice(received_bytes);
        keep_received_bytes(
            received_connections,
            connection_number,
            received_bytes,
        );
    }
    let _refused = stream.write_all(REFUSAL_ANSWER).await;
    let _finished = stream.shutdown().await;
}

fn is_request_complete(request_bytes: &[u8]) -> bool {
    let request_text = String::from_utf8_lossy(request_bytes);
    let Some(head_length) = request_text.find(HEAD_END) else {
        return false;
    };
    let body_length = read_content_length(&request_text[..head_length]);
    request_bytes.len() >= head_length + HEAD_END.len() + body_length
}

fn read_content_length(request_head: &str) -> usize {
    for header_line in request_head.lines() {
        let lowered_line = header_line.to_ascii_lowercase();
        if let Some(length_text) =
            lowered_line.strip_prefix(CONTENT_LENGTH_PREFIX)
        {
            return length_text.trim().parse().unwrap_or_default();
        }
    }
    0
}
