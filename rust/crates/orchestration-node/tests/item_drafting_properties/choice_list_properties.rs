use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{DeviceId, SkillId, WorkflowId};
use orchestration_core::task::TaskDoer;
use orchestration_node::item_drafting::{
    CheckedDraft, DraftingContext, ItemDraft, WorkDraft, check_item_draft,
};
use proptest::prelude::*;
use uuid::Uuid;

use crate::support::draft_problem_texts::{
    join_choices, list_runner_names, list_signed_workflow_names,
    list_skill_names,
};
use crate::support::drafting_samples::{
    FOREIGN_DEVICE_ID, SAMPLE_WORKSPACE_NAME, context_strategy, foreign_uuid,
    valid_work_draft,
};
use crate::support::entity_strategies::secret_text_strategy;

const CHOICE_CASES: u32 = 48;
const ONE_AGENT_CHOICE: &str = "one agent";
const NO_SKILL_CHOICE: &str = "none";
const ANY_FREE_RUNNER_CHOICE: &str = "any free runner";
const SKILL_LABEL: &str = "Skills to use: ";
const MOST_UNKNOWN_SKILLS: usize = 4;
const MOST_LABELS: usize = 3;
const LABEL_PATTERN: &str = "[a-z]{1,6}";

fn check_task(context: &DraftingContext, work: WorkDraft) -> CheckedDraft {
    check_item_draft(context, &ItemDraft::Task(work))
}

fn sign_some_workflows(
    context: &DraftingContext,
    signatures: &[bool],
) -> DraftingContext {
    let mut signed_context = context.clone();
    for (workflow, is_signed) in
        signed_context.workflows.iter_mut().zip(signatures)
    {
        workflow.is_signed = *is_signed;
    }
    signed_context
}

fn workflow_doer(workflow_id: WorkflowId) -> TaskDoer {
    TaskDoer::Workflow { workflow_id }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHOICE_CASES))]

    #[test]
    fn test_list_signed_workflow_names_property_unknown_lists_signed_ones(
        context in context_strategy(),
        signatures in proptest::collection::vec(any::<bool>(), 4),
        words in secret_text_strategy(),
    ) {
        let signed_context = sign_some_workflows(&context, &signatures);
        let mut work = valid_work_draft(&signed_context, &words, &words);
        work.doer = workflow_doer(WorkflowId(foreign_uuid()));

        let checked = check_task(&signed_context, work);

        let choices = join_choices(
            list_signed_workflow_names(&signed_context),
            ONE_AGENT_CHOICE,
        );
        let expected = format!(
            "Who does it: the chosen workflow does not exist here. Ask for \
             changes and name one of: {choices}."
        );
        prop_assert_eq!(checked.problems, vec![expected]);
    }

    #[test]
    fn test_list_signed_workflow_names_property_unsigned_ones_are_left_out(
        context in context_strategy(),
        signatures in proptest::collection::vec(any::<bool>(), 4),
        words in secret_text_strategy(),
    ) {
        prop_assume!(!context.workflows.is_empty());
        let mut flipped = signatures.clone();
        flipped[0] = false;
        let signed_context = sign_some_workflows(&context, &flipped);
        let unsigned = &signed_context.workflows[0];
        let mut work = valid_work_draft(&signed_context, &words, &words);
        work.doer = workflow_doer(unsigned.id);

        let checked = check_task(&signed_context, work);

        let choices = join_choices(
            list_signed_workflow_names(&signed_context),
            ONE_AGENT_CHOICE,
        );
        let expected = format!(
            "Who does it: the workflow {} is not signed yet. Ask for changes \
             and name one of: {choices}.",
            unsigned.name
        );
        prop_assert_eq!(checked.problems, vec![expected]);
    }

    #[test]
    fn test_list_signed_workflow_names_property_a_signed_one_is_accepted(
        context in context_strategy(),
        chosen_index in any::<prop::sample::Index>(),
        words in secret_text_strategy(),
    ) {
        prop_assume!(!context.workflows.is_empty());
        let chosen = chosen_index.get(&context.workflows).id;
        let mut work = valid_work_draft(&context, &words, &words);
        work.doer = workflow_doer(chosen);

        let checked = check_task(&context, work);

        prop_assert!(checked.problems.is_empty(), "{:?}", checked.problems);
    }

    #[test]
    fn test_list_skill_names_property_unknown_lists_every_skill(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let mut work = valid_work_draft(&context, &words, &words);
        work.skills.push(SkillId(foreign_uuid()));

        let checked = check_task(&context, work);

        let choices =
            join_choices(list_skill_names(&context), NO_SKILL_CHOICE);
        let expected = format!(
            "Skills to use: a chosen skill does not exist here. Ask for \
             changes and name one of: {choices}."
        );
        prop_assert_eq!(checked.problems, vec![expected]);
    }

    #[test]
    fn test_list_skill_names_property_repeated_listed_skills_are_accepted(
        context in context_strategy(),
        words in secret_text_strategy(),
        picks in proptest::collection::vec(any::<prop::sample::Index>(), 0..6),
    ) {
        prop_assume!(!context.skills.is_empty());
        let mut work = valid_work_draft(&context, &words, &words);
        let mut skills = Vec::new();
        for pick in &picks {
            skills.push(pick.get(&context.skills).id);
        }
        work.skills = skills;

        let checked = check_task(&context, work);

        prop_assert!(checked.problems.is_empty(), "{:?}", checked.problems);
    }

    #[test]
    fn test_list_skill_names_property_several_unknown_skills_give_one_line(
        context in context_strategy(),
        words in secret_text_strategy(),
        unknown_count in 1..MOST_UNKNOWN_SKILLS,
    ) {
        let mut work = valid_work_draft(&context, &words, &words);
        for index in 0..unknown_count {
            let offset = u128::try_from(index).unwrap_or_default();
            work.skills.push(SkillId(Uuid::from_u128(u128::MAX - offset)));
        }

        let checked = check_task(&context, work);

        let skill_problems = checked
            .problems
            .iter()
            .filter(|problem| problem.starts_with(SKILL_LABEL))
            .count();
        prop_assert_eq!(skill_problems, 1);
        prop_assert_eq!(checked.problems.len(), 1);
    }

    #[test]
    fn test_list_runner_names_property_foreign_lists_every_runner(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let mut work = valid_work_draft(&context, &words, &words);
        work.runs_on = RunnerTarget::SpecificRunner {
            device_id: DeviceId(FOREIGN_DEVICE_ID.to_owned()),
        };

        let checked = check_task(&context, work);

        let choices =
            join_choices(list_runner_names(&context), ANY_FREE_RUNNER_CHOICE);
        let expected = format!(
            "Runs on: the chosen runner is not in {SAMPLE_WORKSPACE_NAME}. \
             Ask for changes and name one of: {choices}."
        );
        prop_assert_eq!(checked.problems, vec![expected]);
    }

    #[test]
    fn test_list_runner_names_property_a_listed_runner_is_accepted(
        context in context_strategy(),
        words in secret_text_strategy(),
        chosen_index in any::<prop::sample::Index>(),
    ) {
        prop_assume!(!context.runners.is_empty());
        let chosen = chosen_index.get(&context.runners).device.id.clone();
        let mut work = valid_work_draft(&context, &words, &words);
        work.runs_on = RunnerTarget::SpecificRunner { device_id: chosen };

        let checked = check_task(&context, work);

        prop_assert!(checked.problems.is_empty(), "{:?}", checked.problems);
    }

    #[test]
    fn test_list_runner_names_property_open_targets_need_no_listed_runner(
        context in context_strategy(),
        words in secret_text_strategy(),
        labels in proptest::collection::vec(LABEL_PATTERN, 0..MOST_LABELS),
    ) {
        let mut context = context;
        context.runners.clear();
        let targets = [
            RunnerTarget::AnyFreeRunner,
            RunnerTarget::RunnerWithLabels { labels },
        ];

        for target in targets {
            let mut work = valid_work_draft(&context, &words, &words);
            work.runs_on = target;
            let checked = check_task(&context, work);
            let problems = checked.problems;
            prop_assert!(problems.is_empty(), "{:?}", problems);
        }
    }
}
