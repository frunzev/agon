use std::time::{Duration, Instant};

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::forged_workspace::list_device_views;
use crate::support::command_builders::prepare_workspace;
use crate::support::pairing_steps::{
    join_at_address, pair_into_workspace, start_pairing,
};
use crate::support::test_device::{TestDevice, fail, read_text};

const PAIRING_CASES: u32 = 2;
const MOST_TRIES: usize = 3;
const UNKNOWN_SESSION: &str = "the pairing session was not found";
const PLAIN_REFUSAL_LIMIT: Duration = Duration::from_secs(15);
const CODE_PATTERN: &str = "[0-9A-HJKMNP-TV-Z]{3}-[0-9A-HJKMNP-TV-Z]{3}";

fn read_rendezvous_problem(device: &TestDevice) -> Result<Value, String> {
    let status = device.run(&json!({ "command": "status" }))?;
    Ok(status["rendezvous_problem"].clone())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PAIRING_CASES))]

    #[test]
    fn test_published_codes_property_a_started_node_has_no_problem(
        read_count in 1..=MOST_TRIES,
    ) {
        let device = TestDevice::start().map_err(fail)?;

        for _ in 0..read_count {
            let problem = read_rendezvous_problem(&device).map_err(fail)?;
            prop_assert_eq!(problem, Value::Null);
        }
    }

    #[test]
    fn test_published_codes_property_local_pairing_leaves_no_problem(
        pairing_count in 1..=MOST_TRIES,
    ) {
        let prepared = prepare_workspace().map_err(fail)?;

        for _ in 0..pairing_count {
            let session = start_pairing(&prepared).map_err(fail)?;
            prepared
                .device
                .run(&json!({
                    "command": "cancel_pairing",
                    "code": session["code"],
                }))
                .map_err(fail)?;
            let problem =
                read_rendezvous_problem(&prepared.device).map_err(fail)?;
            prop_assert_eq!(problem, Value::Null);
        }
    }

    #[test]
    fn test_crosses_networks_property_a_wrong_code_is_refused_plainly(
        code in CODE_PATTERN,
        try_count in 1..=MOST_TRIES,
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let joining = TestDevice::start().map_err(fail)?;

        let mut refusals = Vec::new();
        for _ in 0..try_count {
            let asking_started = Instant::now();
            let refused =
                join_at_address(&joining, &prepared.server.address, &code);
            let waited = asking_started.elapsed();
            prop_assert!(waited < PLAIN_REFUSAL_LIMIT, "{:?}", waited);
            refusals.push(refused.err().unwrap_or_default());
        }

        for refusal in &refusals {
            prop_assert!(refusal.contains(UNKNOWN_SESSION), "{}", refusal);
            prop_assert_eq!(refusal, &refusals[0]);
        }
    }

    #[test]
    fn test_crosses_networks_property_local_pairing_shows_a_code(
        _seed in any::<u8>(),
    ) {
        let prepared = prepare_workspace().map_err(fail)?;

        let session = start_pairing(&prepared).map_err(fail)?;

        let display_code = read_text(&session, "/display_code").map_err(fail)?;
        prop_assert!(!display_code.trim().is_empty());
        let problem = read_rendezvous_problem(&prepared.device).map_err(fail)?;
        prop_assert_eq!(problem, Value::Null);
    }

    #[test]
    fn test_crosses_networks_property_a_local_join_needs_no_relay(
        _seed in any::<u8>(),
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let joining = TestDevice::start().map_err(fail)?;

        let joined_id =
            pair_into_workspace(&prepared, &joining).map_err(fail)?;

        let views = list_device_views(&prepared.device).map_err(fail)?;
        let is_listed = views
            .iter()
            .any(|view| view["device"]["id"] == json!(joined_id));
        prop_assert!(is_listed);
    }

    #[test]
    fn test_approver_pairings_property_an_unknown_code_has_no_request(
        code in CODE_PATTERN,
    ) {
        let prepared = prepare_workspace().map_err(fail)?;

        let request = prepared
            .device
            .run(&json!({ "command": "pairing_request", "code": code }));

        prop_assert!(request.is_err(), "{:?}", request);
    }

    #[test]
    fn test_approver_pairings_property_a_cancelled_code_is_not_approved(
        _seed in any::<u8>(),
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let joining = TestDevice::start().map_err(fail)?;
        let session = start_pairing(&prepared).map_err(fail)?;
        let display_code = read_text(&session, "/display_code").map_err(fail)?;
        join_at_address(&joining, &prepared.server.address, &display_code)
            .map_err(fail)?;
        prepared
            .device
            .run(&json!({
                "command": "cancel_pairing",
                "code": session["code"],
            }))
            .map_err(fail)?;

        let approved = prepared.device.run(&json!({
            "command": "approve_pairing",
            "code": session["code"],
            "workspace_ids": [prepared.workspace_id],
        }));

        prop_assert!(approved.is_err(), "{:?}", approved);
        let views = list_device_views(&prepared.device).map_err(fail)?;
        prop_assert_eq!(views.len(), 1);
    }

    #[test]
    fn test_approver_pairings_property_each_approval_adds_one_device(
        joining_count in 1..=2_usize,
    ) {
        let prepared = prepare_workspace().map_err(fail)?;

        let mut joined_ids = Vec::new();
        for _ in 0..joining_count {
            let joining = TestDevice::start().map_err(fail)?;
            let joined_id =
                pair_into_workspace(&prepared, &joining).map_err(fail)?;
            joined_ids.push(joined_id);
        }

        let views = list_device_views(&prepared.device).map_err(fail)?;
        prop_assert_eq!(views.len(), joining_count + 1);
        for joined_id in &joined_ids {
            let is_listed = views
                .iter()
                .any(|view| view["device"]["id"] == json!(joined_id));
            prop_assert!(is_listed);
        }
    }
}
