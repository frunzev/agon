#[allow(dead_code)]
#[path = "../business_rules/entity_strategies.rs"]
mod entity_strategies;

use orchestration_core::task::{Task, TaskStatus};
use orchestration_core::task_summary::{
    describe_task_summary, summarize_tasks,
};
use proptest::prelude::*;
use serde::Deserialize;

use crate::entity_strategies::example_task;

const SHARED_SUMMARY_CASES: &str =
    include_str!("../fixtures/task_summary_cases.json");
const NO_TASKS_TEXT: &str = "No tasks yet";
const ALL_DONE_TEXT: &str = "All done";
const LARGEST_ADDED_DONE_COUNT: usize = 6;

#[derive(Debug, Deserialize)]
struct SharedSummaryCase {
    statuses: Vec<TaskStatus>,
    text: String,
}

fn read_shared_cases() -> Result<Vec<SharedSummaryCase>, serde_json::Error> {
    serde_json::from_str(SHARED_SUMMARY_CASES)
}

fn build_tasks(statuses: &[TaskStatus]) -> Vec<Task> {
    let mut tasks = Vec::new();
    for status in statuses {
        tasks.push(Task {
            status: *status,
            ..example_task()
        });
    }
    tasks
}

fn describe_statuses(statuses: &[TaskStatus]) -> String {
    describe_task_summary(&summarize_tasks(&build_tasks(statuses)))
}

#[test]
fn test_describe_task_summary_property_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let text = describe_statuses(&case.statuses);

        assert_eq!(text, case.text, "{:?}", case.statuses);
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_describe_task_summary_property_shared_table_ignores_task_order(
        case_position in any::<prop::sample::Index>(),
        shuffle_seed in any::<u64>(),
    ) {
        let cases = read_shared_cases()?;
        let case = &cases[case_position.index(cases.len())];
        let mut shuffled = case.statuses.clone();
        let rotation = usize::try_from(shuffle_seed).unwrap_or_default();
        if !shuffled.is_empty() {
            let length = shuffled.len();
            shuffled.rotate_left(rotation % length);
            shuffled.reverse();
        }

        let text = describe_statuses(&shuffled);

        prop_assert_eq!(text, case.text.clone());
    }

    #[test]
    fn test_describe_task_summary_property_done_tasks_never_change_the_text(
        case_position in any::<prop::sample::Index>(),
        added_done_count in 1..=LARGEST_ADDED_DONE_COUNT,
    ) {
        let cases = read_shared_cases()?;
        let case = &cases[case_position.index(cases.len())];
        let mut grown = case.statuses.clone();
        grown.extend(std::iter::repeat_n(TaskStatus::Done, added_done_count));

        let text = describe_statuses(&grown);

        let expected = if case.text == NO_TASKS_TEXT {
            ALL_DONE_TEXT.to_owned()
        } else {
            case.text.clone()
        };
        prop_assert_eq!(text, expected);
    }
}
