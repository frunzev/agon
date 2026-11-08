use std::fmt;
use std::io::Read;
use std::net::{Ipv4Addr, TcpListener, TcpStream};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, PoisonError};
use std::thread;
use std::time::{Duration, Instant};

use mdns_sd::{ServiceDaemon, ServiceInfo};
use uuid::Uuid;

use crate::support::test_device::describe;
use crate::support::waiting::wait_for;

const APP_SERVER_SERVICE_TYPE: &str = "_agentorch._tcp.local.";
const SERVER_ADDRESS_PROPERTY: &str = "server_address";
const INSTANCE_NAME_PREFIX: &str = "silent-server-";
const HOST_NAME_SUFFIX: &str = ".local.";
const LOOPBACK_TEXT: &str = "127.0.0.1";
const ANY_FREE_PORT: u16 = 0;
const ADDRESS_PREFIX: &str = "http://127.0.0.1:";
const HOLD_LIMIT: Duration = Duration::from_secs(60);
const READ_BUFFER_LENGTH: usize = 1024;
const GOODBYE_LIMIT: Duration = Duration::from_secs(1);
const CLOSING_LIMIT: Duration = Duration::from_secs(70);

#[derive(Clone, Debug)]
pub struct HeldConnection {
    pub held_for: Duration,
    pub received_text: String,
}

type HeldConnections = Arc<Mutex<Vec<HeldConnection>>>;

pub struct SilentServer {
    port: u16,
    opened_count: Arc<AtomicUsize>,
    held_connections: HeldConnections,
    is_stopping: Arc<AtomicBool>,
    daemon: ServiceDaemon,
    service_name: String,
}

#[derive(Debug)]
struct SilentListening {
    opened_count: Arc<AtomicUsize>,
    held_connections: HeldConnections,
    is_stopping: Arc<AtomicBool>,
}

impl fmt::Debug for SilentServer {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("SilentServer")
            .field("port", &self.port)
            .finish_non_exhaustive()
    }
}

fn hold_until_closed(mut connection: TcpStream) -> HeldConnection {
    let opened_at = Instant::now();
    let _limited = connection.set_read_timeout(Some(HOLD_LIMIT));
    let mut buffer = [0_u8; READ_BUFFER_LENGTH];
    let mut received_bytes = Vec::new();
    while let Ok(read_length) = connection.read(&mut buffer) {
        if read_length == 0 {
            break;
        }
        received_bytes.extend_from_slice(&buffer[..read_length]);
    }
    HeldConnection {
        held_for: opened_at.elapsed(),
        received_text: String::from_utf8_lossy(&received_bytes).into_owned(),
    }
}

fn accept_silently(listener: &TcpListener, listening: &SilentListening) {
    for connection in listener.incoming() {
        if listening.is_stopping.load(Ordering::SeqCst) {
            return;
        }
        let Ok(connection) = connection else {
            continue;
        };
        listening.opened_count.fetch_add(1, Ordering::SeqCst);
        let held = Arc::clone(&listening.held_connections);
        thread::spawn(move || {
            let held_connection = hold_until_closed(connection);
            let mut kept = held.lock().unwrap_or_else(PoisonError::into_inner);
            kept.push(held_connection);
        });
    }
}

fn announce(
    address: &str,
    port: u16,
) -> Result<(ServiceDaemon, String), String> {
    let instance_name =
        format!("{INSTANCE_NAME_PREFIX}{}", Uuid::new_v4().simple());
    let host_name = format!("{instance_name}{HOST_NAME_SUFFIX}");
    let properties = [(SERVER_ADDRESS_PROPERTY, address)];
    let service = ServiceInfo::new(
        APP_SERVER_SERVICE_TYPE,
        &instance_name,
        &host_name,
        LOOPBACK_TEXT,
        port,
        &properties[..],
    )
    .map_err(describe)?;
    let service_name = service.get_fullname().to_owned();
    let daemon = ServiceDaemon::new().map_err(describe)?;
    daemon.register(service).map_err(describe)?;
    Ok((daemon, service_name))
}

impl SilentServer {
    pub fn start() -> Result<Self, String> {
        let listener = TcpListener::bind((Ipv4Addr::LOCALHOST, ANY_FREE_PORT))
            .map_err(describe)?;
        let port = listener.local_addr().map_err(describe)?.port();
        let listening = SilentListening {
            opened_count: Arc::default(),
            held_connections: HeldConnections::default(),
            is_stopping: Arc::new(AtomicBool::new(false)),
        };
        let opened_count = Arc::clone(&listening.opened_count);
        let held_connections = Arc::clone(&listening.held_connections);
        let is_stopping = Arc::clone(&listening.is_stopping);
        thread::spawn(move || accept_silently(&listener, &listening));
        let address = format!("{ADDRESS_PREFIX}{port}");
        let (daemon, service_name) = announce(&address, port)?;
        Ok(Self {
            port,
            opened_count,
            held_connections,
            is_stopping,
            daemon,
            service_name,
        })
    }

    pub fn wait_for_closed_connections(
        &self,
    ) -> Result<Vec<HeldConnection>, String> {
        wait_for(CLOSING_LIMIT, "the silent connections to close", || {
            let kept = self
                .held_connections
                .lock()
                .unwrap_or_else(PoisonError::into_inner);
            let opened_count = self.opened_count.load(Ordering::SeqCst);
            Ok((kept.len() == opened_count).then(|| kept.clone()))
        })
    }
}

impl Drop for SilentServer {
    fn drop(&mut self) {
        if let Ok(unregistering) = self.daemon.unregister(&self.service_name) {
            let _goodbye_sent = unregistering.recv_timeout(GOODBYE_LIMIT);
        }
        let _stopping = self.daemon.shutdown();
        self.is_stopping.store(true, Ordering::SeqCst);
        let _woken = TcpStream::connect((Ipv4Addr::LOCALHOST, self.port));
    }
}
