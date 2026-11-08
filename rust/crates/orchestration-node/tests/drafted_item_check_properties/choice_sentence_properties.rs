use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{DeviceId, SkillId, WorkflowId};
use orchestration_core::task::TaskDoer;
use orchestration_node::item_drafting::{
    DraftingContext, ItemDraft, WorkDraft,
};
use proptest::prelude::*;
use uuid::Uuid;

use crate::drafted_item_checks::{
    CHECK_CASES, WorkWrapper, check_work, is_clear_sentence, read_labelled,
    work_wrapper_strategy,
};
use crate::support::draft_problem_texts::{
    join_choices, list_runner_names, list_signed_workflow_names,
    list_skill_names,
};
use crate::support::drafting_samples::{
    FOREIGN_DEVICE_ID, context_strategy, foreign_uuid, valid_work_draft,
};
use crate::work_samples::read_choices;

const RUNNER_LABEL: &str = "Runs on";
const SKILL_LABEL: &str = "Skills to use";
const DOER_LABEL: &str = "Who does it";
const RUNNER_CHOICE: &str = "any free runner";
const SKILL_CHOICE: &str = "none";
const WORKFLOW_CHOICE: &str = "one agent";
const UNKNOWN_DEVICE_PATTERN: &str = "[0-9a-f]{6}x";

struct OfferedChoices {
    label: &'static str,
    fixed_choice: &'static str,
    listed: Vec<String>,
}

fn broken_work(context: &DraftingContext) -> WorkDraft {
    WorkDraft {
        doer: TaskDoer::Workflow {
            workflow_id: WorkflowId(foreign_uuid()),
        },
        runs_on: RunnerTarget::SpecificRunner {
            device_id: DeviceId(FOREIGN_DEVICE_ID.to_owned()),
        },
        skills: vec![SkillId(foreign_uuid())],
        ..valid_work_draft(context, "Ship", "Ship it")
    }
}

fn broken_problems(
    context: &DraftingContext,
    wrap: WorkWrapper,
) -> Result<Vec<String>, TestCaseError> {
    let (_, problems) = check_work(context, &broken_work(context), wrap)?;
    Ok(problems)
}

fn list_offered_choices(context: &DraftingContext) -> [OfferedChoices; 3] {
    [
        OfferedChoices {
            label: DOER_LABEL,
            fixed_choice: WORKFLOW_CHOICE,
            listed: list_signed_workflow_names(context),
        },
        OfferedChoices {
            label: RUNNER_LABEL,
            fixed_choice: RUNNER_CHOICE,
            listed: list_runner_names(context),
        },
        OfferedChoices {
            label: SKILL_LABEL,
            fixed_choice: SKILL_CHOICE,
            listed: list_skill_names(context),
        },
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_describe_foreign_runner_property_offers_every_runner(
        context in context_strategy(),
        wrap in work_wrapper_strategy(),
    ) {
        let problems = broken_problems(&context, wrap)?;

        let expected = format!(
            "Runs on: the chosen runner is not in {}. Ask for changes and \
             name one of: {}.",
            context.workspace.name,
            join_choices(list_runner_names(&context), RUNNER_CHOICE)
        );
        prop_assert_eq!(read_labelled(&problems, RUNNER_LABEL), expected);
    }

    #[test]
    fn test_describe_foreign_runner_property_never_shows_the_device_id(
        context in context_strategy(),
        device_text in UNKNOWN_DEVICE_PATTERN,
    ) {
        let work = WorkDraft {
            runs_on: RunnerTarget::SpecificRunner {
                device_id: DeviceId(device_text.clone()),
            },
            ..valid_work_draft(&context, "Ship", "Ship it")
        };

        let (_, problems) = check_work(&context, &work, ItemDraft::Task)?;

        let problem = read_labelled(&problems, RUNNER_LABEL);
        let is_clear = is_clear_sentence(&problem, RUNNER_LABEL);
        prop_assert!(is_clear, "{}", problem);
        prop_assert!(!problem.contains(&device_text), "{}", problem);
    }

    #[test]
    fn test_describe_foreign_runner_property_offline_runners_are_offered(
        context in context_strategy(),
    ) {
        let mut context = context;
        for runner in &mut context.runners {
            runner.is_online = false;
        }

        let problems = broken_problems(&context, ItemDraft::Task)?;

        let offered = read_choices(&read_labelled(&problems, RUNNER_LABEL));
        let mut expected = list_runner_names(&context);
        expected.push(RUNNER_CHOICE.to_owned());
        prop_assert_eq!(offered, expected);
    }

    #[test]
    fn test_describe_unknown_skill_property_offers_every_skill(
        context in context_strategy(),
        wrap in work_wrapper_strategy(),
    ) {
        let problems = broken_problems(&context, wrap)?;

        let expected = format!(
            "Skills to use: a chosen skill does not exist here. Ask for \
             changes and name one of: {}.",
            join_choices(list_skill_names(&context), SKILL_CHOICE)
        );
        prop_assert_eq!(read_labelled(&problems, SKILL_LABEL), expected);
    }

    #[test]
    fn test_describe_unknown_skill_property_never_shows_the_skill_id(
        context in context_strategy(),
        number in any::<u128>(),
    ) {
        let skill_id = SkillId(Uuid::from_u128(number));
        let is_listed =
            context.skills.iter().any(|skill| skill.id == skill_id);
        prop_assume!(!is_listed);
        let work = WorkDraft {
            skills: vec![skill_id],
            ..valid_work_draft(&context, "Ship", "Ship it")
        };

        let (_, problems) = check_work(&context, &work, ItemDraft::Task)?;

        let problem = read_labelled(&problems, SKILL_LABEL);
        prop_assert!(!problem.contains(&skill_id.0.to_string()));
        prop_assert!(!problem.contains(&skill_id.0.simple().to_string()));
    }

    #[test]
    fn test_describe_unknown_skill_property_is_one_clear_sentence(
        context in context_strategy(),
        wrap in work_wrapper_strategy(),
    ) {
        let problems = broken_problems(&context, wrap)?;

        let problem = read_labelled(&problems, SKILL_LABEL);
        let is_clear = is_clear_sentence(&problem, SKILL_LABEL);
        prop_assert!(is_clear, "{}", problem);
    }

    #[test]
    fn test_join_choices_property_the_fixed_choice_comes_last_once(
        context in context_strategy(),
    ) {
        let problems = broken_problems(&context, ItemDraft::Task)?;

        for offered in list_offered_choices(&context) {
            let problem = read_labelled(&problems, offered.label);
            let choices = read_choices(&problem);
            let fixed = offered.fixed_choice.to_owned();
            prop_assert_eq!(choices.last(), Some(&fixed));
            let repeats = choices.iter().filter(|choice| **choice == fixed);
            prop_assert_eq!(repeats.count(), 1);
        }
    }

    #[test]
    fn test_join_choices_property_offers_one_more_than_listed(
        context in context_strategy(),
    ) {
        let problems = broken_problems(&context, ItemDraft::Job)?;

        for offered in list_offered_choices(&context) {
            let problem = read_labelled(&problems, offered.label);
            let mut expected = offered.listed.clone();
            expected.push(offered.fixed_choice.to_owned());
            prop_assert_eq!(read_choices(&problem), expected);
        }
    }

    #[test]
    fn test_join_choices_property_nothing_listed_offers_the_fixed_choice(
        context in context_strategy(),
    ) {
        let mut context = context;
        context.workflows.clear();
        context.runners.clear();
        context.skills.clear();

        let problems = broken_problems(&context, ItemDraft::Task)?;

        for offered in list_offered_choices(&context) {
            let problem = read_labelled(&problems, offered.label);
            let fixed = vec![offered.fixed_choice.to_owned()];
            prop_assert_eq!(read_choices(&problem), fixed);
        }
    }
}
