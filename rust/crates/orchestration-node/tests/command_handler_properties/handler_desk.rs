use std::sync::OnceLock;

use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use serde_json::{Value, json};

use crate::support::command_builders::{PreparedWorkspace, prepare_workspace};
use crate::support::test_device::{TestDevice, fail, read_text};
use crate::support::test_server::TestServer;

pub const HANDLER_CASES: u32 = 4;
pub const NO_ACCOUNT_KIND: &str = "no_account";
pub const NO_ACCOUNT_PROBLEM: &str = "this device has no account yet";
pub const NOT_A_RUNNER_PROBLEM: &str = "this device cannot run tasks";
pub const INVALID_ARGUMENTS_START: &str = "invalid arguments for";
pub const ERROR_FIELD: &str = "error";
pub const ERROR_KIND_FIELD: &str = "error_kind";
pub const NOT_FOUND_START: &str = "the app server answered 404:";
pub const POST_METHOD: &str = "POST";
pub const NAME_PATTERN: &str = "[a-z][a-z0-9-]{0,20}";
const UUID_LIMIT: u128 = u128::MAX;

static FRESH_DEVICE: OnceLock<Result<TestDevice, String>> = OnceLock::new();
static SHARED_WORKSPACE: OnceLock<Result<PreparedWorkspace, String>> =
    OnceLock::new();

pub fn shared_fresh_device() -> Result<&'static TestDevice, TestCaseError> {
    let started_device = FRESH_DEVICE.get_or_init(TestDevice::start);
    started_device.as_ref().map_err(fail)
}

pub fn shared_workspace() -> Result<&'static PreparedWorkspace, TestCaseError>
{
    let prepared = SHARED_WORKSPACE.get_or_init(prepare_workspace);
    prepared.as_ref().map_err(fail)
}

pub fn name_strategy() -> impl Strategy<Value = String> {
    NAME_PATTERN
}

pub fn uuid_text_strategy() -> impl Strategy<Value = String> {
    (1..UUID_LIMIT)
        .prop_map(|number| uuid::Uuid::from_u128(number).to_string())
}

pub fn read_problem(outcome: Result<Value, String>) -> String {
    outcome.err().unwrap_or_default()
}

pub fn read_error_kind(reply: &Value) -> Option<&str> {
    reply.get(ERROR_KIND_FIELD).and_then(Value::as_str)
}

pub fn read_reply_problem(reply: &Value) -> &str {
    reply
        .get(ERROR_FIELD)
        .and_then(Value::as_str)
        .unwrap_or_default()
}

pub fn create_workspace(
    device: &TestDevice,
    name: &str,
) -> Result<String, String> {
    let created =
        device.run(&json!({ "command": "create_workspace", "name": name }))?;
    read_text(&created, "/id")
}

pub fn read_own_device_id(device: &TestDevice) -> Result<String, String> {
    let status = device.run(&json!({ "command": "status" }))?;
    read_text(&status, "/device_id")
}

pub fn count_requests_to(
    server: &TestServer,
    method: &str,
    path_start: &str,
) -> usize {
    let recorded = server.recorded_requests();
    let mut count = 0;
    for request in recorded {
        let is_counted =
            request.method == method && request.path.starts_with(path_start);
        if is_counted {
            count += 1;
        }
    }
    count
}

pub fn list_object_keys(value: &Value) -> Vec<String> {
    let mut keys = Vec::new();
    if let Some(fields) = value.as_object() {
        for key in fields.keys() {
            keys.push(key.clone());
        }
    }
    keys.sort();
    keys
}

pub fn sorted_texts(texts: &[&str]) -> Vec<String> {
    let mut sorted = Vec::new();
    for text in texts {
        sorted.push((*text).to_owned());
    }
    sorted.sort();
    sorted
}
