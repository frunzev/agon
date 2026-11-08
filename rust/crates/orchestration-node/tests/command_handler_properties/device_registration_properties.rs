use proptest::prelude::*;
use serde_json::{Value, json};

use crate::handler_desk::{name_strategy, read_own_device_id};
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;

const REGISTRATION_CASES: u32 = 3;
const ROLE_NAMES: [&str; 3] = ["client", "runner", "client_and_runner"];
const COMPUTER_KIND: &str = "computer";
const SOFTWARE_KEY_KIND: &str = "software";

#[derive(Debug)]
struct RegisteredDevice {
    _server: TestServer,
    device: TestDevice,
    own_view: Value,
}

fn register(
    device_name: &str,
    role: &str,
) -> Result<RegisteredDevice, String> {
    let server = TestServer::start()?;
    let device = TestDevice::start()?;
    device.run(&json!({
        "command": "create_account",
        "server_address": server.address,
        "setup_code": server.read_setup_code()?,
        "device_name": device_name,
        "role": role,
        "workspace_name": "acme",
    }))?;
    let own_device_id = read_own_device_id(&device)?;
    let listed = device.run(&json!({ "command": "list_devices" }))?;
    let wanted_id = json!(own_device_id);
    let own_view = listed
        .as_array()
        .into_iter()
        .flatten()
        .find(|view| view["device"]["id"] == wanted_id)
        .cloned()
        .ok_or("this device is not listed")?;
    Ok(RegisteredDevice {
        _server: server,
        device,
        own_view,
    })
}

fn role_strategy() -> impl Strategy<Value = &'static str> {
    prop::sample::select(ROLE_NAMES.to_vec())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(REGISTRATION_CASES))]

    #[test]
    fn test_register_this_device_property_keeps_the_name_and_role(
        device_name in name_strategy(),
        role in role_strategy(),
    ) {
        let registered = register(&device_name, role).map_err(fail)?;

        let device = &registered.own_view["device"];
        prop_assert_eq!(&device["name"], &json!(device_name));
        prop_assert_eq!(&device["role"], &json!(role));
        prop_assert_eq!(&device["revoked"], &json!(false));
    }

    #[test]
    fn test_register_this_device_property_names_a_software_computer(
        device_name in name_strategy(),
        role in role_strategy(),
    ) {
        let registered = register(&device_name, role).map_err(fail)?;

        let device = &registered.own_view["device"];
        prop_assert_eq!(&device["kind"], &json!(COMPUTER_KIND));
        prop_assert_eq!(&device["key_kind"], &json!(SOFTWARE_KEY_KIND));
        prop_assert_eq!(&registered.own_view["is_this_device"], &json!(true));
    }

    #[test]
    fn test_register_this_device_property_sends_the_kept_public_keys(
        device_name in name_strategy(),
        role in role_strategy(),
    ) {
        let registered = register(&device_name, role).map_err(fail)?;
        let identity = registered.device.load_identity().map_err(fail)?;

        let public_identity = identity.public_identity();
        let device = &registered.own_view["device"];
        prop_assert_eq!(
            &device["signing_public_key"],
            &json!(public_identity.signing_public_key)
        );
        prop_assert_eq!(
            &device["sealing_public_key"],
            &json!(public_identity.sealing_public_key)
        );
        prop_assert_eq!(&device["id"], &json!(identity.device_id().0));
    }
}
