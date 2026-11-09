use std::time::Duration;

use proptest::prelude::*;

use crate::hosting_desk::{heavy_cases, host_a_server, shared_hosting};
use crate::support::hosting_steps::{HostingDevice, read_hosted_address};
use crate::support::server_backups::pair_client_at;
use crate::support::test_device::{TestDevice, fail, read_text};
use crate::support::waiting::wait_for;

const ROUTE_LIMIT: Duration = Duration::from_secs(30);
const ROUTE_DESCRIPTION: &str = "the app server routes to be readable";
const APP_SERVER_START: &str = "app_server: RwLock { data: Some(";
const APP_SERVER_END: &str = "server_dialer:";
const CLIENT_NAME: &str = "route-laptop";
const WORKSPACE_ID_POINTER: &str = "/workspaces/0/id";

fn describe_loopback_route(port: u16) -> String {
    format!("base_address: \"http://127.0.0.1:{port}\"")
}

fn read_app_server_debug(device: &TestDevice) -> Result<String, String> {
    wait_for(ROUTE_LIMIT, ROUTE_DESCRIPTION, || {
        let debug_text = format!("{device:?}");
        let Some(start) = debug_text.find(APP_SERVER_START) else {
            return Ok(None);
        };
        let from_app_server = &debug_text[start..];
        let Some(end) = from_app_server.find(APP_SERVER_END) else {
            return Ok(None);
        };
        Ok(Some(from_app_server[..end].to_owned()))
    })
}

fn pair_a_client(hosting: &HostingDevice) -> Result<TestDevice, String> {
    let client = TestDevice::start()?;
    let address = read_hosted_address(&hosting.device)?;
    let workspace_id = read_text(&hosting.account, WORKSPACE_ID_POINTER)?;
    pair_client_at(
        &hosting.device,
        &client,
        &address,
        &workspace_id,
        CLIENT_NAME,
    )?;
    Ok(client)
}

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_describe_own_server_route_property_the_host_dials_its_loopback(
        _round in 0_u8..1,
    ) {
        let hosting = shared_hosting().map_err(fail)?;

        let app_server = read_app_server_debug(&hosting.device).map_err(fail)?;

        let loopback_route = describe_loopback_route(hosting.port);
        prop_assert!(app_server.contains(&loopback_route), "{app_server}");
    }

    #[test]
    fn test_describe_own_server_route_property_a_restart_keeps_the_loopback(
        _round in 0_u8..1,
    ) {
        let HostingDevice { device, port, .. } =
            host_a_server().map_err(fail)?;

        let restarted = device.stop_and_start_again().map_err(fail)?;

        let app_server = read_app_server_debug(&restarted).map_err(fail)?;
        let loopback_route = describe_loopback_route(port);
        prop_assert!(app_server.contains(&loopback_route), "{app_server}");
    }

    #[test]
    fn test_describe_own_server_route_property_a_client_takes_no_loopback(
        _round in 0_u8..1,
    ) {
        let hosting = shared_hosting().map_err(fail)?;

        let client = pair_a_client(hosting).map_err(fail)?;

        let app_server = read_app_server_debug(&client).map_err(fail)?;
        let loopback_route = describe_loopback_route(hosting.port);
        prop_assert!(!app_server.contains(&loopback_route), "{app_server}");
    }
}
