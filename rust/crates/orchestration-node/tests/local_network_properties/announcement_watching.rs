use std::fmt;
use std::time::{Duration, Instant};

use mdns_sd::{Receiver, ResolvedService, ServiceDaemon, ServiceEvent};

use crate::announcing::{APP_SERVER_SERVICE_TYPE, SERVER_ADDRESS_PROPERTY};
use crate::support::test_device::describe;

const NOT_ANNOUNCED: &str = "the wanted server was not announced in time";

pub type AnnouncedText = (String, String);

#[derive(Debug)]
pub struct WatchedAnnouncement {
    pub full_name: String,
    pub host_name: String,
    pub port: u16,
    pub properties: Vec<AnnouncedText>,
}

pub struct AnnouncementBrowser {
    daemon: ServiceDaemon,
    events: Receiver<ServiceEvent>,
}

fn describe_resolved(service: &ResolvedService) -> WatchedAnnouncement {
    let mut properties = Vec::new();
    for property in service.get_properties().iter() {
        let value = property.val_str().to_owned();
        properties.push((property.key().to_owned(), value));
    }
    WatchedAnnouncement {
        full_name: service.get_fullname().to_owned(),
        host_name: service.get_hostname().to_owned(),
        port: service.get_port(),
        properties,
    }
}

impl AnnouncementBrowser {
    pub fn start() -> Result<Self, String> {
        let daemon = ServiceDaemon::new().map_err(describe)?;
        let events =
            daemon.browse(APP_SERVER_SERVICE_TYPE).map_err(describe)?;
        Ok(Self { daemon, events })
    }

    pub fn wait_for_announcement(
        &self,
        wanted_address: &str,
        limit: Duration,
    ) -> Result<WatchedAnnouncement, String> {
        let deadline = Instant::now() + limit;
        loop {
            let remaining = deadline.saturating_duration_since(Instant::now());
            let event = self
                .events
                .recv_timeout(remaining)
                .map_err(|_| NOT_ANNOUNCED.to_owned())?;
            let ServiceEvent::ServiceResolved(service) = event else {
                continue;
            };
            let announced =
                service.get_property_val_str(SERVER_ADDRESS_PROPERTY);
            if announced == Some(wanted_address) {
                return Ok(describe_resolved(&service));
            }
        }
    }
}

impl fmt::Debug for AnnouncementBrowser {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("AnnouncementBrowser")
            .finish_non_exhaustive()
    }
}

impl Drop for AnnouncementBrowser {
    fn drop(&mut self) {
        let _stopping = self.daemon.shutdown();
    }
}
