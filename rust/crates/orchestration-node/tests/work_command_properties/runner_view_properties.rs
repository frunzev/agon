use orchestration_api::work::HeartbeatRequest;
use orchestration_runner::runner_server::RunnerServer;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::handler_desk::{
    list_object_keys, read_own_device_id, read_problem, uuid_text_strategy,
};
use crate::support::command_builders::PreparedWorkspace;
use crate::support::runner_access::{
    open_runner, sample_heartbeat, test_runtime,
};
use crate::support::test_device::{TestDevice, describe, fail};
use crate::work_desk::check_on_workspace;

const MOST_SLOTS: u32 = 8;
const MOST_SWITCHES: usize = 4;
const DEVICE_NAME: &str = "air-laptop";
const DART_RUNNER_VIEW_FIELDS: [&str; 5] = [
    "device_name",
    "free_slots",
    "peer_address",
    "peer_address_verified",
    "runner",
];

fn send_heartbeat(
    prepared: &PreparedWorkspace,
    slots_total: u32,
    slots_busy: u32,
) -> Result<(), String> {
    let runtime = test_runtime()?;
    let runner = open_runner(prepared)?;
    let heartbeat = HeartbeatRequest {
        slots_total,
        slots_busy,
        ..sample_heartbeat()
    };
    runtime
        .block_on(runner.send_heartbeat(&heartbeat))
        .map_err(describe)?;
    Ok(())
}

fn list_runners(
    device: &TestDevice,
    workspace_id: &str,
) -> Result<Value, String> {
    device.run(&json!({
        "command": "list_runners",
        "workspace_id": workspace_id,
    }))
}

#[test]
fn test_build_runners_view_property_free_slots_are_total_minus_busy() {
    let cases = (0..=MOST_SLOTS)
        .prop_flat_map(|slots_total| (Just(slots_total), 0..=slots_total));
    check_on_workspace(&cases, |prepared, (slots_total, slots_busy)| {
        send_heartbeat(prepared, slots_total, slots_busy).map_err(fail)?;

        let view = list_runners(&prepared.device, &prepared.workspace_id)
            .map_err(fail)?;

        let free_slots = slots_total - slots_busy;
        prop_assert_eq!(&view["runners"][0]["free_slots"], &json!(free_slots));
        prop_assert_eq!(&view["summary"]["runner_count"], &json!(1));
        prop_assert_eq!(&view["summary"]["online_count"], &json!(1));
        prop_assert_eq!(
            &view["summary"]["free_slot_count"],
            &json!(free_slots)
        );
        let slot_word = if free_slots == 1 { "slot" } else { "slots" };
        let expected_text =
            format!("1 of 1 online · {free_slots} free {slot_word}");
        prop_assert_eq!(&view["summary_text"], &json!(expected_text));
        Ok(())
    });
}

#[test]
fn test_build_runners_view_property_an_unknown_workspace_has_no_runners() {
    check_on_workspace(
        &uuid_text_strategy(),
        |prepared, unknown_workspace| {
            send_heartbeat(prepared, MOST_SLOTS, 0).map_err(fail)?;

            let view = list_runners(&prepared.device, &unknown_workspace)
                .map_err(fail)?;

            prop_assert_eq!(&view["runners"], &json!([]));
            prop_assert_eq!(
                &view["summary"],
                &json!({
                    "runner_count": 0,
                    "online_count": 0,
                    "free_slot_count": 0,
                })
            );
            prop_assert_eq!(
                &view["summary_text"],
                "0 of 0 online · 0 free slots"
            );
            Ok(())
        },
    );
}

#[test]
fn test_build_runners_view_property_each_view_names_its_device() {
    check_on_workspace(&(1..=MOST_SLOTS), |prepared, slots_total| {
        send_heartbeat(prepared, slots_total, 0).map_err(fail)?;
        let own_device_id =
            read_own_device_id(&prepared.device).map_err(fail)?;

        let view = list_runners(&prepared.device, &prepared.workspace_id)
            .map_err(fail)?;

        let runner_views =
            view["runners"].as_array().cloned().unwrap_or_default();
        prop_assert_eq!(runner_views.len(), 1);
        let runner_view = &runner_views[0];
        prop_assert_eq!(
            list_object_keys(runner_view),
            DART_RUNNER_VIEW_FIELDS
        );
        prop_assert_eq!(&runner_view["device_name"], DEVICE_NAME);
        prop_assert_eq!(
            &runner_view["runner"]["device_id"],
            &json!(own_device_id)
        );
        prop_assert!(runner_view["peer_address_verified"].is_boolean());
        Ok(())
    });
}

#[test]
fn test_handle_runner_command_property_the_last_pause_or_resume_wins() {
    let cases = vec(any::<bool>(), 1..=MOST_SWITCHES);
    check_on_workspace(&cases, |prepared, switches| {
        send_heartbeat(prepared, MOST_SLOTS, 0).map_err(fail)?;
        let device = &prepared.device;
        let own_device_id = read_own_device_id(device).map_err(fail)?;

        for is_accepting in &switches {
            let command_name = if *is_accepting {
                "resume_runner"
            } else {
                "pause_runner"
            };
            let switched = device.run(&json!({
                "command": command_name,
                "device_id": own_device_id,
            }));
            prop_assert_eq!(switched, Ok(Value::Null));
            let view =
                list_runners(device, &prepared.workspace_id).map_err(fail)?;
            let accepting =
                &view["runners"][0]["runner"]["accepting_new_runs"];
            prop_assert_eq!(accepting, &json!(is_accepting));
        }
        Ok(())
    });
}

#[test]
fn test_handle_runner_command_property_offers_only_with_settings() {
    check_on_workspace(&(0..=MOST_SLOTS), |prepared, slots_total| {
        send_heartbeat(prepared, slots_total, 0).map_err(fail)?;

        let view = list_runners(&prepared.device, &prepared.workspace_id)
            .map_err(fail)?;

        prop_assert_eq!(&view["this_device_settings"], &Value::Null);
        prop_assert_eq!(&view["this_device_offers"], &Value::Null);
        let field_count = view.as_object().map_or(0, serde_json::Map::len);
        prop_assert_eq!(field_count, 6);
        Ok(())
    });
}

#[test]
fn test_handle_runner_command_property_an_unknown_runner_is_refused() {
    let cases = ("device-[a-z0-9]{6,12}", any::<bool>());
    check_on_workspace(&cases, |prepared, (unknown_device, is_pause)| {
        let command_name = if is_pause {
            "pause_runner"
        } else {
            "resume_runner"
        };

        let problem = read_problem(prepared.device.run(&json!({
            "command": command_name,
            "device_id": unknown_device,
        })));

        prop_assert!(
            problem.starts_with("the app server answered 404"),
            "{}",
            problem
        );
        Ok(())
    });
}
