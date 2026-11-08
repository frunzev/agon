#[allow(dead_code)]
#[path = "../worktree_support/mod.rs"]
mod worktree_support;

use orchestration_core::identifiers::TaskId;
use orchestration_hub::branch_names::is_valid_branch_name;
use orchestration_hub::worktree_plan::{WorktreeLifetime, plan_worktree};
use proptest::prelude::*;
use serde::Deserialize;

use crate::worktree_support::{any_hostile_title, any_task_id, request_for};

const SHARED_BRANCH_CASES: &str = include_str!(
    "../../../orchestration-core/tests/fixtures/task_branch_cases.json"
);

#[derive(Debug, Deserialize)]
struct SharedBranchCase {
    title: String,
    task_id: TaskId,
    run_number: Option<u32>,
    branch: String,
}

fn read_shared_cases() -> Result<Vec<SharedBranchCase>, serde_json::Error> {
    serde_json::from_str(SHARED_BRANCH_CASES)
}

fn describe_lifetime(run_number: Option<u32>) -> WorktreeLifetime {
    match run_number {
        None => WorktreeLifetime::PerTask,
        Some(run_number) => WorktreeLifetime::PerJobRun { run_number },
    }
}

fn plan_branch(
    task_id: TaskId,
    title: &str,
    run_number: Option<u32>,
) -> Option<String> {
    let request =
        request_for(task_id, title, describe_lifetime(run_number), Vec::new());
    let plan = plan_worktree(&request).ok()?;
    Some(plan.branch)
}

#[test]
fn test_plan_worktree_property_branch_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let branch = plan_branch(case.task_id, &case.title, case.run_number);

        assert_eq!(branch.as_deref(), Some(case.branch.as_str()), "{case:?}");
    }
    Ok(())
}

#[test]
fn test_plan_worktree_property_shared_branches_are_distinct_and_valid()
-> Result<(), serde_json::Error> {
    let cases = read_shared_cases()?;
    let mut seen = std::collections::BTreeSet::new();
    for case in &cases {
        assert!(is_valid_branch_name(&case.branch), "{case:?}");
        assert!(seen.insert(case.branch.clone()), "{case:?}");
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_plan_worktree_property_branch_ends_with_the_task_id_and_run(
        task_id in any_task_id(),
        title in any_hostile_title(),
        run_number in proptest::option::of(any::<u32>()),
    ) {
        let branch = plan_branch(task_id, &title, run_number);

        let identifier = task_id.0.simple().to_string();
        let ending = match run_number {
            None => identifier,
            Some(run_number) => format!("{identifier}-run-{run_number}"),
        };
        let planned = branch.unwrap_or_default();
        prop_assert!(planned.ends_with(&format!("-{ending}")), "{planned}");
        prop_assert!(is_valid_branch_name(&planned), "{planned}");
    }
}
