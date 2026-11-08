use proptest::prelude::*;
use serde_json::{Value, json};

use crate::command_shapes::DEVICE_SHAPES;
use crate::handler_desk::{
    HANDLER_CASES, NO_ACCOUNT_KIND, NO_ACCOUNT_PROBLEM, NOT_FOUND_START,
    POST_METHOD, count_requests_to, read_error_kind, read_own_device_id,
    read_problem, read_reply_problem, shared_fresh_device, shared_workspace,
    uuid_text_strategy,
};
use crate::shape_checks::shape_strategy;
use crate::support::command_builders::prepare_workspace;
use crate::support::test_device::fail;

const POLICY_NAMES: [&str; 2] = ["ask_before_risky_actions", "never_ask"];
const FORBIDDEN_START: &str = "the app server answered 403:";
const CLIENT_REFUSAL_START: &str = "the app server answered 4";
const CONFLICT_START: &str = "the app server answered 409:";
const DEVICE_TEXT_PATTERN: &str = "\\PC{1,24}";
const ROUTE_SAFE_DEVICE_PATTERN: &str = "[a-z0-9-]{1,24}";
const ROUTE_HOSTILE_DEVICE_PATTERN: &str = "[a-z]{0,4}[ ./?#][a-z]{0,4}";
const ROUTE_REFUSAL_END: &str = "cannot be used inside a route";
const DELETE_METHOD: &str = "DELETE";
const WORKSPACES_PATH: &str = "/workspaces/";
const AUDIT_COUNT_POINTER: &str = "/entry_count";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HANDLER_CASES))]

    #[test]
    fn test_handle_device_command_property_no_account_names_its_kind(
        shape in shape_strategy(&DEVICE_SHAPES),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&shape.build_command());

        prop_assert_eq!(read_reply_problem(&reply), NO_ACCOUNT_PROBLEM);
        prop_assert_eq!(read_error_kind(&reply), Some(NO_ACCOUNT_KIND));
    }

    #[test]
    fn test_handle_device_command_property_revoking_needs_another_device(
        unknown_device_id in ROUTE_SAFE_DEVICE_PATTERN,
    ) {
        let prepared = shared_workspace()?;
        let own_device_id =
            read_own_device_id(&prepared.device).map_err(fail)?;
        prop_assume!(unknown_device_id != own_device_id);

        let unknown = read_problem(prepared.device.run(&json!({
            "command": "revoke_device",
            "device_id": unknown_device_id,
        })));
        let own = read_problem(prepared.device.run(&json!({
            "command": "revoke_device",
            "device_id": own_device_id,
        })));

        prop_assert!(unknown.starts_with(NOT_FOUND_START), "{}", unknown);
        prop_assert!(own.starts_with(FORBIDDEN_START), "{}", own);
    }

    #[test]
    fn test_handle_device_command_property_hostile_ids_stay_local(
        hostile_device_id in ROUTE_HOSTILE_DEVICE_PATTERN,
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let member_path =
            format!("{WORKSPACES_PATH}{}/devices/", prepared.workspace_id);
        let removals_before =
            count_requests_to(&prepared.server, DELETE_METHOD, &member_path);

        let revoked = read_problem(prepared.device.run(&json!({
            "command": "revoke_device",
            "device_id": hostile_device_id,
        })));
        let removed = read_problem(prepared.device.run(&json!({
            "command": "remove_device_from_workspace",
            "workspace_id": prepared.workspace_id,
            "device_id": hostile_device_id,
        })));

        prop_assert!(revoked.ends_with(ROUTE_REFUSAL_END), "{}", revoked);
        prop_assert!(removed.ends_with(ROUTE_REFUSAL_END), "{}", removed);
        let removals_after =
            count_requests_to(&prepared.server, DELETE_METHOD, &member_path);
        prop_assert_eq!(removals_after, removals_before);
    }

    #[test]
    fn test_handle_device_command_property_a_chosen_policy_is_kept(
        policies in prop::collection::vec(
            prop::sample::select(POLICY_NAMES.to_vec()),
            1..4,
        ),
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let device = &prepared.device;

        for policy in &policies {
            let changed = device
                .run(&json!({
                    "command": "change_workspace_approval_policy",
                    "workspace_id": prepared.workspace_id,
                    "approval_policy": policy,
                }))
                .map_err(fail)?;
            prop_assert_eq!(&changed["approval_policy"], &json!(policy));
            prop_assert_eq!(&changed["id"], &json!(prepared.workspace_id));
        }
        let listed = device
            .run(&json!({ "command": "list_workspaces" }))
            .map_err(fail)?;

        let last_policy = policies.last().copied().unwrap_or_default();
        let shown_policy = &listed[0]["workspace"]["approval_policy"];
        prop_assert_eq!(shown_policy, &json!(last_policy));
    }

    #[test]
    fn test_handle_device_command_property_unknown_members_are_not_found(
        unknown_device_id in ROUTE_SAFE_DEVICE_PATTERN,
        unknown_workspace_id in uuid_text_strategy(),
    ) {
        let prepared = shared_workspace()?;
        let device = &prepared.device;

        let unknown_member = read_problem(device.run(&json!({
            "command": "remove_device_from_workspace",
            "workspace_id": prepared.workspace_id,
            "device_id": unknown_device_id,
        })));
        let unknown_workspace = read_problem(device.run(&json!({
            "command": "change_workspace_approval_policy",
            "workspace_id": unknown_workspace_id,
            "approval_policy": POLICY_NAMES[0],
        })));

        prop_assert!(
            unknown_member.starts_with(NOT_FOUND_START),
            "{}",
            unknown_member
        );
        prop_assert!(
            unknown_workspace.starts_with(CLIENT_REFUSAL_START),
            "{}",
            unknown_workspace
        );
    }

    #[test]
    fn test_handle_device_command_property_the_audit_only_grows(
        policies in prop::collection::vec(
            prop::sample::select(POLICY_NAMES.to_vec()),
            1..4,
        ),
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let device = &prepared.device;
        let mut last_count = 0;

        for policy in &policies {
            device
                .run(&json!({
                    "command": "change_workspace_approval_policy",
                    "workspace_id": prepared.workspace_id,
                    "approval_policy": policy,
                }))
                .map_err(fail)?;
            let audit = device
                .run(&json!({ "command": "list_audit" }))
                .map_err(fail)?;
            let count = audit
                .pointer(AUDIT_COUNT_POINTER)
                .and_then(Value::as_u64)
                .unwrap_or_default();
            prop_assert!(count > last_count, "{} {}", count, last_count);
            prop_assert_eq!(&audit["intact"], &json!(true));
            last_count = count;
        }
    }

    #[test]
    fn test_device_find_device_property_names_an_unknown_device_locally(
        unknown_device_id in DEVICE_TEXT_PATTERN,
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let own_device_id =
            read_own_device_id(&prepared.device).map_err(fail)?;
        prop_assume!(unknown_device_id != own_device_id);
        let add_path = format!(
            "{WORKSPACES_PATH}{}/devices",
            prepared.workspace_id
        );
        let server = &prepared.server;
        let adds_before = count_requests_to(server, POST_METHOD, &add_path);

        let problem = read_problem(prepared.device.run(&json!({
            "command": "add_device_to_workspace",
            "workspace_id": prepared.workspace_id,
            "device_id": unknown_device_id,
        })));

        let expected = format!("device {unknown_device_id} was not found");
        prop_assert_eq!(problem, expected);
        let adds_after = count_requests_to(server, POST_METHOD, &add_path);
        prop_assert_eq!(adds_after, adds_before);
    }

    #[test]
    fn test_device_find_device_property_matches_the_whole_identifier(
        extra in "[a-z0-9]{1,6}",
        cut in 1_usize..8,
    ) {
        let prepared = shared_workspace()?;
        let own_device_id =
            read_own_device_id(&prepared.device).map_err(fail)?;
        let longer_id = format!("{own_device_id}{extra}");
        let kept_length = own_device_id.len().saturating_sub(cut);
        let shorter_id = own_device_id[..kept_length].to_owned();

        for near_id in [longer_id, shorter_id] {
            let problem = read_problem(prepared.device.run(&json!({
                "command": "add_device_to_workspace",
                "workspace_id": prepared.workspace_id,
                "device_id": near_id,
            })));
            let expected = format!("device {near_id} was not found");
            prop_assert_eq!(problem, expected);
        }
    }

    #[test]
    fn test_device_find_device_property_a_known_device_passes_on(
        unknown_workspace_id in uuid_text_strategy(),
    ) {
        let prepared = shared_workspace()?;
        let own_device_id =
            read_own_device_id(&prepared.device).map_err(fail)?;

        let unknown_workspace = read_problem(prepared.device.run(&json!({
            "command": "add_device_to_workspace",
            "workspace_id": unknown_workspace_id,
            "device_id": own_device_id,
        })));
        let own_workspace = read_problem(prepared.device.run(&json!({
            "command": "add_device_to_workspace",
            "workspace_id": prepared.workspace_id,
            "device_id": own_device_id,
        })));

        let missing_key = format!(
            "this device holds no key for workspace {unknown_workspace_id}"
        );
        prop_assert_eq!(unknown_workspace, missing_key);
        prop_assert!(
            own_workspace.starts_with(CONFLICT_START),
            "{}",
            own_workspace
        );
    }
}
