use proptest::prelude::*;
use serde_json::{Value, json};

use crate::handler_desk::{
    HANDLER_CASES, POST_METHOD, count_requests_to, create_workspace,
    list_object_keys, name_strategy, read_own_device_id, read_problem,
    shared_workspace, sorted_texts,
};
use crate::support::command_builders::{
    create_project_command, prepare_workspace,
};
use crate::support::test_device::{TestDevice, fail, read_text};
use crate::support::test_server::TestServer;

const DART_DEVICE_VIEW_FIELDS: [&str; 4] = [
    "device",
    "is_this_device",
    "workspace_names",
    "peer_address_verified",
];
const DART_DEVICE_FIELDS: [&str; 11] = [
    "id",
    "name",
    "role",
    "kind",
    "key_kind",
    "signing_public_key",
    "sealing_public_key",
    "workspaces",
    "paired_at",
    "last_seen",
    "revoked",
];
const DART_WORKSPACE_VIEW_FIELDS: [&str; 3] =
    ["workspace", "project_count", "runner_count"];
const ROLE_NAMES: [&str; 3] = ["client", "runner", "client_and_runner"];
const MOST_PROJECTS: usize = 3;
const INVALID_NAME_PATTERN: &str =
    "|[A-Z ]{1,8}|[a-z]{41,48}|[a-z]{1,4}[_./ \u{e9}][a-z]{0,4}";
const WORKSPACES_PATH: &str = "/workspaces";
const NAME_PROBLEM_START: &str = "a name ";

fn list_views(device: &TestDevice, name: &str) -> Result<Vec<Value>, String> {
    let listed = device.run(&json!({ "command": name }))?;
    Ok(listed.as_array().cloned().unwrap_or_default())
}

fn find_view<'views>(
    views: &'views [Value],
    pointer: &str,
    identifier: &str,
) -> Option<&'views Value> {
    let wanted = json!(identifier);
    views
        .iter()
        .find(|view| view.pointer(pointer) == Some(&wanted))
}

fn start_device_with_role(
    role: &str,
) -> Result<(TestServer, TestDevice), String> {
    let server = TestServer::start()?;
    let device = TestDevice::start()?;
    device.create_account_with_role(&server, "acme", role)?;
    Ok((server, device))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HANDLER_CASES))]

    #[test]
    fn test_build_device_views_property_one_view_is_this_device(
        _seed in any::<u8>(),
    ) {
        let prepared = shared_workspace()?;
        let own_device_id =
            read_own_device_id(&prepared.device).map_err(fail)?;

        let views = list_views(&prepared.device, "list_devices")
            .map_err(fail)?;

        let mut own_views = Vec::new();
        for view in &views {
            if view["is_this_device"] == json!(true) {
                own_views.push(view["device"]["id"].clone());
            }
        }
        prop_assert_eq!(own_views, vec![json!(own_device_id)]);
    }

    #[test]
    fn test_build_device_views_property_names_the_member_workspaces(
        workspace_names in prop::collection::vec(name_strategy(), 0..3),
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        for workspace_name in &workspace_names {
            create_workspace(&prepared.device, workspace_name)
                .map_err(fail)?;
        }

        let device_views = list_views(&prepared.device, "list_devices")
            .map_err(fail)?;
        let workspace_views = list_views(&prepared.device, "list_workspaces")
            .map_err(fail)?;

        for device_view in &device_views {
            let member_of = &device_view["device"]["workspaces"];
            let mut expected_names = Vec::new();
            for workspace_view in &workspace_views {
                let workspace = &workspace_view["workspace"];
                let is_member = member_of
                    .as_array()
                    .is_some_and(|ids| ids.contains(&workspace["id"]));
                if is_member {
                    expected_names.push(workspace["name"].clone());
                }
            }
            prop_assert_eq!(
                &device_view["workspace_names"],
                &Value::Array(expected_names)
            );
        }
        prop_assert_eq!(workspace_views.len(), workspace_names.len() + 1);
    }

    #[test]
    fn test_device_view_property_has_the_dart_fields(_seed in any::<u8>()) {
        let prepared = shared_workspace()?;

        let views = list_views(&prepared.device, "list_devices")
            .map_err(fail)?;

        prop_assert!(!views.is_empty());
        for view in &views {
            let view_keys = list_object_keys(view);
            let dart_keys = sorted_texts(&DART_DEVICE_VIEW_FIELDS);
            prop_assert_eq!(&view_keys, &dart_keys);
            let device_keys = list_object_keys(&view["device"]);
            for dart_field in DART_DEVICE_FIELDS {
                let is_sent = device_keys.iter().any(|key| key == dart_field);
                prop_assert!(is_sent, "{}", dart_field);
            }
            prop_assert!(view["peer_address_verified"].is_boolean());
        }
    }

    #[test]
    fn test_build_workspace_views_property_counts_each_workspace_projects(
        project_count in 0..=MOST_PROJECTS,
        workspace_name in name_strategy(),
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let device = &prepared.device;
        let workspace_id =
            create_workspace(device, &workspace_name).map_err(fail)?;
        for _ in 0..project_count {
            device
                .run(&create_project_command(&workspace_id))
                .map_err(fail)?;
        }

        let views = list_views(device, "list_workspaces").map_err(fail)?;

        let created = find_view(&views, "/workspace/id", &workspace_id);
        let first = find_view(&views, "/workspace/id", &prepared.workspace_id);
        let created_count = created.map(|view| view["project_count"].clone());
        let first_count = first.map(|view| view["project_count"].clone());
        prop_assert_eq!(created_count, Some(json!(project_count)));
        prop_assert_eq!(first_count, Some(json!(1)));
    }

    #[test]
    fn test_build_workspace_views_property_counts_only_runner_roles(
        role in prop::sample::select(ROLE_NAMES.to_vec()),
    ) {
        let (_server, device) = start_device_with_role(role).map_err(fail)?;

        let views = list_views(&device, "list_workspaces").map_err(fail)?;

        let expected_count = usize::from(role != "client");
        prop_assert_eq!(views.len(), 1);
        prop_assert_eq!(&views[0]["runner_count"], &json!(expected_count));
    }

    #[test]
    fn test_workspace_view_property_has_the_dart_fields(_seed in any::<u8>()) {
        let prepared = shared_workspace()?;

        let views = list_views(&prepared.device, "list_workspaces")
            .map_err(fail)?;

        let mut workspace_ids = Vec::new();
        for view in &views {
            let view_keys = list_object_keys(view);
            let dart_keys = sorted_texts(&DART_WORKSPACE_VIEW_FIELDS);
            prop_assert_eq!(&view_keys, &dart_keys);
            let workspace_id =
                read_text(view, "/workspace/id").map_err(fail)?;
            workspace_ids.push(workspace_id);
        }
        let listed_count = workspace_ids.len();
        workspace_ids.sort();
        workspace_ids.dedup();
        prop_assert_eq!(workspace_ids.len(), listed_count);
    }

    #[test]
    fn test_create_workspace_property_bad_names_never_reach_the_server(
        bad_name in INVALID_NAME_PATTERN,
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let creations_before =
            count_requests_to(&prepared.server, POST_METHOD, WORKSPACES_PATH);

        let problem = read_problem(prepared.device.run(&json!({
            "command": "create_workspace",
            "name": bad_name,
        })));

        prop_assert!(problem.starts_with(NAME_PROBLEM_START), "{}", problem);
        let creations_after =
            count_requests_to(&prepared.server, POST_METHOD, WORKSPACES_PATH);
        prop_assert_eq!(creations_after, creations_before);
    }

    #[test]
    fn test_create_workspace_property_the_new_key_is_kept(
        workspace_name in name_strategy(),
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let device = &prepared.device;

        let workspace_id =
            create_workspace(device, &workspace_name).map_err(fail)?;
        let project = device.run(&create_project_command(&workspace_id));

        let project_workspace = project
            .and_then(|created| read_text(&created, "/workspace_id"));
        prop_assert_eq!(project_workspace, Ok(workspace_id));
    }

    #[test]
    fn test_create_workspace_property_a_repeated_name_gets_a_new_id(
        workspace_name in name_strategy(),
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let device = &prepared.device;

        let first = create_workspace(device, &workspace_name).map_err(fail)?;
        let second = create_workspace(device, &workspace_name).map_err(fail)?;
        let views = list_views(device, "list_workspaces").map_err(fail)?;

        prop_assert_ne!(&first, &second);
        prop_assert!(find_view(&views, "/workspace/id", &first).is_some());
        prop_assert!(find_view(&views, "/workspace/id", &second).is_some());
    }
}
