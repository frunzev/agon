use axum::http::StatusCode;
use orchestration_core::run::{Run, RunStatus};
use orchestration_core::run_lifecycle::is_run_finished;
use orchestration_core::task::TaskStatus;
use proptest::prelude::*;

use crate::active_run_desk::{
    ActiveRunDesk, RunAction, WorkKind, open_desk, work_kind_strategy,
};
use crate::test_client::block_on;

const RETRY_CASES: u32 = 16;
const FEWEST_STOPPED_RUNS: usize = 2;
const MOST_STOPPED_RUNS: usize = 5;
const FEWEST_ACTIONS: usize = 4;
const MOST_ACTIONS: usize = 14;

fn older_run_refusal(kind: WorkKind) -> String {
    let kind_name = match kind {
        WorkKind::Task => "task",
        WorkKind::Job => "job",
    };
    format!("only the latest run of the {kind_name} can be retried")
}

fn status_shown_for(run_status: RunStatus) -> TaskStatus {
    match run_status {
        RunStatus::Queued | RunStatus::Running => TaskStatus::Running,
        RunStatus::WaitingForApproval => TaskStatus::WaitingForApproval,
        RunStatus::Failed => TaskStatus::Failed,
        RunStatus::Cancelled => TaskStatus::ToDo,
        RunStatus::Done => TaskStatus::Done,
    }
}

fn weighted_run_action() -> impl Strategy<Value = RunAction> {
    prop_oneof![
        3 => Just(RunAction::Start),
        3 => Just(RunAction::CancelActive),
        2 => any::<usize>().prop_map(|run_choice| RunAction::Retry {
            run_choice,
        }),
        1 => Just(RunAction::SaveAndStart),
    ]
}

fn stopping_and_retrying_actions() -> impl Strategy<Value = Vec<RunAction>> {
    let later_actions = proptest::collection::vec(
        weighted_run_action(),
        FEWEST_ACTIONS..MOST_ACTIONS,
    );
    later_actions.prop_map(|later_actions| {
        let mut actions = Vec::new();
        for _ in 0..FEWEST_STOPPED_RUNS {
            actions.push(RunAction::Start);
            actions.push(RunAction::CancelActive);
        }
        actions.extend(later_actions);
        actions
    })
}

fn find_latest(runs: &[Run]) -> Option<&Run> {
    runs.iter().max_by_key(|run| run.number)
}

async fn start_and_cancel_runs(
    desk: &ActiveRunDesk,
    run_count: usize,
) -> Vec<Run> {
    for _ in 0..run_count {
        let started: Run = desk.start().await.json();
        desk.cancel(&started).await;
    }
    desk.list_runs().await
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RETRY_CASES))]

    #[test]
    fn test_retry_stored_run_property_an_older_run_is_refused(
        kind in work_kind_strategy(),
        run_count in FEWEST_STOPPED_RUNS..=MOST_STOPPED_RUNS,
        older_choice in any::<usize>(),
    ) {
        let desk = open_desk(kind.schedule());

        let (runs_before, task_before, response, runs_after, task_after) =
            block_on(async {
                let runs_before =
                    start_and_cancel_runs(&desk, run_count).await;
                let task_before = desk.read_task().await;
                let older_run = &runs_before[older_choice % (run_count - 1)];
                let response = desk.retry(older_run).await;
                let runs_after = desk.list_runs().await;
                let task_after = desk.read_task().await;
                (runs_before, task_before, response, runs_after, task_after)
            });

        prop_assert_eq!(response.status, StatusCode::CONFLICT);
        prop_assert_eq!(response.error_message(), older_run_refusal(kind));
        prop_assert_eq!(runs_after, runs_before);
        prop_assert_eq!(task_after, task_before);
    }

    #[test]
    fn test_retry_stored_run_property_the_latest_stopped_run_reopens(
        kind in work_kind_strategy(),
        run_count in FEWEST_STOPPED_RUNS..=MOST_STOPPED_RUNS,
    ) {
        let desk = open_desk(kind.schedule());

        let (latest_before, response, runs_after, task_after) =
            block_on(async {
                let runs_before =
                    start_and_cancel_runs(&desk, run_count).await;
                let latest_before = runs_before[run_count - 1].clone();
                let response = desk.retry(&latest_before).await;
                let runs_after = desk.list_runs().await;
                let task_after = desk.read_task().await;
                (latest_before, response, runs_after, task_after)
            });

        prop_assert_eq!(response.status, StatusCode::OK);
        let retried: Run = response.json();
        prop_assert_eq!(retried.id, latest_before.id);
        prop_assert_eq!(retried.number, latest_before.number);
        prop_assert!(!is_run_finished(retried.status));
        prop_assert_eq!(runs_after.len(), run_count);
        let latest_after = find_latest(&runs_after);
        prop_assert_eq!(latest_after, Some(&retried));
        prop_assert_eq!(task_after.status, status_shown_for(retried.status));
    }

    #[test]
    fn test_retry_stored_run_property_the_task_status_follows_the_latest_run(
        actions in stopping_and_retrying_actions(),
        kind in work_kind_strategy(),
    ) {
        let desk = open_desk(kind.schedule());

        let observed = desk.perform_all(&actions);

        for step in &observed {
            let Some(latest_run) = find_latest(&step.runs_after) else {
                prop_assert_eq!(step.task_after.status, TaskStatus::ToDo);
                continue;
            };
            prop_assert_eq!(
                step.task_after.status,
                status_shown_for(latest_run.status),
                "{:?}",
                step
            );
        }
    }
}
