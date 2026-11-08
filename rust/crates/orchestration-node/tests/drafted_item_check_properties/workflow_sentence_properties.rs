use std::collections::BTreeSet;

use orchestration_core::identifiers::WorkflowId;
use orchestration_core::task::TaskDoer;
use orchestration_node::item_drafting::{
    DraftingContext, DraftingWorkflow, ItemDraft, WorkDraft,
};
use proptest::prelude::*;
use uuid::Uuid;

use crate::drafted_item_checks::{
    CHECK_CASES, WorkWrapper, check_work, is_clear_sentence, read_labelled,
    work_wrapper_strategy,
};
use crate::support::draft_problem_texts::{
    join_choices, list_signed_workflow_names,
};
use crate::support::drafting_samples::{
    context_strategy, foreign_uuid, valid_work_draft,
};
use crate::work_samples::read_choices;

const DOER_LABEL: &str = "Who does it";
const UNSIGNED_NAME_PATTERN: &str = "[a-z]{3,6}-draft";
const UNSIGNED_NUMBER_BASE: u128 = 0xa00;
const MOST_UNSIGNED: usize = 3;

fn doer_problem(
    context: &DraftingContext,
    workflow_id: WorkflowId,
    wrap: WorkWrapper,
) -> Result<String, TestCaseError> {
    let work = WorkDraft {
        doer: TaskDoer::Workflow { workflow_id },
        ..valid_work_draft(context, "Ship", "Ship it")
    };
    let (_, problems) = check_work(context, &work, wrap)?;
    Ok(read_labelled(&problems, DOER_LABEL))
}

fn unknown_workflow_id() -> WorkflowId {
    WorkflowId(foreign_uuid())
}

fn add_unsigned(
    context: &DraftingContext,
    names: &BTreeSet<String>,
) -> (DraftingContext, Vec<DraftingWorkflow>) {
    let mut grown = context.clone();
    let mut added = Vec::new();
    for (number, name) in names.iter().enumerate() {
        let offset = u128::try_from(number).unwrap_or_default();
        let workflow = DraftingWorkflow {
            id: WorkflowId(Uuid::from_u128(UNSIGNED_NUMBER_BASE + offset)),
            name: name.clone(),
            is_signed: false,
        };
        grown.workflows.push(workflow.clone());
        added.push(workflow);
    }
    (grown, added)
}

fn describe_choices(context: &DraftingContext) -> String {
    join_choices(list_signed_workflow_names(context), "one agent")
}

fn unsigned_names_strategy() -> impl Strategy<Value = BTreeSet<String>> {
    proptest::collection::btree_set(UNSIGNED_NAME_PATTERN, 1..MOST_UNSIGNED)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_describe_unknown_workflow_property_offers_signed_then_one_agent(
        context in context_strategy(),
    ) {
        let problem =
            doer_problem(&context, unknown_workflow_id(), ItemDraft::Task)?;

        let expected = format!(
            "Who does it: the chosen workflow does not exist here. Ask for \
             changes and name one of: {}.",
            describe_choices(&context)
        );
        prop_assert_eq!(problem, expected);
    }

    #[test]
    fn test_describe_unknown_workflow_property_never_offers_unsigned_ones(
        context in context_strategy(),
        unsigned_names in unsigned_names_strategy(),
    ) {
        let (grown, _) = add_unsigned(&context, &unsigned_names);

        let problem =
            doer_problem(&grown, unknown_workflow_id(), ItemDraft::Task)?;

        let offered = read_choices(&problem);
        for name in &unsigned_names {
            prop_assert!(!offered.contains(name), "{}", problem);
        }
    }

    #[test]
    fn test_describe_unknown_workflow_property_is_one_clear_sentence(
        context in context_strategy(),
        wrap in work_wrapper_strategy(),
    ) {
        let problem = doer_problem(&context, unknown_workflow_id(), wrap)?;

        prop_assert!(is_clear_sentence(&problem, DOER_LABEL), "{}", problem);
    }

    #[test]
    fn test_describe_unsigned_workflow_property_names_it_and_signed_ones(
        context in context_strategy(),
        unsigned_names in unsigned_names_strategy(),
    ) {
        let (grown, added) = add_unsigned(&context, &unsigned_names);

        for workflow in &added {
            let problem = doer_problem(&grown, workflow.id, ItemDraft::Job)?;

            let expected = format!(
                "Who does it: the workflow {} is not signed yet. Ask for \
                 changes and name one of: {}.",
                workflow.name,
                describe_choices(&grown)
            );
            prop_assert_eq!(problem, expected);
        }
    }

    #[test]
    fn test_describe_unsigned_workflow_property_differs_from_unknown(
        context in context_strategy(),
        unsigned_names in unsigned_names_strategy(),
    ) {
        let (grown, added) = add_unsigned(&context, &unsigned_names);
        let unknown_problem =
            doer_problem(&grown, unknown_workflow_id(), ItemDraft::Task)?;

        for workflow in &added {
            let problem = doer_problem(&grown, workflow.id, ItemDraft::Task)?;

            prop_assert_ne!(&problem, &unknown_problem);
            let unknown_choices = read_choices(&unknown_problem);
            prop_assert_eq!(read_choices(&problem), unknown_choices);
        }
    }

    #[test]
    fn test_describe_unsigned_workflow_property_is_one_clear_sentence(
        context in context_strategy(),
        unsigned_names in unsigned_names_strategy(),
        wrap in work_wrapper_strategy(),
    ) {
        let (grown, added) = add_unsigned(&context, &unsigned_names);

        for workflow in &added {
            let problem = doer_problem(&grown, workflow.id, wrap)?;

            let is_clear = is_clear_sentence(&problem, DOER_LABEL);
            prop_assert!(is_clear, "{}", problem);
        }
    }
}
