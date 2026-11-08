use std::fs;
use std::future::IntoFuture;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::time::Duration;

use chrono::{DateTime, TimeDelta, Utc};
use orchestration_server::{Clock, Server, ServerSettings, build_router};
use serde_json::{Value, json};
use tempfile::TempDir;
use tokio::net::TcpListener;
use tokio::runtime::Runtime;

use crate::support::test_device::describe;

const LOOPBACK_ADDRESS: &str = "127.0.0.1:0";
const ADDRESS_SCHEME: &str = "http://";
const LONG_POLL_TIMEOUT: Duration = Duration::from_millis(50);
const SETUP_CODE_FILE_NAME: &str = "setup-code";

#[derive(Debug, Default)]
struct SkippingClock {
    skipped_time: Mutex<TimeDelta>,
}

#[derive(Debug)]
pub struct SkippingClockServer {
    pub address: String,
    clock: Arc<SkippingClock>,
    _serving_runtime: Runtime,
    data_directory: TempDir,
}

impl SkippingClock {
    fn set_skipped_time(&self, skipped_time: TimeDelta) {
        *self.lock_skipped_time() = skipped_time;
    }

    fn lock_skipped_time(&self) -> MutexGuard<'_, TimeDelta> {
        self.skipped_time
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
    }
}

impl Clock for SkippingClock {
    fn now(&self) -> DateTime<Utc> {
        let skipped_time = *self.lock_skipped_time();
        Utc::now() + skipped_time
    }
}

impl SkippingClockServer {
    pub fn start() -> Result<Self, String> {
        let runtime = tokio::runtime::Builder::new_multi_thread()
            .enable_all()
            .build()
            .map_err(describe)?;
        let listener = runtime
            .block_on(TcpListener::bind(LOOPBACK_ADDRESS))
            .map_err(describe)?;
        let local_address = listener.local_addr().map_err(describe)?;
        let address = format!("{ADDRESS_SCHEME}{local_address}");
        let data_directory = TempDir::new().map_err(describe)?;

        let settings = ServerSettings {
            data_directory: data_directory.path().to_path_buf(),
            public_address: address.clone(),
            long_poll_timeout: LONG_POLL_TIMEOUT,
        };
        let clock = Arc::new(SkippingClock::default());
        let server_clock: Arc<dyn Clock> = clock.clone();
        let server = Server::open(settings, server_clock).map_err(describe)?;
        let router = build_router(Arc::new(server));
        runtime.spawn(axum::serve(listener, router).into_future());
        Ok(Self {
            address,
            clock,
            _serving_runtime: runtime,
            data_directory,
        })
    }

    pub fn run_skipped_ahead<Outcome>(
        &self,
        skipped_time: TimeDelta,
        action: impl FnOnce() -> Outcome,
    ) -> Outcome {
        self.clock.set_skipped_time(skipped_time);
        let outcome = action();
        self.clock.set_skipped_time(TimeDelta::zero());
        outcome
    }

    pub fn build_create_account_command(&self) -> Result<Value, String> {
        let setup_code_path =
            self.data_directory.path().join(SETUP_CODE_FILE_NAME);
        let setup_code =
            fs::read_to_string(setup_code_path).map_err(describe)?;
        Ok(json!({
            "command": "create_account",
            "server_address": self.address,
            "setup_code": setup_code.trim(),
            "device_name": "air-laptop",
            "role": "client_and_runner",
            "workspace_name": "acme",
        }))
    }
}
