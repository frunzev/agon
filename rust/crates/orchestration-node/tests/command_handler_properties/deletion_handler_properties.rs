use proptest::prelude::*;
use serde_json::{Value, json};

use crate::command_shapes::{CommandShape, DELETION_SHAPES};
use crate::handler_desk::{
    HANDLER_CASES, NO_ACCOUNT_KIND, NO_ACCOUNT_PROBLEM, NOT_FOUND_START,
    create_workspace, name_strategy, read_error_kind, read_problem,
    read_reply_problem, shared_fresh_device, shared_workspace,
    uuid_text_strategy,
};
use crate::shape_checks::shape_strategy;
use crate::support::command_builders::{
    create_project_command, prepare_workspace,
};
use crate::support::test_device::{TestDevice, fail, read_text};

const MOST_PROJECTS: usize = 3;
const DELETED_KINDS: [(&str, &str); 4] = [
    ("delete_project", "project"),
    ("delete_workflow", "workflow"),
    ("delete_task", "task"),
    ("delete_workspace", "workspace"),
];

fn build_deletion(shape: CommandShape, identifier: &str) -> Value {
    let mut command = shape.build_command();
    for (field, _) in shape.fields {
        command[*field] = json!(identifier);
    }
    command
}

fn name_deleted_kind(shape: CommandShape) -> &'static str {
    let mut deleted_kind = "";
    for (name, kind) in DELETED_KINDS {
        if name == shape.name {
            deleted_kind = kind;
        }
    }
    deleted_kind
}

fn list_project_ids(
    device: &TestDevice,
    workspace_id: &str,
) -> Result<Vec<Value>, String> {
    let views = device.run(&json!({
        "command": "list_projects",
        "workspace_id": workspace_id,
    }))?;
    let mut project_ids = Vec::new();
    for view in views.as_array().cloned().unwrap_or_default() {
        project_ids.push(view["project"]["id"].clone());
    }
    Ok(project_ids)
}

fn list_workspace_ids(device: &TestDevice) -> Result<Vec<String>, String> {
    let views = device.run(&json!({ "command": "list_workspaces" }))?;
    let mut workspace_ids = Vec::new();
    for view in views.as_array().cloned().unwrap_or_default() {
        workspace_ids.push(read_text(&view, "/workspace/id")?);
    }
    Ok(workspace_ids)
}

fn delete_project(
    device: &TestDevice,
    project_id: &str,
) -> Result<Value, String> {
    device.run(&json!({
        "command": "delete_project",
        "project_id": project_id,
    }))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HANDLER_CASES))]

    #[test]
    fn test_handle_deletion_command_property_no_account_names_its_kind(
        shape in shape_strategy(&DELETION_SHAPES),
        identifier in uuid_text_strategy(),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&build_deletion(shape, &identifier));

        prop_assert_eq!(read_reply_problem(&reply), NO_ACCOUNT_PROBLEM);
        prop_assert_eq!(read_error_kind(&reply), Some(NO_ACCOUNT_KIND));
    }

    #[test]
    fn test_handle_deletion_command_property_unknown_ids_are_not_found(
        shape in shape_strategy(&DELETION_SHAPES),
        identifier in uuid_text_strategy(),
    ) {
        let prepared = shared_workspace()?;

        let reply = prepared.device.send(&build_deletion(shape, &identifier));

        let problem = read_reply_problem(&reply);
        let missing_text =
            format!("the {} was not found", name_deleted_kind(shape));
        prop_assert!(problem.starts_with(NOT_FOUND_START), "{}", problem);
        prop_assert!(problem.ends_with(&missing_text), "{}", problem);
        prop_assert_eq!(read_error_kind(&reply), None);
    }

    #[test]
    fn test_handle_deletion_command_property_deletes_only_the_chosen_project(
        project_count in 1_usize..=MOST_PROJECTS,
        chosen in any::<prop::sample::Index>(),
    ) {
        let prepared = shared_workspace()?;
        let device = &prepared.device;
        let workspace_id = &prepared.workspace_id;
        let mut created_ids = Vec::new();
        for _ in 0..project_count {
            let project = device
                .run(&create_project_command(workspace_id))
                .map_err(fail)?;
            created_ids.push(read_text(&project, "/id").map_err(fail)?);
        }
        let deleted_id = created_ids[chosen.index(project_count)].clone();

        let first = delete_project(device, &deleted_id);
        let listed = list_project_ids(device, workspace_id).map_err(fail)?;
        let second = read_problem(delete_project(device, &deleted_id));

        prop_assert_eq!(first, Ok(Value::Null));
        for created_id in &created_ids {
            let is_listed = listed.contains(&json!(created_id));
            prop_assert_eq!(is_listed, created_id != &deleted_id);
        }
        prop_assert!(second.starts_with(NOT_FOUND_START), "{}", second);
    }

    #[test]
    fn test_handle_deletion_command_property_a_workspace_leaves_the_rest(
        workspace_name in name_strategy(),
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let device = &prepared.device;
        let workspace_id =
            create_workspace(device, &workspace_name).map_err(fail)?;
        let before = list_workspace_ids(device).map_err(fail)?;

        let deleted = device.run(&json!({
            "command": "delete_workspace",
            "workspace_id": workspace_id,
        }));
        let after = list_workspace_ids(device).map_err(fail)?;

        prop_assert_eq!(deleted, Ok(Value::Null));
        prop_assert!(before.contains(&workspace_id));
        prop_assert!(!after.contains(&workspace_id));
        prop_assert!(after.contains(&prepared.workspace_id));
        prop_assert_eq!(after.len() + 1, before.len());
    }
}
