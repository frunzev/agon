use std::collections::VecDeque;
use std::fs;
use std::future::IntoFuture;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::time::Duration;

use axum::body::{Body, to_bytes};
use axum::extract::{Request, State};
use axum::http::Method;
use axum::middleware::{Next, from_fn_with_state};
use axum::response::Response;
use orchestration_api::routes::ACCOUNTS;
use orchestration_server::{
    Clock, Server, ServerSettings, SystemClock, build_router,
};
use serde_json::{Value, json};
use tempfile::TempDir;
use tokio::net::TcpListener;
use tokio::runtime::Runtime;

use crate::support::test_device::{TestDevice, describe};

const LOOPBACK_ADDRESS: &str = "127.0.0.1:0";
const ADDRESS_SCHEME: &str = "http://";
const LONG_POLL_TIMEOUT: Duration = Duration::from_millis(50);
const BODY_LIMIT: usize = 16 * 1024 * 1024;
const SETUP_CODE_FILE_NAME: &str = "setup-code";

type SharedStalls = Arc<Mutex<VecDeque<Duration>>>;

#[derive(Debug)]
pub struct StallingAccountServer {
    pub address: String,
    stalls: SharedStalls,
    _serving_runtime: Runtime,
    data_directory: TempDir,
}

impl StallingAccountServer {
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
        let clock: Arc<dyn Clock> = Arc::new(SystemClock);
        let server = Server::open(settings, clock).map_err(describe)?;
        let stalls = SharedStalls::default();
        let middleware =
            from_fn_with_state(Arc::clone(&stalls), stall_account_reads);
        let router = build_router(Arc::new(server)).layer(middleware);
        runtime.spawn(axum::serve(listener, router).into_future());
        Ok(Self {
            address,
            stalls,
            _serving_runtime: runtime,
            data_directory,
        })
    }

    pub fn stall_next_account_read(&self, stall: Duration) {
        lock_stalls(&self.stalls).push_back(stall);
    }

    pub fn create_account(
        &self,
        device: &TestDevice,
    ) -> Result<Value, String> {
        let setup_code_path =
            self.data_directory.path().join(SETUP_CODE_FILE_NAME);
        let setup_code =
            fs::read_to_string(setup_code_path).map_err(describe)?;
        device.run(&json!({
            "command": "create_account",
            "server_address": self.address,
            "setup_code": setup_code.trim(),
            "device_name": "air-laptop",
            "role": "client_and_runner",
            "workspace_name": "acme",
        }))
    }
}

fn lock_stalls(stalls: &SharedStalls) -> MutexGuard<'_, VecDeque<Duration>> {
    stalls.lock().unwrap_or_else(PoisonError::into_inner)
}

async fn stall_account_reads(
    State(stalls): State<SharedStalls>,
    request: Request,
    next: Next,
) -> Response {
    let is_account_read =
        request.method() == Method::GET && request.uri().path() == ACCOUNTS;
    let response = next.run(request).await;
    if !is_account_read {
        return response;
    }

    let stall = lock_stalls(&stalls).pop_front();
    let Some(stall) = stall else {
        return response;
    };
    let (parts, body) = response.into_parts();
    let body_bytes = to_bytes(body, BODY_LIMIT).await.unwrap_or_default();
    tokio::time::sleep(stall).await;
    Response::from_parts(parts, Body::from(body_bytes))
}
