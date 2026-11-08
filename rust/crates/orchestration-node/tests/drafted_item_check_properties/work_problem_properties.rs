use orchestration_core::identifiers::{ProjectId, WorkflowId};
use orchestration_core::task::TaskDoer;
use orchestration_core::workflow::AgentKind;
use orchestration_node::item_drafting::{
    DraftingWorkflow, ItemDraft, WorkDraft,
};
use proptest::prelude::*;
use uuid::Uuid;

use crate::drafted_item_checks::{
    CHECK_CASES, check_work, count_labelled, find_labelled, is_clear_sentence,
    is_unicode_blank, work_wrapper_strategy,
};
use crate::support::draft_problem_texts::list_project_names;
use crate::support::drafting_samples::{
    context_strategy, foreign_uuid, valid_work_draft,
};
use crate::work_samples::{
    EMPTY_WORK_TITLE, WORK_LABELS, read_choices, title_strategy,
    varied_work_strategy,
};

const PROJECT_LABEL: &str = "Project";
const DOER_LABEL: &str = "Who does it";
const WORKFLOW_IDENTIFIER_BASE: u128 = 0x900;
const MOST_WORKFLOWS: usize = 4;

fn agent_kind_strategy() -> impl Strategy<Value = AgentKind> {
    prop_oneof![
        Just(AgentKind::ClaudeCode),
        Just(AgentKind::Codex),
        Just(AgentKind::GeminiCli),
    ]
}

fn drafting_workflow(index: usize, is_signed: bool) -> DraftingWorkflow {
    let offset = u128::try_from(index).unwrap_or_default();
    DraftingWorkflow {
        id: WorkflowId(Uuid::from_u128(WORKFLOW_IDENTIFIER_BASE + offset)),
        name: format!("flow-{index}"),
        is_signed,
    }
}

fn workflow_signings_strategy() -> impl Strategy<Value = Vec<bool>> {
    proptest::collection::vec(any::<bool>(), 0..MOST_WORKFLOWS)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_find_work_problems_property_a_valid_draft_has_none(
        context in context_strategy(),
        wrap in work_wrapper_strategy(),
        title in title_strategy(),
    ) {
        prop_assume!(!is_unicode_blank(&title));
        let work = valid_work_draft(&context, &title, &title);

        let (_, problems) = check_work(&context, &work, wrap)?;

        prop_assert!(problems.is_empty(), "{:?}", problems);
    }

    #[test]
    fn test_find_work_problems_property_title_problem_iff_unicode_blank(
        context in context_strategy(),
        wrap in work_wrapper_strategy(),
        title in title_strategy(),
    ) {
        let work = valid_work_draft(&context, &title, "Details");

        let (_, problems) = check_work(&context, &work, wrap)?;

        let title_problem = EMPTY_WORK_TITLE.to_owned();
        let has_title_problem = problems.contains(&title_problem);
        prop_assert_eq!(has_title_problem, is_unicode_blank(&title));
    }

    #[test]
    fn test_find_work_problems_property_each_label_is_one_clear_sentence(
        (context, work) in varied_work_strategy(),
        wrap in work_wrapper_strategy(),
    ) {
        let (_, problems) = check_work(&context, &work, wrap)?;

        for problem in &problems {
            let label = WORK_LABELS
                .iter()
                .find(|label| is_clear_sentence(problem, label));
            prop_assert!(label.is_some(), "{}", problem);
        }
        for label in WORK_LABELS {
            prop_assert!(count_labelled(&problems, label) <= 1);
        }
    }

    #[test]
    fn test_find_project_problem_property_any_listed_project_is_accepted(
        context in context_strategy(),
        position in any::<prop::sample::Index>(),
    ) {
        let chosen = &context.projects[position.index(context.projects.len())];
        let work = WorkDraft {
            project_id: Some(chosen.id),
            ..valid_work_draft(&context, "Ship", "Ship it")
        };

        let (_, problems) = check_work(&context, &work, ItemDraft::Task)?;

        prop_assert_eq!(count_labelled(&problems, PROJECT_LABEL), 0);
    }

    #[test]
    fn test_find_project_problem_property_problem_iff_not_listed(
        (context, work) in varied_work_strategy(),
    ) {
        let (completed, problems) =
            check_work(&context, &work, ItemDraft::Task)?;

        let is_listed = completed.project_id.is_some_and(|project_id| {
            context.projects.iter().any(|project| project.id == project_id)
        });
        let has_problem = count_labelled(&problems, PROJECT_LABEL) == 1;
        prop_assert_eq!(has_problem, !is_listed);
    }

    #[test]
    fn test_find_project_problem_property_offers_projects_in_order(
        context in context_strategy(),
        is_missing in any::<bool>(),
    ) {
        let project_id = if is_missing {
            None
        } else {
            Some(ProjectId(foreign_uuid()))
        };
        let work = WorkDraft {
            project_id,
            ..valid_work_draft(&context, "Ship", "Ship it")
        };
        prop_assume!(project_id.is_some() || context.projects.len() > 1);

        let (_, problems) = check_work(&context, &work, ItemDraft::Task)?;

        let problem = find_labelled(&problems, PROJECT_LABEL);
        let offered = problem.map(read_choices).unwrap_or_default();
        prop_assert_eq!(offered, list_project_names(&context));
    }

    #[test]
    fn test_find_doer_problem_property_one_agent_never_has_one(
        context in context_strategy(),
        agent in agent_kind_strategy(),
        signings in workflow_signings_strategy(),
    ) {
        let mut context = context;
        for (index, is_signed) in signings.into_iter().enumerate() {
            context.workflows.push(drafting_workflow(index, is_signed));
        }
        let work = WorkDraft {
            doer: TaskDoer::OneAgent { agent },
            ..valid_work_draft(&context, "Ship", "Ship it")
        };

        let (_, problems) = check_work(&context, &work, ItemDraft::Task)?;

        prop_assert_eq!(count_labelled(&problems, DOER_LABEL), 0);
    }

    #[test]
    fn test_find_doer_problem_property_problem_iff_unknown_or_unsigned(
        context in context_strategy(),
        signings in workflow_signings_strategy(),
        chosen_position in 0..MOST_WORKFLOWS + 1,
    ) {
        let mut context = context;
        context.workflows.clear();
        for (index, is_signed) in signings.iter().enumerate() {
            context.workflows.push(drafting_workflow(index, *is_signed));
        }
        let chosen = drafting_workflow(chosen_position, false);
        let work = WorkDraft {
            doer: TaskDoer::Workflow { workflow_id: chosen.id },
            ..valid_work_draft(&context, "Ship", "Ship it")
        };

        let (_, problems) = check_work(&context, &work, ItemDraft::Task)?;

        let is_signed_here = signings.get(chosen_position) == Some(&true);
        let has_problem = count_labelled(&problems, DOER_LABEL) == 1;
        prop_assert_eq!(has_problem, !is_signed_here);
    }

    #[test]
    fn test_find_doer_problem_property_signing_removes_only_that_problem(
        (context, work) in varied_work_strategy(),
    ) {
        let mut unsigned_context = context;
        let unsigned = drafting_workflow(MOST_WORKFLOWS, false);
        unsigned_context.workflows.push(unsigned.clone());
        let mut signed_context = unsigned_context.clone();
        if let Some(listed) = signed_context.workflows.last_mut() {
            listed.is_signed = true;
        }
        let work = WorkDraft {
            doer: TaskDoer::Workflow { workflow_id: unsigned.id },
            ..work
        };

        let (_, unsigned_problems) =
            check_work(&unsigned_context, &work, ItemDraft::Job)?;
        let (_, signed_problems) =
            check_work(&signed_context, &work, ItemDraft::Job)?;

        let mut expected = Vec::new();
        for problem in &unsigned_problems {
            if !problem.starts_with(DOER_LABEL) {
                expected.push(problem.clone());
            }
        }
        prop_assert_eq!(count_labelled(&unsigned_problems, DOER_LABEL), 1);
        prop_assert_eq!(signed_problems, expected);
    }
}
