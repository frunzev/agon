use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::command_builders::{PreparedWorkspace, prepare_workspace};
use crate::support::pairing_steps::pair_into_workspace;
use crate::support::test_device::{TestDevice, fail};

const PAIRING_CASES: u32 = 2;
const FIRST_WORKSPACE_NAME: &str = "acme";

#[derive(Debug)]
struct PairedDevices {
    prepared: PreparedWorkspace,
    _joining: TestDevice,
    joining_id: String,
}

fn pair_two_devices() -> Result<PairedDevices, String> {
    let prepared = prepare_workspace()?;
    let joining = TestDevice::start()?;
    let joining_id = pair_into_workspace(&prepared, &joining)?;
    Ok(PairedDevices {
        prepared,
        _joining: joining,
        joining_id,
    })
}

fn list_views(device: &TestDevice, name: &str) -> Result<Vec<Value>, String> {
    let listed = device.run(&json!({ "command": name }))?;
    Ok(listed.as_array().cloned().unwrap_or_default())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PAIRING_CASES))]

    #[test]
    fn test_build_device_views_property_a_paired_device_is_another_one(
        _seed in any::<u8>(),
    ) {
        let paired = pair_two_devices().map_err(fail)?;

        let views = list_views(&paired.prepared.device, "list_devices")
            .map_err(fail)?;

        prop_assert_eq!(views.len(), 2);
        let wanted_id = json!(paired.joining_id);
        let joined_view = views
            .iter()
            .find(|view| view["device"]["id"] == wanted_id)
            .cloned()
            .unwrap_or_default();
        prop_assert_eq!(&joined_view["is_this_device"], &json!(false));
        prop_assert_eq!(
            &joined_view["workspace_names"],
            &json!([FIRST_WORKSPACE_NAME])
        );
    }

    #[test]
    fn test_build_workspace_views_property_a_paired_client_adds_no_runner(
        _seed in any::<u8>(),
    ) {
        let paired = pair_two_devices().map_err(fail)?;

        let views = list_views(&paired.prepared.device, "list_workspaces")
            .map_err(fail)?;

        prop_assert_eq!(views.len(), 1);
        prop_assert_eq!(&views[0]["runner_count"], &json!(1));
        prop_assert_eq!(&views[0]["project_count"], &json!(1));
    }
}
