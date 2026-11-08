use proptest::prelude::*;
use serde_json::json;

use crate::drafting_context_steps::{
    DRAFTING_CASES, DraftingTable, EMPTY_SECTION_LINE, names_identifier,
    only_workspace_scope, open_table_or_fail, read_section,
};
use crate::handler_desk::{create_workspace, name_strategy};
use crate::support::command_builders::create_project_command;
use crate::support::test_device::{fail, read_text};

const MOST_ITEMS: usize = 3;
const SUMMARY_PATTERN: &str = "[A-Z][a-z ]{0,16}[a-z]";
const EVERYWHERE_SCOPE_KIND: &str = "all_workspaces";
const SIGNED_END: &str = ", signed";
const UNSIGNED_END: &str = ", not signed yet";

fn create_projects(
    table: &DraftingTable,
    workspace_id: &str,
    count: usize,
) -> Result<Vec<String>, String> {
    let mut project_ids = Vec::new();
    for _ in 0..count {
        let project = table.run(&create_project_command(workspace_id))?;
        project_ids.push(read_text(&project, "/id")?);
    }
    Ok(project_ids)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DRAFTING_CASES))]

    #[test]
    fn test_read_projects_property_lists_every_workspace_project(
        workspace_name in name_strategy(),
        project_count in 1..=MOST_ITEMS,
    ) {
        let table = open_table_or_fail()?;
        let workspace_id =
            create_workspace(&table.device, &workspace_name).map_err(fail)?;
        let project_ids =
            create_projects(&table, &workspace_id, project_count)
                .map_err(fail)?;

        let prompt = table.read_drafting_prompt(&workspace_id).map_err(fail)?;

        let projects = read_section(&prompt, "Projects:");
        prop_assert_eq!(projects.len(), project_count);
        for project_id in &project_ids {
            let is_named = names_identifier(&projects, project_id);
            prop_assert!(is_named, "{}", prompt);
        }
    }

    #[test]
    fn test_read_projects_property_leaves_out_other_workspaces(
        workspace_name in name_strategy(),
        other_count in 1..=MOST_ITEMS,
    ) {
        let table = open_table_or_fail()?;
        let workspace_id =
            create_workspace(&table.device, &workspace_name).map_err(fail)?;
        let first_id = &table.workspace_id;
        let other_ids =
            create_projects(&table, first_id, other_count).map_err(fail)?;

        let prompt = table.read_drafting_prompt(&workspace_id).map_err(fail)?;

        for other_id in &other_ids {
            prop_assert!(!prompt.contains(other_id.as_str()), "{}", prompt);
        }
    }

    #[test]
    fn test_read_projects_property_an_empty_workspace_says_none(
        workspace_name in name_strategy(),
    ) {
        let table = open_table_or_fail()?;
        let workspace_id =
            create_workspace(&table.device, &workspace_name).map_err(fail)?;

        let prompt = table.read_drafting_prompt(&workspace_id).map_err(fail)?;

        let projects = read_section(&prompt, "Projects:");
        prop_assert_eq!(projects, vec![EMPTY_SECTION_LINE]);
    }

    #[test]
    fn test_read_workflows_property_follows_the_availability(
        workspace_name in name_strategy(),
    ) {
        let table = open_table_or_fail()?;
        let workspace_id =
            create_workspace(&table.device, &workspace_name).map_err(fail)?;
        let everywhere = json!({ "kind": EVERYWHERE_SCOPE_KIND });
        let shared_id = table
            .create_workflow(&table.workspace_id, &everywhere)
            .map_err(fail)?;
        let elsewhere_id = table
            .create_workflow(
                &table.workspace_id,
                &only_workspace_scope(&table.workspace_id),
            )
            .map_err(fail)?;

        let prompt = table.read_drafting_prompt(&workspace_id).map_err(fail)?;

        let workflows = read_section(&prompt, "Workflows:");
        prop_assert!(names_identifier(&workflows, &shared_id), "{}", prompt);
        prop_assert!(!prompt.contains(elsewhere_id.as_str()), "{}", prompt);
    }

    #[test]
    fn test_read_workflows_property_lists_each_workflow_once(
        workflow_count in 1..=MOST_ITEMS,
    ) {
        let table = open_table_or_fail()?;
        let scope = only_workspace_scope(&table.workspace_id);
        let mut workflow_ids = Vec::new();
        for _ in 0..workflow_count {
            let workflow_id = table
                .create_workflow(&table.workspace_id, &scope)
                .map_err(fail)?;
            workflow_ids.push(workflow_id);
        }

        let prompt = table.read_first_prompt().map_err(fail)?;

        let workflows = read_section(&prompt, "Workflows:");
        prop_assert_eq!(workflows.len(), workflow_count);
        for workflow_id in &workflow_ids {
            prop_assert!(names_identifier(&workflows, workflow_id));
        }
    }

    #[test]
    fn test_read_workflows_property_shows_the_signature_state(
        is_signed in any::<bool>(),
    ) {
        let table = open_table_or_fail()?;
        let scope = only_workspace_scope(&table.workspace_id);
        let workflow_id = table
            .create_workflow(&table.workspace_id, &scope)
            .map_err(fail)?;
        if is_signed {
            table
                .run(&json!({
                    "command": "sign_workflow",
                    "workflow_id": workflow_id,
                }))
                .map_err(fail)?;
        }

        let prompt = table.read_first_prompt().map_err(fail)?;

        let workflows = read_section(&prompt, "Workflows:");
        let expected_end = if is_signed {
            SIGNED_END
        } else {
            UNSIGNED_END
        };
        prop_assert_eq!(workflows.len(), 1);
        prop_assert!(workflows[0].ends_with(expected_end), "{}", prompt);
    }

    #[test]
    fn test_read_skills_property_follows_the_skill_scope(
        workspace_name in name_strategy(),
        summary in SUMMARY_PATTERN,
    ) {
        let table = open_table_or_fail()?;
        let workspace_id =
            create_workspace(&table.device, &workspace_name).map_err(fail)?;
        let everywhere = json!({ "kind": EVERYWHERE_SCOPE_KIND });
        let shared_id = table
            .create_skill(&table.workspace_id, &everywhere, &summary)
            .map_err(fail)?;
        let elsewhere_id = table
            .create_skill(
                &table.workspace_id,
                &only_workspace_scope(&table.workspace_id),
                &summary,
            )
            .map_err(fail)?;

        let prompt = table.read_drafting_prompt(&workspace_id).map_err(fail)?;

        let skills = read_section(&prompt, "Skills:");
        prop_assert!(names_identifier(&skills, &shared_id), "{}", prompt);
        prop_assert!(!prompt.contains(elsewhere_id.as_str()), "{}", prompt);
    }

    #[test]
    fn test_read_skills_property_shows_usage_and_summary(
        summary in SUMMARY_PATTERN,
    ) {
        let table = open_table_or_fail()?;
        let scope = only_workspace_scope(&table.workspace_id);
        let skill_id = table
            .create_skill(&table.workspace_id, &scope, &summary)
            .map_err(fail)?;

        let prompt = table.read_first_prompt().map_err(fail)?;

        let skills = read_section(&prompt, "Skills:");
        let expected_end = format!("(id {skill_id}), automatic: {summary}");
        prop_assert_eq!(skills.len(), 1);
        prop_assert!(skills[0].ends_with(&expected_end), "{}", prompt);
    }

    #[test]
    fn test_read_skills_property_an_empty_library_says_none(
        workspace_name in name_strategy(),
    ) {
        let table = open_table_or_fail()?;
        let workspace_id =
            create_workspace(&table.device, &workspace_name).map_err(fail)?;

        let prompt = table.read_drafting_prompt(&workspace_id).map_err(fail)?;

        let skills = read_section(&prompt, "Skills:");
        prop_assert_eq!(skills, vec![EMPTY_SECTION_LINE]);
    }
}
