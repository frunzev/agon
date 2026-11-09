use std::fmt;
use std::time::Duration;

use mdns_sd::{ServiceDaemon, ServiceInfo};
use uuid::Uuid;

use crate::support::test_device::describe;

pub const APP_SERVER_SERVICE_TYPE: &str = "_agentorch._tcp.local.";
pub const SERVER_ADDRESS_PROPERTY: &str = "server_address";
const INSTANCE_NAME_PREFIX: &str = "local-network-property-";
const HOST_NAME_SUFFIX: &str = ".local.";
const LOOPBACK_TEXT: &str = "127.0.0.1";
const GOODBYE_LIMIT: Duration = Duration::from_secs(1);

pub type AnnouncedProperty<'text> = (&'text str, &'text str);

pub struct Announcer {
    daemon: ServiceDaemon,
    service_names: Vec<String>,
}

impl Announcer {
    pub fn start() -> Result<Self, String> {
        let daemon = ServiceDaemon::new().map_err(describe)?;
        Ok(Self {
            daemon,
            service_names: Vec::new(),
        })
    }

    pub fn announce(
        &mut self,
        properties: &[AnnouncedProperty<'_>],
        port: u16,
    ) -> Result<(), String> {
        let instance_name =
            format!("{INSTANCE_NAME_PREFIX}{}", Uuid::new_v4().simple());
        let host_name = format!("{instance_name}{HOST_NAME_SUFFIX}");
        let service = ServiceInfo::new(
            APP_SERVER_SERVICE_TYPE,
            &instance_name,
            &host_name,
            LOOPBACK_TEXT,
            port,
            properties,
        )
        .map_err(describe)?;
        self.service_names.push(service.get_fullname().to_owned());
        self.daemon.register(service).map_err(describe)
    }

    pub fn announce_server_address(
        &mut self,
        announced_address: &str,
        port: u16,
    ) -> Result<(), String> {
        let properties = [(SERVER_ADDRESS_PROPERTY, announced_address)];
        self.announce(&properties, port)
    }
}

impl fmt::Debug for Announcer {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("Announcer")
            .field("service_names", &self.service_names)
            .finish_non_exhaustive()
    }
}

impl Drop for Announcer {
    fn drop(&mut self) {
        for service_name in &self.service_names {
            if let Ok(unregistering) = self.daemon.unregister(service_name) {
                let _goodbye_sent = unregistering.recv_timeout(GOODBYE_LIMIT);
            }
        }
        let _stopping = self.daemon.shutdown();
    }
}
