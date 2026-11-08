use orchestration_core::device::DeviceRole;
use orchestration_node::node_error::NodeError;
use orchestration_node::runner_bridge::check_reader_access;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::role_device::{
    CLIENT_ROLE_NAMES, ROLE_NAMES, RUNNER_ROLE_NAMES, RoleDevice,
};
use crate::support::file_reader_samples::{
    ADDRESS, ReaderShape, build_device, project, reader_shape, reference,
};
use crate::support::test_device::fail;

const NODE_CASE_COUNT: u32 = 4;
const MOST_EXTRA_WORKSPACES: usize = 3;
const WORKSPACE_NAME_PATTERN: &str = "[a-z]{3,12}";

fn may_read_files(shape: ReaderShape) -> Result<bool, TestCaseError> {
    let device = build_device(shape, 1).map_err(fail)?;
    let verdict =
        check_reader_access(&device, &[project()], &reference(ADDRESS));
    if let Err(problem) = &verdict {
        let is_untrusted = matches!(problem, NodeError::UntrustedFileReader);
        prop_assert!(is_untrusted, "{:?}", problem);
    }
    Ok(verdict.is_ok())
}

fn with_role(shape: ReaderShape, role: DeviceRole) -> ReaderShape {
    ReaderShape { role, ..shape }
}

fn read_runner_counts(device: &RoleDevice) -> Result<Vec<Value>, String> {
    let mut runner_counts = Vec::new();
    for view in device.list("list_workspaces")? {
        runner_counts.push(view["runner_count"].clone());
    }
    Ok(runner_counts)
}

proptest! {
    #[test]
    fn test_can_decide_approvals_property_follows_the_client_role(
        shape in reader_shape(),
    ) {
        let has_client_part = matches!(
            shape.role,
            DeviceRole::Client | DeviceRole::ClientAndRunner
        );

        let may_read = may_read_files(shape)?;

        let expected = has_client_part && !shape.revoked && shape.in_workspace;
        prop_assert_eq!(may_read, expected);
    }

    #[test]
    fn test_can_decide_approvals_property_a_runner_alone_never_decides(
        shape in reader_shape(),
    ) {
        let runner_shape = with_role(shape, DeviceRole::Runner);

        prop_assert!(!may_read_files(runner_shape)?);
    }

    #[test]
    fn test_can_decide_approvals_property_adding_a_client_part_only_grants(
        shape in reader_shape(),
    ) {
        let as_client = may_read_files(with_role(shape, DeviceRole::Client))?;
        let as_both =
            may_read_files(with_role(shape, DeviceRole::ClientAndRunner))?;
        let as_runner = may_read_files(with_role(shape, DeviceRole::Runner))?;

        prop_assert_eq!(as_client, as_both);
        prop_assert!(as_both || !as_runner);
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NODE_CASE_COUNT))]

    #[test]
    fn test_can_run_tasks_property_only_runner_roles_are_counted(
        role in prop::sample::select(ROLE_NAMES.to_vec()),
    ) {
        let device = RoleDevice::start(role).map_err(fail)?;

        let runner_counts = read_runner_counts(&device).map_err(fail)?;

        let expected = usize::from(RUNNER_ROLE_NAMES.contains(&role));
        prop_assert_eq!(runner_counts, vec![json!(expected)]);
    }

    #[test]
    fn test_can_run_tasks_property_every_new_workspace_counts_alike(
        role in prop::sample::select(CLIENT_ROLE_NAMES.to_vec()),
        workspace_names in prop::collection::vec(
            WORKSPACE_NAME_PATTERN,
            1..MOST_EXTRA_WORKSPACES,
        ),
    ) {
        let device = RoleDevice::start(role).map_err(fail)?;
        for workspace_name in &workspace_names {
            device
                .run(&json!({
                    "command": "create_workspace",
                    "name": workspace_name,
                }))
                .map_err(fail)?;
        }

        let runner_counts = read_runner_counts(&device).map_err(fail)?;

        let expected = usize::from(RUNNER_ROLE_NAMES.contains(&role));
        prop_assert_eq!(runner_counts.len(), workspace_names.len() + 1);
        for runner_count in &runner_counts {
            prop_assert_eq!(runner_count, &json!(expected));
        }
    }

    #[test]
    fn test_can_run_tasks_property_matches_the_listed_device_roles(
        role in prop::sample::select(ROLE_NAMES.to_vec()),
    ) {
        let device = RoleDevice::start(role).map_err(fail)?;

        let workspace_views = device.list("list_workspaces").map_err(fail)?;
        let device_views = device.list("list_devices").map_err(fail)?;

        for workspace_view in &workspace_views {
            let workspace_id = &workspace_view["workspace"]["id"];
            let mut listed_runners = 0_usize;
            for device_view in &device_views {
                let listed = &device_view["device"];
                let is_member = listed["workspaces"]
                    .as_array()
                    .is_some_and(|members| members.contains(workspace_id));
                let listed_role = listed["role"].as_str().unwrap_or_default();
                let runs_tasks = RUNNER_ROLE_NAMES.contains(&listed_role);
                if is_member && runs_tasks && listed["revoked"] == json!(false)
                {
                    listed_runners += 1;
                }
            }
            prop_assert_eq!(
                &workspace_view["runner_count"],
                &json!(listed_runners)
            );
        }
    }
}
