use std::fs;
use std::future::IntoFuture;
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::time::Duration;

use axum::body::{Body, to_bytes};
use axum::extract::{Request, State};
use axum::http::header::CONTENT_LENGTH;
use axum::http::{Method, StatusCode};
use axum::middleware::{Next, from_fn_with_state};
use axum::response::{IntoResponse, Response};
use orchestration_api::routes::DEVICES;
use orchestration_server::{
    Clock, Server, ServerSettings, SystemClock, build_router,
};
use serde_json::{Value, json};
use tempfile::TempDir;
use tokio::net::TcpListener;
use tokio::runtime::Runtime;

use crate::support::runner_access::test_runtime;
use crate::support::test_device::describe;

const LOOPBACK_ADDRESS: &str = "127.0.0.1:0";
const ADDRESS_SCHEME: &str = "http://";
const LONG_POLL_TIMEOUT: Duration = Duration::from_millis(50);
const BODY_LIMIT: usize = 16 * 1024 * 1024;
const SETUP_CODE_FILE_NAME: &str = "setup-code";
const FORGED_DEVICE_ID: &str = "forged-device";
const BYTE_VALUES: u64 = 256;
const LATER_PUBLISHED_AT: &str = "2099-01-01T00:00:00Z";

type SharedPlan = Arc<Mutex<Option<ForgeryPlan>>>;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Forgery {
    Untouched,
    RemovedAddress,
    ForeignDeviceId,
    ChangedSignature,
    MovedEndpoint,
    LaterPublishing,
}

#[derive(Clone, Debug)]
struct ForgeryPlan {
    device_id: String,
    forgery: Forgery,
}

#[derive(Debug)]
pub struct ForgingServer {
    pub address: String,
    plan: SharedPlan,
    _serving_runtime: Runtime,
    data_directory: TempDir,
}

impl ForgingServer {
    pub fn start() -> Result<Self, String> {
        let runtime = test_runtime()?;
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
        let plan = SharedPlan::default();
        let forging =
            from_fn_with_state(Arc::clone(&plan), forge_device_listing);
        let router = build_router(Arc::new(server)).layer(forging);
        runtime.spawn(axum::serve(listener, router).into_future());
        Ok(Self {
            address,
            plan,
            _serving_runtime: runtime,
            data_directory,
        })
    }

    pub fn forge(&self, device_id: &str, forgery: Forgery) {
        *lock_plan(&self.plan) = Some(ForgeryPlan {
            device_id: device_id.to_owned(),
            forgery,
        });
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

async fn forge_device_listing(
    State(plan): State<SharedPlan>,
    request: Request,
    next: Next,
) -> Response {
    let is_listing =
        request.method() == Method::GET && request.uri().path() == DEVICES;
    let response = next.run(request).await;
    let chosen_plan = lock_plan(&plan).clone();
    match chosen_plan {
        Some(chosen_plan) if is_listing => {
            rewrite_listing(response, &chosen_plan).await
        }
        _ => response,
    }
}

async fn rewrite_listing(response: Response, plan: &ForgeryPlan) -> Response {
    let (mut parts, body) = response.into_parts();
    let Ok(body_bytes) = to_bytes(body, BODY_LIMIT).await else {
        return StatusCode::BAD_GATEWAY.into_response();
    };
    let Ok(mut devices) = serde_json::from_slice::<Value>(&body_bytes) else {
        return Response::from_parts(parts, Body::from(body_bytes));
    };
    if let Some(listed) = devices.as_array_mut() {
        for device in listed {
            if device["id"] == json!(plan.device_id) {
                forge_peer_address(&mut device["peer_address"], plan.forgery);
            }
        }
    }
    parts.headers.remove(CONTENT_LENGTH);
    Response::from_parts(parts, Body::from(devices.to_string()))
}

fn forge_peer_address(peer_address: &mut Value, forgery: Forgery) {
    match forgery {
        Forgery::Untouched => {}
        Forgery::RemovedAddress => *peer_address = Value::Null,
        Forgery::ForeignDeviceId => {
            peer_address["device_id"] = json!(FORGED_DEVICE_ID);
        }
        Forgery::ChangedSignature => {
            shift_first_byte(&mut peer_address["signature"]);
        }
        Forgery::MovedEndpoint => {
            let endpoint_key =
                &mut peer_address["address"]["endpoint_public_key"];
            shift_first_byte(endpoint_key);
        }
        Forgery::LaterPublishing => {
            peer_address["published_at"] = json!(LATER_PUBLISHED_AT);
        }
    }
}

fn shift_first_byte(bytes: &mut Value) {
    let Some(first_byte) = bytes.get_mut(0) else {
        return;
    };
    let first_value = first_byte.as_u64().unwrap_or_default();
    *first_byte = json!((first_value + 1) % BYTE_VALUES);
}

fn lock_plan(plan: &SharedPlan) -> MutexGuard<'_, Option<ForgeryPlan>> {
    plan.lock().unwrap_or_else(PoisonError::into_inner)
}
