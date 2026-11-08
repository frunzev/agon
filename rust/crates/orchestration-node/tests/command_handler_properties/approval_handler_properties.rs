use proptest::prelude::*;
use serde_json::{Value, json};

use crate::command_shapes::APPROVAL_SHAPES;
use crate::handler_desk::{
    HANDLER_CASES, NO_ACCOUNT_KIND, NO_ACCOUNT_PROBLEM, POST_METHOD,
    count_requests_to, list_object_keys, read_error_kind, read_problem,
    read_reply_problem, shared_fresh_device, shared_workspace, sorted_texts,
    uuid_text_strategy,
};
use crate::shape_checks::shape_strategy;
use crate::support::command_builders::prepare_workspace;
use crate::support::test_device::{TestDevice, fail, read_text};

const DECISION_NAMES: [&str; 2] = ["approved", "denied"];
const TARGET_PATTERN: &str = "[a-z][a-z0-9-]{0,12}";
const MOST_APPROVALS: usize = 4;
const CONFLICT_START: &str = "the app server answered 409:";
const APPROVALS_PATH: &str = "/approvals/";
const DART_APPROVALS_FIELDS: [&str; 2] = ["waiting_count", "approvals"];
const DART_APPROVAL_FIELDS: [&str; 4] =
    ["approval", "description", "is_waiting", "skill_change"];

fn deploy_action(target: &str) -> Value {
    json!({ "kind": "deploy", "target": target })
}

fn create_deploy_approval(
    device: &TestDevice,
    target: &str,
) -> Result<Value, String> {
    device.run(&json!({
        "command": "create_approval",
        "run_id": null,
        "action": deploy_action(target),
    }))
}

fn decide(
    device: &TestDevice,
    approval_id: &str,
    decision: &str,
) -> Result<Value, String> {
    device.run(&json!({
        "command": "decide_approval",
        "approval_id": approval_id,
        "decision": decision,
    }))
}

fn list_approvals(device: &TestDevice) -> Result<Value, String> {
    device.run(&json!({ "command": "list_approvals" }))
}

fn find_listed<'listing>(
    listing: &'listing Value,
    approval_id: &str,
) -> Vec<&'listing Value> {
    let wanted = json!(approval_id);
    let mut found = Vec::new();
    for view in listing["approvals"].as_array().into_iter().flatten() {
        if view["approval"]["id"] == wanted {
            found.push(view);
        }
    }
    found
}

fn list_views(listing: &Value) -> Vec<Value> {
    listing["approvals"].as_array().cloned().unwrap_or_default()
}

fn count_waiting(listing: &Value) -> usize {
    let views = list_views(listing);
    views
        .iter()
        .filter(|view| view["is_waiting"] == json!(true))
        .count()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HANDLER_CASES))]

    #[test]
    fn test_handle_approval_command_property_no_account_names_its_kind(
        shape in shape_strategy(&APPROVAL_SHAPES),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&shape.build_command());

        prop_assert_eq!(read_reply_problem(&reply), NO_ACCOUNT_PROBLEM);
        prop_assert_eq!(read_error_kind(&reply), Some(NO_ACCOUNT_KIND));
    }

    #[test]
    fn test_handle_approval_command_property_unknown_ids_stay_local(
        approval_id in uuid_text_strategy(),
        decision in prop::sample::select(DECISION_NAMES.to_vec()),
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let decisions_before =
            count_requests_to(&prepared.server, POST_METHOD, APPROVALS_PATH);

        let problem = read_problem(decide(
            &prepared.device,
            &approval_id,
            decision,
        ));

        let expected = format!("approval {approval_id} was not found");
        prop_assert_eq!(problem, expected);
        let decisions_after =
            count_requests_to(&prepared.server, POST_METHOD, APPROVALS_PATH);
        prop_assert_eq!(decisions_after, decisions_before);
    }

    #[test]
    fn test_handle_approval_command_property_a_decision_is_final(
        target in TARGET_PATTERN,
        first in prop::sample::select(DECISION_NAMES.to_vec()),
        second in prop::sample::select(DECISION_NAMES.to_vec()),
    ) {
        let prepared = shared_workspace()?;
        let device = &prepared.device;
        let created = create_deploy_approval(device, &target).map_err(fail)?;
        let approval_id = read_text(&created, "/id").map_err(fail)?;

        let first_outcome = decide(device, &approval_id, first);
        let second_outcome = decide(device, &approval_id, second);
        let second_problem = read_problem(second_outcome);
        let listing = list_approvals(device).map_err(fail)?;

        prop_assert_eq!(&created["action"], &deploy_action(&target));
        prop_assert_eq!(&created["decision"], &Value::Null);
        prop_assert_eq!(first_outcome, Ok(Value::Null));
        prop_assert!(
            second_problem.starts_with(CONFLICT_START),
            "{}",
            second_problem
        );
        let listed = find_listed(&listing, &approval_id);
        prop_assert_eq!(listed.len(), 1);
        let kept_decision = &listed[0]["approval"]["decision"]["decision"];
        prop_assert_eq!(kept_decision, &json!(first));
    }

    #[test]
    fn test_build_approvals_view_property_waiting_count_matches_the_list(
        targets in prop::collection::vec(TARGET_PATTERN, 0..MOST_APPROVALS),
    ) {
        let prepared = shared_workspace()?;
        for target in &targets {
            create_deploy_approval(&prepared.device, target).map_err(fail)?;
        }

        let listing = list_approvals(&prepared.device).map_err(fail)?;

        let views = list_views(&listing);
        let waiting = count_waiting(&listing);
        prop_assert_eq!(&listing["waiting_count"], &json!(waiting));
        for view in &views {
            let is_undecided = view["approval"]["decision"].is_null();
            prop_assert_eq!(&view["is_waiting"], &json!(is_undecided));
        }
    }

    #[test]
    fn test_build_approvals_view_property_lists_each_approval_once(
        targets in prop::collection::vec(TARGET_PATTERN, 1..MOST_APPROVALS),
    ) {
        let prepared = shared_workspace()?;
        let mut created_ids = Vec::new();
        for target in &targets {
            let created = create_deploy_approval(&prepared.device, target)
                .map_err(fail)?;
            created_ids.push(read_text(&created, "/id").map_err(fail)?);
        }

        let listing = list_approvals(&prepared.device).map_err(fail)?;

        for (approval_id, target) in created_ids.iter().zip(&targets) {
            let listed = find_listed(&listing, approval_id);
            prop_assert_eq!(listed.len(), 1);
            let expected_description = format!("Deploy to {target}");
            let description = &listed[0]["description"];
            prop_assert_eq!(description, &json!(expected_description));
            prop_assert_eq!(&listed[0]["skill_change"], &Value::Null);
        }
    }

    #[test]
    fn test_build_approvals_view_property_each_decision_ends_one_wait(
        targets in prop::collection::vec(TARGET_PATTERN, 1..MOST_APPROVALS),
        decided_count in 0..MOST_APPROVALS,
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let device = &prepared.device;
        let mut created_ids = Vec::new();
        for target in &targets {
            let created =
                create_deploy_approval(device, target).map_err(fail)?;
            created_ids.push(read_text(&created, "/id").map_err(fail)?);
        }
        let before = list_approvals(device).map_err(fail)?;
        let decided_ids: Vec<&String> =
            created_ids.iter().take(decided_count).collect();

        for approval_id in &decided_ids {
            decide(device, approval_id, DECISION_NAMES[0]).map_err(fail)?;
        }
        let after = list_approvals(device).map_err(fail)?;

        let waiting_before = count_waiting(&before);
        prop_assert_eq!(waiting_before, created_ids.len());
        let waiting_after = count_waiting(&after);
        prop_assert_eq!(waiting_after, waiting_before - decided_ids.len());
        for approval_id in &decided_ids {
            let listed = find_listed(&after, approval_id);
            prop_assert_eq!(&listed[0]["is_waiting"], &json!(false));
        }
    }

    #[test]
    fn test_approvals_view_property_has_the_dart_fields(
        target in TARGET_PATTERN,
    ) {
        let prepared = shared_workspace()?;
        create_deploy_approval(&prepared.device, &target).map_err(fail)?;

        let listing = list_approvals(&prepared.device).map_err(fail)?;

        let listing_keys = list_object_keys(&listing);
        prop_assert_eq!(listing_keys, sorted_texts(&DART_APPROVALS_FIELDS));
        prop_assert!(listing["waiting_count"].is_u64());
    }

    #[test]
    fn test_approval_view_property_has_the_dart_fields(
        target in TARGET_PATTERN,
    ) {
        let prepared = shared_workspace()?;
        create_deploy_approval(&prepared.device, &target).map_err(fail)?;

        let listing = list_approvals(&prepared.device).map_err(fail)?;

        let views = list_views(&listing);
        prop_assert!(!views.is_empty());
        for view in &views {
            let view_keys = list_object_keys(view);
            prop_assert_eq!(&view_keys, &sorted_texts(&DART_APPROVAL_FIELDS));
            prop_assert!(view["description"].is_string());
            prop_assert!(view["is_waiting"].is_boolean());
        }
    }
}
