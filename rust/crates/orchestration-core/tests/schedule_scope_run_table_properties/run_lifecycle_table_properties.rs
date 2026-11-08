use chrono::{DateTime, Utc};
use orchestration_core::run::{RunStatus, RunStep, StepStatus};
use orchestration_core::run_lifecycle::{
    derive_run_status, is_run_finished, is_run_stopped, is_step_finished,
    skip_unfinished_steps,
};
use proptest::prelude::*;
use proptest::sample::Index;
use serde::Deserialize;

const SHARED_RUN_LIFECYCLE_TABLE: &str =
    include_str!("../fixtures/run_lifecycle_cases.json");

#[derive(Debug, Deserialize)]
struct SharedRunLifecycleTable {
    run_statuses: Vec<SharedRunStatus>,
    cancels: Vec<SharedCancel>,
    retries: Vec<SharedRetry>,
}

#[derive(Debug, Deserialize)]
struct SharedRunStatus {
    status: RunStatus,
    is_finished: bool,
    can_retry: bool,
}

#[derive(Debug, Deserialize)]
struct SharedCancel {
    steps: Vec<StepStatus>,
    after_cancel: Vec<StepStatus>,
}

#[derive(Debug, Deserialize)]
struct SharedRetry {
    steps: Vec<StepStatus>,
    after_retry: Vec<StepStatus>,
    status_after_retry: RunStatus,
}

fn read_shared_table() -> Result<SharedRunLifecycleTable, serde_json::Error> {
    serde_json::from_str(SHARED_RUN_LIFECYCLE_TABLE)
}

fn build_step(position: usize, status: StepStatus) -> RunStep {
    RunStep {
        name: format!("step {position}"),
        agent_id: None,
        runner: None,
        status,
        started_at: None,
        finished_at: None,
        result: None,
        outcome: None,
        loop_source: None,
        earlier_rounds: Vec::new(),
    }
}

fn build_steps(statuses: &[StepStatus]) -> Vec<RunStep> {
    let mut steps = Vec::new();
    for (position, status) in statuses.iter().enumerate() {
        steps.push(build_step(position, *status));
    }
    steps
}

fn list_statuses(steps: &[RunStep]) -> Vec<StepStatus> {
    steps.iter().map(|step| step.status).collect()
}

#[test]
fn test_is_run_finished_property_matches_the_shared_lifecycle_table()
-> Result<(), serde_json::Error> {
    let table = read_shared_table()?;

    assert!(!table.run_statuses.is_empty());
    for case in table.run_statuses {
        assert_eq!(is_run_finished(case.status), case.is_finished, "{case:?}");
        assert_eq!(is_run_stopped(case.status), case.can_retry, "{case:?}");
    }
    Ok(())
}

#[test]
fn test_skip_unfinished_steps_property_matches_the_shared_cancels()
-> Result<(), serde_json::Error> {
    let table = read_shared_table()?;
    let at = DateTime::<Utc>::UNIX_EPOCH;

    assert!(!table.cancels.is_empty());
    for case in table.cancels {
        let cancelled = skip_unfinished_steps(&build_steps(&case.steps), at);

        assert_eq!(list_statuses(&cancelled), case.after_cancel, "{case:?}");
    }
    Ok(())
}

#[test]
fn test_derive_run_status_property_matches_the_shared_retries()
-> Result<(), serde_json::Error> {
    let table = read_shared_table()?;

    assert!(!table.retries.is_empty());
    for case in table.retries {
        let status = derive_run_status(&build_steps(&case.after_retry));

        assert_eq!(status, case.status_after_retry, "{case:?}");
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_derive_run_status_property_shared_retries_start_from_a_stop(
        picked in any::<Index>(),
    ) {
        let table = read_shared_table()?;
        let case = picked.get(&table.retries);

        let before = derive_run_status(&build_steps(&case.steps));

        prop_assert!(is_run_stopped(before) || before == RunStatus::Done);
        prop_assert!(case.steps.iter().all(|status| is_step_finished(*status)));
        prop_assert!(!is_run_finished(case.status_after_retry));
    }
}
