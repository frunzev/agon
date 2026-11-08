use proptest::prelude::*;
use serde_json::json;

use crate::drafting_context_steps::{
    DRAFTING_CASES, DRAFTING_DEVICE_NAME, FIRST_WORKSPACE_NAME,
    SECTION_HEADINGS, draft_command, open_drafting_table,
};
use crate::handler_desk::{
    POST_METHOD, count_requests_to, create_workspace, name_strategy,
    read_own_device_id, read_problem, uuid_text_strategy,
};
use crate::support::test_device::fail;

const TASKS_PATH: &str = "/tasks";
const MOST_WORKSPACES: usize = 3;

fn count_lines_starting(prompt: &str, start: &str) -> usize {
    prompt
        .lines()
        .filter(|line| line.starts_with(start))
        .count()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DRAFTING_CASES))]

    #[test]
    fn test_read_drafting_context_property_an_unknown_workspace_queues_nothing(
        workspace_id in uuid_text_strategy(),
    ) {
        let table = open_drafting_table(DRAFTING_DEVICE_NAME).map_err(fail)?;
        let server = &table.server;
        let tasks_before = count_requests_to(server, POST_METHOD, TASKS_PATH);

        let problem = read_problem(table.run(&draft_command(&workspace_id)));

        let expected = format!("workspace {workspace_id} was not found");
        prop_assert_eq!(problem, expected);
        let tasks_after = count_requests_to(server, POST_METHOD, TASKS_PATH);
        prop_assert_eq!(tasks_after, tasks_before);
    }

    #[test]
    fn test_read_drafting_context_property_names_workspace_and_computer(
        workspace_name in name_strategy(),
    ) {
        let table = open_drafting_table(DRAFTING_DEVICE_NAME).map_err(fail)?;
        let workspace_id =
            create_workspace(&table.device, &workspace_name)
                .map_err(fail)?;
        let device_id =
            read_own_device_id(&table.device).map_err(fail)?;

        let prompt = table.read_drafting_prompt(&workspace_id).map_err(fail)?;

        let workspace_line =
            format!("Workspace: {workspace_name} (id {workspace_id})");
        let device_line =
            format!("This computer: {DRAFTING_DEVICE_NAME} (id {device_id})");
        prop_assert!(prompt.contains(&workspace_line), "{}", prompt);
        prop_assert!(prompt.contains(&device_line), "{}", prompt);
    }

    #[test]
    fn test_read_drafting_context_property_each_section_once_in_order(
        workspace_name in name_strategy(),
    ) {
        let table = open_drafting_table(DRAFTING_DEVICE_NAME).map_err(fail)?;
        let workspace_id =
            create_workspace(&table.device, &workspace_name)
                .map_err(fail)?;

        let prompt = table.read_drafting_prompt(&workspace_id).map_err(fail)?;

        let mut last_position = 0;
        for heading in SECTION_HEADINGS {
            prop_assert_eq!(count_lines_starting(&prompt, heading), 1);
            let position = prompt.find(heading).unwrap_or_default();
            prop_assert!(position > last_position, "{}", prompt);
            last_position = position;
        }
    }

    #[test]
    fn test_read_workspace_property_picks_the_drafting_workspace(
        workspace_names in
            prop::collection::vec(name_strategy(), 1..MOST_WORKSPACES),
        chosen in any::<prop::sample::Index>(),
    ) {
        let table = open_drafting_table(DRAFTING_DEVICE_NAME).map_err(fail)?;
        let mut workspace_ids = Vec::new();
        for workspace_name in &workspace_names {
            let workspace_id =
                create_workspace(&table.device, workspace_name)
                    .map_err(fail)?;
            workspace_ids.push(workspace_id);
        }
        let chosen_position = chosen.index(workspace_ids.len());
        let chosen_id = &workspace_ids[chosen_position];

        let prompt = table.read_drafting_prompt(chosen_id).map_err(fail)?;

        prop_assert_eq!(count_lines_starting(&prompt, "Workspace: "), 1);
        for workspace_id in &workspace_ids {
            let is_named = prompt.contains(&format!("(id {workspace_id})"));
            prop_assert_eq!(is_named, workspace_id == chosen_id);
        }
    }

    #[test]
    fn test_read_workspace_property_a_deleted_workspace_is_not_found(
        workspace_name in name_strategy(),
    ) {
        let table = open_drafting_table(DRAFTING_DEVICE_NAME).map_err(fail)?;
        let workspace_id =
            create_workspace(&table.device, &workspace_name)
                .map_err(fail)?;
        table
            .run(&json!({
                "command": "delete_workspace",
                "workspace_id": workspace_id,
            }))
            .map_err(fail)?;

        let problem = read_problem(table.run(&draft_command(&workspace_id)));

        let expected = format!("workspace {workspace_id} was not found");
        prop_assert_eq!(problem, expected);
    }

    #[test]
    fn test_read_workspace_property_the_first_workspace_stays_findable(
        workspace_names in
            prop::collection::vec(name_strategy(), 0..MOST_WORKSPACES),
    ) {
        let table = open_drafting_table(DRAFTING_DEVICE_NAME).map_err(fail)?;
        for workspace_name in &workspace_names {
            create_workspace(&table.device, workspace_name)
                .map_err(fail)?;
        }
        let first_id = table.workspace_id.clone();

        let prompt = table.read_drafting_prompt(&first_id).map_err(fail)?;

        let first_line =
            format!("Workspace: {FIRST_WORKSPACE_NAME} (id {first_id})");
        prop_assert!(prompt.contains(&first_line), "{}", prompt);
    }

    #[test]
    fn test_drafting_find_device_property_shows_the_chosen_device_name(
        device_name in name_strategy(),
    ) {
        let table = open_drafting_table(&device_name).map_err(fail)?;
        let device_id = read_own_device_id(&table.device).map_err(fail)?;

        let prompt =
            table.read_drafting_prompt(&table.workspace_id).map_err(fail)?;

        let device_line =
            format!("This computer: {device_name} (id {device_id})");
        prop_assert!(prompt.contains(&device_line), "{}", prompt);
    }

    #[test]
    fn test_drafting_find_device_property_names_this_computer_once(
        workspace_name in name_strategy(),
    ) {
        let table = open_drafting_table(DRAFTING_DEVICE_NAME).map_err(fail)?;
        let workspace_id =
            create_workspace(&table.device, &workspace_name)
                .map_err(fail)?;
        let device_id =
            read_own_device_id(&table.device).map_err(fail)?;

        let prompt = table.read_drafting_prompt(&workspace_id).map_err(fail)?;

        prop_assert_eq!(count_lines_starting(&prompt, "This computer: "), 1);
        let computer_line = prompt
            .lines()
            .find(|line| line.starts_with("This computer: "))
            .unwrap_or_default();
        let device_marker = format!("(id {device_id})");
        prop_assert!(computer_line.ends_with(&device_marker), "{}", prompt);
    }

    #[test]
    fn test_drafting_find_device_property_comes_before_the_sections(
        workspace_name in name_strategy(),
    ) {
        let table = open_drafting_table(DRAFTING_DEVICE_NAME).map_err(fail)?;
        let workspace_id =
            create_workspace(&table.device, &workspace_name)
                .map_err(fail)?;

        let prompt = table.read_drafting_prompt(&workspace_id).map_err(fail)?;

        let computer_position = prompt.find("This computer: ");
        let projects_position = prompt.find(SECTION_HEADINGS[0]);
        prop_assert!(computer_position.is_some());
        prop_assert!(computer_position < projects_position, "{}", prompt);
    }
}
