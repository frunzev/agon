use orchestration_core::identifiers::ProjectId;
use orchestration_node::item_drafting::{
    DraftingContext, ItemDraft, WorkDraft,
};
use proptest::prelude::*;
use uuid::Uuid;

use crate::drafted_item_checks::{
    CHECK_CASES, check_work, is_clear_sentence, read_labelled,
    work_wrapper_strategy,
};
use crate::support::draft_problem_texts::{join_names, list_project_names};
use crate::support::drafting_samples::{
    context_strategy, foreign_uuid, sample_project, valid_work_draft,
};
use crate::work_samples::read_choices;

const PROJECT_LABEL: &str = "Project";
const WORKSPACE_NAME_PATTERN: &str = "[a-z][a-z0-9-]{0,12}";
const EXTRA_PROJECT_INDEX: usize = 9;
const EXTRA_PROJECT_NAME: &str = "extra";

fn with_project(
    context: &DraftingContext,
    project_id: Option<ProjectId>,
) -> WorkDraft {
    WorkDraft {
        project_id,
        ..valid_work_draft(context, "Ship", "Ship it")
    }
}

fn project_problem(
    context: &DraftingContext,
    project_id: Option<ProjectId>,
) -> Result<String, TestCaseError> {
    let work = with_project(context, project_id);
    let (_, problems) = check_work(context, &work, ItemDraft::Task)?;
    Ok(read_labelled(&problems, PROJECT_LABEL))
}

fn foreign_project_id(number: u128) -> ProjectId {
    ProjectId(Uuid::from_u128(number))
}

fn add_extra_project(context: &DraftingContext) -> DraftingContext {
    let mut grown = context.clone();
    grown.projects.push(sample_project(
        EXTRA_PROJECT_INDEX,
        EXTRA_PROJECT_NAME,
        "github.com/acme/extra",
    ));
    grown
}

fn without_projects(context: &DraftingContext, name: &str) -> DraftingContext {
    let mut emptied = context.clone();
    emptied.projects.clear();
    name.clone_into(&mut emptied.workspace.name);
    emptied
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_describe_missing_project_property_lists_every_project(
        context in context_strategy(),
    ) {
        let grown = add_extra_project(&context);

        let problem = project_problem(&grown, None)?;

        let expected = format!(
            "Project: the agent could not tell which one. Ask for changes \
             and name one of: {}.",
            join_names(&list_project_names(&grown))
        );
        prop_assert_eq!(problem, expected);
    }

    #[test]
    fn test_describe_missing_project_property_is_one_clear_sentence(
        context in context_strategy(),
        wrap in work_wrapper_strategy(),
    ) {
        let grown = add_extra_project(&context);
        let work = with_project(&grown, None);

        let (_, problems) = check_work(&grown, &work, wrap)?;

        let problem = read_labelled(&problems, PROJECT_LABEL);
        let is_clear = is_clear_sentence(&problem, PROJECT_LABEL);
        prop_assert!(is_clear, "{}", problem);
    }

    #[test]
    fn test_describe_missing_project_property_a_new_project_comes_last(
        context in context_strategy(),
    ) {
        prop_assume!(context.projects.len() > 1);
        let before = project_problem(&context, None)?;

        let after = project_problem(&add_extra_project(&context), None)?;

        let mut expected = read_choices(&before);
        expected.push(EXTRA_PROJECT_NAME.to_owned());
        prop_assert_eq!(read_choices(&after), expected);
    }

    #[test]
    fn test_describe_foreign_project_property_names_the_workspace(
        context in context_strategy(),
    ) {
        let problem =
            project_problem(&context, Some(ProjectId(foreign_uuid())))?;

        let expected = format!(
            "Project: the chosen one is not in {}. Ask for changes and name \
             one of: {}.",
            context.workspace.name,
            join_names(&list_project_names(&context))
        );
        prop_assert_eq!(problem, expected);
    }

    #[test]
    fn test_describe_foreign_project_property_never_shows_the_id(
        context in context_strategy(),
        number in any::<u128>(),
    ) {
        let foreign_id = foreign_project_id(number);
        let is_listed =
            context.projects.iter().any(|project| project.id == foreign_id);
        prop_assume!(!is_listed);

        let problem = project_problem(&context, Some(foreign_id))?;

        prop_assert!(!problem.contains(&foreign_id.0.to_string()));
        prop_assert!(!problem.contains(&foreign_id.0.simple().to_string()));
    }

    #[test]
    fn test_describe_foreign_project_property_any_foreign_id_reads_alike(
        context in context_strategy(),
        numbers in (any::<u128>(), any::<u128>()),
    ) {
        let first_id = foreign_project_id(numbers.0);
        let second_id = foreign_project_id(numbers.1);
        let is_listed = context.projects.iter().any(|project| {
            project.id == first_id || project.id == second_id
        });
        prop_assume!(!is_listed);

        let first_problem = project_problem(&context, Some(first_id))?;
        let second_problem = project_problem(&context, Some(second_id))?;

        prop_assert_eq!(first_problem, second_problem);
    }

    #[test]
    fn test_describe_workspace_without_projects_property_names_it(
        context in context_strategy(),
        workspace_name in WORKSPACE_NAME_PATTERN,
    ) {
        let emptied = without_projects(&context, &workspace_name);

        let problem = project_problem(&emptied, None)?;

        let expected = format!(
            "Project: {workspace_name} has no projects yet. Add a project \
             first, then draft this again."
        );
        prop_assert_eq!(problem, expected);
    }

    #[test]
    fn test_describe_workspace_without_projects_property_missing_is_foreign(
        context in context_strategy(),
        workspace_name in WORKSPACE_NAME_PATTERN,
    ) {
        let emptied = without_projects(&context, &workspace_name);

        let missing_problem = project_problem(&emptied, None)?;
        let foreign_problem =
            project_problem(&emptied, Some(ProjectId(foreign_uuid())))?;

        prop_assert_eq!(missing_problem, foreign_problem);
    }

    #[test]
    fn test_describe_workspace_without_projects_property_offers_no_choice(
        context in context_strategy(),
        workspace_name in WORKSPACE_NAME_PATTERN,
    ) {
        let emptied = without_projects(&context, &workspace_name);

        let problem = project_problem(&emptied, None)?;

        prop_assert!(read_choices(&problem).is_empty(), "{}", problem);
        prop_assert!(is_clear_sentence(&problem, PROJECT_LABEL));
    }
}
