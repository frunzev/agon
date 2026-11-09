use std::fs;
use std::future::IntoFuture;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, MutexGuard, PoisonError};
use std::time::Duration;

use axum::body::{Body, to_bytes};
use axum::extract::{Request, State};
use axum::http::header::CONTENT_LENGTH;
use axum::http::{Method, StatusCode};
use axum::middleware::{Next, from_fn_with_state};
use axum::response::{IntoResponse, Response};
use orchestration_api::routes::APPROVALS;
use orchestration_core::identifiers::generate_uuid;
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
const BYTE_VALUES: u64 = 256;
const APPROVED: &str = "approved";
const DENIED: &str = "denied";
const FORGED_BRANCH: &str = "forged/branch";

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ApprovalForgery {
    FlippedDecision,
    ForeignDecider,
    ChangedSignature,
    ChangedAction,
    RemovedApproval,
}

#[derive(Debug, Default)]
struct ForgeryState {
    forgery: Mutex<Option<ApprovalForgery>>,
    listing_count: AtomicUsize,
}

#[derive(Debug)]
pub struct ApprovalForgingServer {
    pub address: String,
    state: Arc<ForgeryState>,
    _serving_runtime: Runtime,
    data_directory: TempDir,
}

impl ApprovalForgingServer {
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
        let state = Arc::new(ForgeryState::default());
        let forging =
            from_fn_with_state(Arc::clone(&state), forge_approval_listing);
        let router = build_router(Arc::new(server)).layer(forging);
        runtime.spawn(axum::serve(listener, router).into_future());
        Ok(Self {
            address,
            state,
            _serving_runtime: runtime,
            data_directory,
        })
    }

    pub fn forge(&self, forgery: ApprovalForgery) {
        *lock_forgery(&self.state) = Some(forgery);
    }

    pub fn count_listings(&self) -> usize {
        self.state.listing_count.load(Ordering::SeqCst)
    }

    pub fn read_setup_code(&self) -> Result<String, String> {
        let setup_code_path =
            self.data_directory.path().join(SETUP_CODE_FILE_NAME);
        let setup_code =
            fs::read_to_string(setup_code_path).map_err(describe)?;
        Ok(setup_code.trim().to_owned())
    }
}

async fn forge_approval_listing(
    State(state): State<Arc<ForgeryState>>,
    request: Request,
    next: Next,
) -> Response {
    let is_listing =
        request.method() == Method::GET && request.uri().path() == APPROVALS;
    if is_listing {
        state.listing_count.fetch_add(1, Ordering::SeqCst);
    }
    let response = next.run(request).await;
    let chosen_forgery = *lock_forgery(&state);
    match chosen_forgery {
        Some(forgery) if is_listing => {
            rewrite_listing(response, forgery).await
        }
        _ => response,
    }
}

async fn rewrite_listing(
    response: Response,
    forgery: ApprovalForgery,
) -> Response {
    let (mut parts, body) = response.into_parts();
    let Ok(body_bytes) = to_bytes(body, BODY_LIMIT).await else {
        return StatusCode::BAD_GATEWAY.into_response();
    };
    let Ok(mut approvals) = serde_json::from_slice::<Value>(&body_bytes)
    else {
        return Response::from_parts(parts, Body::from(body_bytes));
    };
    if let Some(listed) = approvals.as_array_mut() {
        if forgery == ApprovalForgery::RemovedApproval {
            listed.clear();
        }
        for approval in listed.iter_mut() {
            forge_approval(approval, forgery);
        }
    }
    parts.headers.remove(CONTENT_LENGTH);
    Response::from_parts(parts, Body::from(approvals.to_string()))
}

fn forge_approval(approval: &mut Value, forgery: ApprovalForgery) {
    if approval["decision"].is_null() {
        return;
    }
    let decision = &mut approval["decision"];
    match forgery {
        ApprovalForgery::RemovedApproval => {}
        ApprovalForgery::FlippedDecision => {
            let flipped = if decision["decision"] == json!(APPROVED) {
                DENIED
            } else {
                APPROVED
            };
            decision["decision"] = json!(flipped);
        }
        ApprovalForgery::ForeignDecider => {
            decision["decided_by"] = json!(generate_uuid());
        }
        ApprovalForgery::ChangedSignature => {
            shift_first_byte(&mut decision["signature"]);
        }
        ApprovalForgery::ChangedAction => {
            approval["action"]["branch"] = json!(FORGED_BRANCH);
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

fn lock_forgery(
    state: &ForgeryState,
) -> MutexGuard<'_, Option<ApprovalForgery>> {
    state.forgery.lock().unwrap_or_else(PoisonError::into_inner)
}
