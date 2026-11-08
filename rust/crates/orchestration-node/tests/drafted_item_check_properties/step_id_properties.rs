use std::collections::{BTreeMap, BTreeSet};

use orchestration_core::identifiers::WorkflowAgentId;
use orchestration_core::workflow::{AgentConnection, Workflow, WorkflowAgent};
use orchestration_core::workflow_graph::validate_workflow;
use orchestration_node::item_drafting::keep_stored_step_ids;
use proptest::prelude::*;
use uuid::Uuid;

use crate::drafted_item_checks::CHECK_CASES;
use crate::support::entity_strategies::sample_workflow;

const MOST_STEPS: usize = 6;
const MOST_NEW_STEPS: usize = 3;

type NamedConnection = (String, String);

fn stored_workflow(step_count: usize) -> Workflow {
    let mut tasks = Vec::new();
    for index in 0..step_count {
        tasks.push(format!("Do part {index}"));
    }
    let mut workflow = sample_workflow(&tasks);
    for pair in workflow.agents.windows(2) {
        workflow
            .connections
            .push(AgentConnection::plain(pair[0].id, pair[1].id));
    }
    workflow
}

fn distinct_ids_strategy(
    count: usize,
) -> impl Strategy<Value = Vec<WorkflowAgentId>> {
    proptest::collection::btree_set(any::<u128>(), count).prop_map(|numbers| {
        let mut ids = Vec::new();
        for number in numbers {
            ids.push(WorkflowAgentId(Uuid::from_u128(number)));
        }
        ids
    })
}

fn reassign_ids(workflow: &Workflow, new_ids: &[WorkflowAgentId]) -> Workflow {
    let mut moved_ids = BTreeMap::new();
    let mut agents = Vec::new();
    for (agent, new_id) in workflow.agents.iter().zip(new_ids) {
        moved_ids.insert(agent.id, *new_id);
        agents.push(WorkflowAgent {
            id: *new_id,
            ..agent.clone()
        });
    }
    let mut connections = Vec::new();
    for connection in &workflow.connections {
        let from = moved_ids.get(&connection.from).copied();
        let to = moved_ids.get(&connection.to).copied();
        connections.push(AgentConnection {
            from: from.unwrap_or(connection.from),
            to: to.unwrap_or(connection.to),
            ..connection.clone()
        });
    }
    Workflow {
        agents,
        connections,
        ..workflow.clone()
    }
}

fn add_new_steps(
    workflow: &Workflow,
    new_ids: &[WorkflowAgentId],
) -> Workflow {
    let mut grown = workflow.clone();
    let template = workflow.agents[0].clone();
    for (index, new_id) in new_ids.iter().enumerate() {
        grown.agents.push(WorkflowAgent {
            id: *new_id,
            name: format!("new-{index}"),
            ..template.clone()
        });
    }
    grown
}

fn ids_by_name(workflow: &Workflow) -> BTreeMap<String, WorkflowAgentId> {
    let mut ids = BTreeMap::new();
    for agent in &workflow.agents {
        ids.insert(agent.name.clone(), agent.id);
    }
    ids
}

fn name_connections(workflow: &Workflow) -> Vec<NamedConnection> {
    let step_names: BTreeMap<WorkflowAgentId, String> = workflow
        .agents
        .iter()
        .map(|agent| (agent.id, agent.name.clone()))
        .collect();
    let mut named_connections = Vec::new();
    for connection in &workflow.connections {
        let from = step_names.get(&connection.from).cloned();
        let to = step_names.get(&connection.to).cloned();
        named_connections
            .push((from.unwrap_or_default(), to.unwrap_or_default()));
    }
    named_connections
}

fn change_strategy() -> impl Strategy<Value = (Workflow, Workflow)> {
    (1..MOST_STEPS, 0..MOST_NEW_STEPS).prop_flat_map(|(steps, new_steps)| {
        let stored = stored_workflow(steps);
        distinct_ids_strategy(steps + new_steps).prop_map(move |drafted_ids| {
            let (kept_part, new_part) = drafted_ids.split_at(steps);
            let redrafted = reassign_ids(&stored, kept_part);
            (add_new_steps(&redrafted, new_part), stored.clone())
        })
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_choose_step_id_property_a_stored_name_takes_the_stored_id(
        (changed, stored) in change_strategy(),
    ) {
        let kept = keep_stored_step_ids(&changed, &stored);

        let kept_ids = ids_by_name(&kept);
        for (name, stored_id) in ids_by_name(&stored) {
            prop_assert_eq!(kept_ids.get(&name), Some(&stored_id));
        }
    }

    #[test]
    fn test_choose_step_id_property_a_new_name_gets_an_unused_id(
        (changed, stored) in change_strategy(),
    ) {
        let kept = keep_stored_step_ids(&changed, &stored);

        let stored_names: BTreeSet<String> =
            ids_by_name(&stored).into_keys().collect();
        let mut used_ids: BTreeSet<WorkflowAgentId> = BTreeSet::new();
        used_ids.extend(stored.agents.iter().map(|agent| agent.id));
        used_ids.extend(changed.agents.iter().map(|agent| agent.id));
        for agent in &kept.agents {
            if stored_names.contains(&agent.name) {
                continue;
            }
            prop_assert!(used_ids.insert(agent.id), "{:?}", agent.id);
        }
    }

    #[test]
    fn test_choose_step_id_property_a_re_draft_keeps_every_id(
        (changed, stored) in change_strategy(),
        redrafted_ids in distinct_ids_strategy(MOST_STEPS + MOST_NEW_STEPS),
    ) {
        let first = keep_stored_step_ids(&changed, &stored);
        let redrafted = reassign_ids(&first, &redrafted_ids);

        let second = keep_stored_step_ids(&redrafted, &first);

        prop_assert_eq!(second, first);
    }

    #[test]
    fn test_move_step_id_property_connections_join_the_same_named_steps(
        (changed, stored) in change_strategy(),
    ) {
        let kept = keep_stored_step_ids(&changed, &stored);

        prop_assert_eq!(name_connections(&kept), name_connections(&changed));
    }

    #[test]
    fn test_move_step_id_property_the_kept_workflow_stays_valid(
        (changed, stored) in change_strategy(),
    ) {
        prop_assert_eq!(validate_workflow(&changed), Ok(()));

        let kept = keep_stored_step_ids(&changed, &stored);

        prop_assert_eq!(validate_workflow(&kept), Ok(()));
    }

    #[test]
    fn test_move_step_id_property_swapped_ids_move_back_both_ways(
        (stored, shuffled_ids) in (1..MOST_STEPS).prop_flat_map(|steps| {
            let stored = stored_workflow(steps);
            let ids: Vec<WorkflowAgentId> =
                stored.agents.iter().map(|agent| agent.id).collect();
            (Just(stored), Just(ids).prop_shuffle())
        }),
    ) {
        let swapped = reassign_ids(&stored, &shuffled_ids);

        let kept = keep_stored_step_ids(&swapped, &stored);

        prop_assert_eq!(kept, stored);
    }
}
