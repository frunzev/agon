use std::thread;
use std::time::Duration;

use orchestration_api::routes::DEVICE_PEER_ADDRESS;
use serde_json::{Value, json};

use crate::peer_publishing::read_announcement;
use crate::support::test_device::TestDevice;
use crate::support::test_server::TestServer;
use crate::support::waiting::wait_for;

pub const ANNOUNCE_TICK: Duration = Duration::from_millis(1_100);
pub const PROBLEM_LIMIT: Duration = Duration::from_secs(20);
const PUT_METHOD: &str = "PUT";
const WORKSPACE_NAME: &str = "acme";

pub fn count_publishing(server: &TestServer) -> usize {
    let mut publishing_count = 0;
    for request in server.recorded_requests() {
        let is_publishing = request.method == PUT_METHOD
            && request.path == DEVICE_PEER_ADDRESS;
        if is_publishing {
            publishing_count += 1;
        }
    }
    publishing_count
}

pub fn start_with_account() -> Result<(TestServer, TestDevice), String> {
    let server = TestServer::start()?;
    let device = TestDevice::start()?;
    device.create_account(&server, WORKSPACE_NAME)?;
    Ok((server, device))
}

pub fn create_account_on(
    device: &TestDevice,
    server: &TestServer,
) -> Result<Value, String> {
    device.create_account(server, WORKSPACE_NAME)
}

pub fn wait_ticks(tick_count: u32) {
    thread::sleep(ANNOUNCE_TICK * tick_count);
}

pub fn read_listed_own_address(device: &TestDevice) -> Result<Value, String> {
    let views = device.run(&json!({ "command": "list_devices" }))?;
    let listed = views.as_array().cloned().unwrap_or_default();
    let own_view = listed
        .iter()
        .find(|view| view["is_this_device"] == json!(true))
        .ok_or("this device is not listed")?;
    Ok(own_view["device"]["peer_address"]["address"].clone())
}

pub fn wait_for_problem(device: &TestDevice) -> Result<String, String> {
    wait_for(PROBLEM_LIMIT, "an announcement problem", || {
        let announcement = read_announcement(device)?;
        Ok(announcement["problem"].as_str().map(str::to_owned))
    })
}
