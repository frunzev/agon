use std::collections::BTreeMap;

use orchestration_core::approval::ApprovalAction;
use orchestration_core::identifiers::WorkflowId;
use orchestration_node::views::describe_approval_action;
use proptest::collection::btree_map;
use proptest::prelude::*;
use uuid::Uuid;

const TITLE_CASES: u32 = 64;
const UNLISTED_WORKFLOW_TITLE: &str = "Sign a workflow";
const MOST_OTHER_WORKFLOWS: usize = 4;

type WorkflowNames = BTreeMap<WorkflowId, String>;

fn workflow_id_strategy() -> impl Strategy<Value = WorkflowId> {
    any::<u128>().prop_map(|bits| WorkflowId(Uuid::from_u128(bits)))
}

fn workflow_names_strategy() -> impl Strategy<Value = WorkflowNames> {
    btree_map(
        workflow_id_strategy(),
        "\\PC{1,24}",
        0..MOST_OTHER_WORKFLOWS,
    )
}

fn describe_signing(
    workflow_id: WorkflowId,
    workflow_names: &WorkflowNames,
) -> String {
    let action = ApprovalAction::SignWorkflow { workflow_id };
    describe_approval_action(&action, workflow_names)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(TITLE_CASES))]

    #[test]
    fn test_describe_approval_action_property_unlisted_is_a_plain_title(
        workflow_id in workflow_id_strategy(),
        other_names in workflow_names_strategy(),
    ) {
        let mut workflow_names = other_names;
        workflow_names.remove(&workflow_id);

        let title = describe_signing(workflow_id, &workflow_names);

        prop_assert_eq!(title, UNLISTED_WORKFLOW_TITLE);
    }

    #[test]
    fn test_describe_approval_action_property_never_shows_the_raw_id(
        workflow_id in workflow_id_strategy(),
        other_names in workflow_names_strategy(),
    ) {
        let mut workflow_names = other_names;
        workflow_names.remove(&workflow_id);

        let title = describe_signing(workflow_id, &workflow_names);

        let raw_identifier = workflow_id.0.to_string();
        prop_assert!(!title.contains(&raw_identifier), "{}", title);
        let simple_identifier = workflow_id.0.simple().to_string();
        prop_assert!(!title.contains(&simple_identifier), "{}", title);
    }

    #[test]
    fn test_describe_approval_action_property_picks_the_listed_name(
        workflow_id in workflow_id_strategy(),
        workflow_name in "\\PC{1,24}",
        other_names in workflow_names_strategy(),
    ) {
        let mut workflow_names = other_names;
        workflow_names.insert(workflow_id, workflow_name.clone());

        let title = describe_signing(workflow_id, &workflow_names);

        prop_assert_eq!(title, format!("Sign workflow {workflow_name}"));
    }
}
