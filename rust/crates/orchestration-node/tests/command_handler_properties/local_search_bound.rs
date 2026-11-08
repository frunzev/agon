use std::collections::BTreeSet;
use std::fmt;
use std::sync::mpsc::{self, RecvTimeoutError};
use std::thread;
use std::time::{Duration, Instant};

use mdns_sd::{Receiver, ResolvedService, ServiceDaemon, ServiceEvent};
use serde_json::Value;

use crate::support::pairing_steps::join_on_local_network;
use crate::support::test_device::{TestDevice, describe};

const APP_SERVER_SERVICE_TYPE: &str = "_agentorch._tcp.local.";
const SERVER_ADDRESS_PROPERTY: &str = "server_address";
const QUIET_PERIOD: Duration = Duration::from_secs(5);
const ATTEMPT_ALLOWANCE: Duration = Duration::from_secs(45);
const ANSWER_SLACK: Duration = Duration::from_secs(30);
const ANSWER_CHECK_PAUSE: Duration = Duration::from_millis(200);
const SILENT_JOIN: &str = "the join stopped without answering";

pub type LocalJoin = (TestDevice, Result<Value, String>);

struct AnnouncementCounter {
    daemon: ServiceDaemon,
    events: Receiver<ServiceEvent>,
    announced: BTreeSet<String>,
}

impl AnnouncementCounter {
    fn start() -> Result<Self, String> {
        let daemon = ServiceDaemon::new().map_err(describe)?;
        let events =
            daemon.browse(APP_SERVER_SERVICE_TYPE).map_err(describe)?;
        Ok(Self {
            daemon,
            events,
            announced: BTreeSet::new(),
        })
    }

    fn count_new_announcements(&mut self) -> usize {
        while let Ok(event) = self.events.try_recv() {
            let ServiceEvent::ServiceResolved(service) = event else {
                continue;
            };
            if let Some(announcement) = describe_announcement(&service) {
                self.announced.insert(announcement);
            }
        }
        self.announced.len()
    }
}

impl fmt::Debug for AnnouncementCounter {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("AnnouncementCounter")
            .field("announced", &self.announced)
            .finish_non_exhaustive()
    }
}

impl Drop for AnnouncementCounter {
    fn drop(&mut self) {
        let _stopping = self.daemon.shutdown();
    }
}

fn describe_announcement(service: &ResolvedService) -> Option<String> {
    let announced_address =
        service.get_property_val_str(SERVER_ADDRESS_PROPERTY)?;
    let mut local_addresses = Vec::new();
    for local_address in service.get_addresses_v4() {
        local_addresses.push(local_address.to_string());
    }
    local_addresses.sort();
    let port = service.get_port();
    Some(format!("{announced_address} {local_addresses:?} {port}"))
}

fn allow_search_time(announced_count: usize) -> Duration {
    let attempt_count = u32::try_from(announced_count).unwrap_or(u32::MAX);
    let attempts_time = ATTEMPT_ALLOWANCE.saturating_mul(attempt_count);
    QUIET_PERIOD + ANSWER_SLACK + attempts_time
}

pub fn join_locally_within_search_bound(
    joining: TestDevice,
    code: String,
) -> Result<LocalJoin, String> {
    let mut counter = AnnouncementCounter::start()?;
    let started = Instant::now();
    let (answer_sender, answer_receiver) = mpsc::channel();
    thread::spawn(move || {
        let joined = join_on_local_network(&joining, &code);
        let _unheard_answer = answer_sender.send((joining, joined));
    });

    loop {
        let announced_count = counter.count_new_announcements();
        match answer_receiver.recv_timeout(ANSWER_CHECK_PAUSE) {
            Ok(local_join) => return Ok(local_join),
            Err(RecvTimeoutError::Disconnected) => {
                return Err(SILENT_JOIN.to_owned());
            }
            Err(RecvTimeoutError::Timeout) => {}
        }

        let allowed_time = allow_search_time(announced_count);
        if started.elapsed() > allowed_time {
            return Err(format!(
                "the search outlasted {allowed_time:?} with \
                 {announced_count} announced servers"
            ));
        }
    }
}
