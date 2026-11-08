use orchestration_core::identifiers::ProjectId;
use orchestration_core::scope::ProjectScope;
use orchestration_node::item_drafting::{
    CheckedDraft, DraftingContext, ItemDraft, WorkDraft, check_item_draft,
};
use proptest::prelude::*;

use crate::support::draft_problem_texts::{
    join_choices, join_names, list_project_names,
};
use crate::support::drafting_samples::{
    SAMPLE_WORKSPACE_NAME, context_strategy, foreign_uuid, sample_project,
    valid_rule_draft, valid_work_draft,
};
use crate::support::entity_strategies::secret_text_strategy;

const PROJECT_CASES: u32 = 48;
const PROJECT_LABEL: &str = "Project: ";
const SCOPE_LABEL: &str = "Applies to: ";
const ALL_PROJECTS_CHOICE: &str = "all projects";
const MOST_EXTRA_PROJECTS: usize = 3;

fn check_task(context: &DraftingContext, work: WorkDraft) -> CheckedDraft {
    check_item_draft(context, &ItemDraft::Task(work))
}

fn read_project_id(checked: &CheckedDraft) -> Option<ProjectId> {
    match &checked.draft {
        ItemDraft::Task(work) | ItemDraft::Job(work) => work.project_id,
        _ => None,
    }
}

fn foreign_project_sentence(context: &DraftingContext) -> String {
    format!(
        "Project: the chosen one is not in {SAMPLE_WORKSPACE_NAME}. Ask for \
         changes and name one of: {}.",
        join_names(&list_project_names(context))
    )
}

fn missing_project_sentence(context: &DraftingContext) -> String {
    format!(
        "Project: the agent could not tell which one. Ask for changes and \
         name one of: {}.",
        join_names(&list_project_names(context))
    )
}

fn with_extra_projects(
    context: &DraftingContext,
    extra_count: usize,
) -> DraftingContext {
    let mut widened = context.clone();
    let first_index = widened.projects.len();
    for index in first_index..first_index + extra_count {
        let name = format!("extra-{index}");
        let address = format!("github.com/extra/repo-{index}");
        widened
            .projects
            .push(sample_project(index, &name, &address));
    }
    widened
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROJECT_CASES))]

    #[test]
    fn test_includes_project_property_a_listed_project_is_accepted(
        context in context_strategy(),
        words in secret_text_strategy(),
        chosen_index in any::<prop::sample::Index>(),
    ) {
        let chosen = chosen_index.get(&context.projects).id;
        let mut work = valid_work_draft(&context, &words, &words);
        work.project_id = Some(chosen);

        let checked = check_task(&context, work);

        prop_assert!(checked.problems.is_empty(), "{:?}", checked.problems);
        prop_assert_eq!(read_project_id(&checked), Some(chosen));
    }

    #[test]
    fn test_includes_project_property_a_foreign_project_is_refused(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let mut work = valid_work_draft(&context, &words, &words);
        work.project_id = Some(ProjectId(foreign_uuid()));

        let checked = check_task(&context, work);

        let expected = vec![foreign_project_sentence(&context)];
        prop_assert_eq!(checked.problems, expected);
    }

    #[test]
    fn test_includes_project_property_a_rule_scope_needs_listed_projects(
        context in context_strategy(),
        words in secret_text_strategy(),
        adds_foreign in any::<bool>(),
    ) {
        let mut rule = valid_rule_draft(&context, &words);
        if adds_foreign {
            rule.scope.projects = ProjectScope::OnlyProjects {
                projects: vec![
                    context.projects[0].id,
                    ProjectId(foreign_uuid()),
                ],
            };
        }

        let checked = check_item_draft(&context, &ItemDraft::Rule(rule));

        let scope_problems: Vec<&String> = checked
            .problems
            .iter()
            .filter(|problem| problem.starts_with(SCOPE_LABEL))
            .collect();
        prop_assert_eq!(scope_problems.len(), usize::from(adds_foreign));
        prop_assert_eq!(checked.problems.len(), usize::from(adds_foreign));
    }

    #[test]
    fn test_find_only_project_id_property_the_only_project_fills_the_gap(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let mut context = context;
        context.projects.truncate(1);
        let mut work = valid_work_draft(&context, &words, &words);
        work.project_id = None;

        let checked = check_task(&context, work);

        let only_project_id = context.projects[0].id;
        prop_assert_eq!(read_project_id(&checked), Some(only_project_id));
        prop_assert!(checked.problems.is_empty(), "{:?}", checked.problems);
    }

    #[test]
    fn test_find_only_project_id_property_several_projects_stay_unchosen(
        context in context_strategy(),
        words in secret_text_strategy(),
        extra_count in 1..MOST_EXTRA_PROJECTS,
    ) {
        let widened = with_extra_projects(&context, extra_count);
        let mut work = valid_work_draft(&widened, &words, &words);
        work.project_id = None;

        let checked = check_task(&widened, work);

        prop_assert_eq!(read_project_id(&checked), None);
        let expected = vec![missing_project_sentence(&widened)];
        prop_assert_eq!(checked.problems, expected);
    }

    #[test]
    fn test_find_only_project_id_property_an_answered_project_is_kept(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let mut context = context;
        context.projects.truncate(1);
        let foreign = ProjectId(foreign_uuid());
        let mut work = valid_work_draft(&context, &words, &words);
        work.project_id = Some(foreign);

        let checked = check_task(&context, work);

        prop_assert_eq!(read_project_id(&checked), Some(foreign));
        let expected = vec![foreign_project_sentence(&context)];
        prop_assert_eq!(checked.problems, expected);
    }

    #[test]
    fn test_list_project_names_property_names_every_project_in_order(
        context in context_strategy(),
        words in secret_text_strategy(),
        extra_count in 1..MOST_EXTRA_PROJECTS,
    ) {
        let widened = with_extra_projects(&context, extra_count);
        let mut work = valid_work_draft(&widened, &words, &words);
        work.project_id = None;

        let checked = check_task(&widened, work);

        let problem = checked.problems.first().cloned().unwrap_or_default();
        prop_assert!(problem.starts_with(PROJECT_LABEL), "{}", problem);
        let names = join_names(&list_project_names(&widened));
        let listed = format!("name one of: {names}.");
        prop_assert!(problem.ends_with(&listed), "{}", problem);
    }

    #[test]
    fn test_list_project_names_property_scope_choices_end_with_all_projects(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let mut rule = valid_rule_draft(&context, &words);
        rule.scope.projects = ProjectScope::OnlyProjects {
            projects: vec![ProjectId(foreign_uuid())],
        };

        let checked = check_item_draft(&context, &ItemDraft::Rule(rule));

        let choices =
            join_choices(list_project_names(&context), ALL_PROJECTS_CHOICE);
        let expected = format!(
            "Applies to: a chosen project is not in {SAMPLE_WORKSPACE_NAME}. \
             Ask for changes and name one of: {choices}."
        );
        prop_assert_eq!(checked.problems, vec![expected]);
    }

    #[test]
    fn test_list_project_names_property_no_projects_asks_to_add_one(
        context in context_strategy(),
        words in secret_text_strategy(),
        is_foreign in any::<bool>(),
    ) {
        let mut work = valid_work_draft(&context, &words, &words);
        let mut context = context;
        context.projects.clear();
        work.project_id = is_foreign.then(|| ProjectId(foreign_uuid()));

        let checked = check_task(&context, work);

        let expected = format!(
            "Project: {SAMPLE_WORKSPACE_NAME} has no projects yet. Add a \
             project first, then draft this again."
        );
        prop_assert_eq!(checked.problems, vec![expected]);
    }
}
