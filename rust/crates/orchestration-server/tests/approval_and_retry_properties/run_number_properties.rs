use axum::http::StatusCode;
use orchestration_core::run::Run;
use proptest::prelude::*;

use crate::test_client::block_on;
use crate::two_task_desk::{TwoTaskDesk, open_two_task_desk};

const NUMBER_CASES: u32 = 6;
const MOST_RUNS_PER_TASK: usize = 4;
const OLDER_RUN_REFUSAL: &str =
    "only the latest run of the task can be retried";
const ALREADY_RUNNING: &str = "the task is already running";

fn run_numbers(runs: &[Run]) -> Vec<u32> {
    runs.iter().map(|run| run.number).collect()
}

fn numbers_from_one(count: usize) -> Vec<u32> {
    (1..=count)
        .map(|number| u32::try_from(number).unwrap_or(u32::MAX))
        .collect()
}

async fn stop_runs_in_turns(
    desk: &TwoTaskDesk,
    turns: &[bool],
) -> (Vec<Run>, Vec<Run>) {
    for is_first_task in turns {
        let task_id = if *is_first_task {
            desk.first_task
        } else {
            desk.second_task
        };
        desk.start_and_cancel(task_id).await;
    }
    let first_runs = desk.list_runs(desk.first_task).await;
    let second_runs = desk.list_runs(desk.second_task).await;
    (first_runs, second_runs)
}

fn count_turns(turns: &[bool], is_first_task: bool) -> usize {
    turns.iter().filter(|turn| **turn == is_first_task).count()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NUMBER_CASES))]

    #[test]
    fn test_next_run_number_property_numbers_count_from_one_per_task(
        turns in proptest::collection::vec(any::<bool>(), 1..9),
    ) {
        let (first_runs, second_runs) = block_on(async {
            let desk = open_two_task_desk().await;
            stop_runs_in_turns(&desk, &turns).await
        });

        let first_count = count_turns(&turns, true);
        let second_count = count_turns(&turns, false);
        prop_assert_eq!(
            run_numbers(&first_runs),
            numbers_from_one(first_count)
        );
        prop_assert_eq!(
            run_numbers(&second_runs),
            numbers_from_one(second_count)
        );
    }

    #[test]
    fn test_next_run_number_property_a_retry_takes_no_new_number(
        run_count in 1..=MOST_RUNS_PER_TASK,
    ) {
        let numbers = block_on(async {
            let desk = open_two_task_desk().await;
            let task_id = desk.first_task;
            for _ in 0..run_count {
                desk.start_and_cancel(task_id).await;
            }
            let runs = desk.list_runs(task_id).await;
            let retried: Run = desk.retry(&runs[run_count - 1]).await.json();
            desk.cancel(&retried).await;
            desk.start_and_cancel(task_id).await;
            run_numbers(&desk.list_runs(task_id).await)
        });

        prop_assert_eq!(numbers, numbers_from_one(run_count + 1));
    }

    #[test]
    fn test_next_run_number_property_numbers_never_repeat(
        turns in proptest::collection::vec(any::<bool>(), 1..9),
    ) {
        let (first_runs, second_runs) = block_on(async {
            let desk = open_two_task_desk().await;
            stop_runs_in_turns(&desk, &turns).await
        });

        for runs in [&first_runs, &second_runs] {
            let mut numbers = run_numbers(runs);
            numbers.dedup();
            prop_assert_eq!(numbers.len(), runs.len());
        }
    }

    #[test]
    fn test_find_latest_run_number_property_counts_only_the_tasks_own_runs(
        turns in proptest::collection::vec(any::<bool>(), 2..9),
    ) {
        prop_assume!(turns.contains(&true) && turns.contains(&false));

        let statuses = block_on(async {
            let desk = open_two_task_desk().await;
            let (first_runs, second_runs) =
                stop_runs_in_turns(&desk, &turns).await;
            let first_latest = &first_runs[first_runs.len() - 1];
            let second_latest = &second_runs[second_runs.len() - 1];
            let first_status = desk.retry(first_latest).await.status;
            let second_status = desk.retry(second_latest).await.status;
            (first_status, second_status)
        });

        prop_assert_eq!(statuses, (StatusCode::OK, StatusCode::OK));
    }

    #[test]
    fn test_find_latest_run_number_property_the_retried_latest_stays_latest(
        run_count in 2..=MOST_RUNS_PER_TASK,
        older_choice in any::<usize>(),
    ) {
        let (latest_again, older) = block_on(async {
            let desk = open_two_task_desk().await;
            let task_id = desk.first_task;
            for _ in 0..run_count {
                desk.start_and_cancel(task_id).await;
            }
            let runs = desk.list_runs(task_id).await;
            let retried: Run = desk.retry(&runs[run_count - 1]).await.json();
            desk.cancel(&retried).await;
            let latest_again = desk.retry(&retried).await;
            desk.cancel(&retried).await;
            let older_run = &runs[older_choice % (run_count - 1)];
            let older = desk.retry(older_run).await;
            (latest_again, older)
        });

        prop_assert_eq!(latest_again.status, StatusCode::OK);
        prop_assert_eq!(older.status, StatusCode::CONFLICT);
        prop_assert_eq!(older.error_message(), OLDER_RUN_REFUSAL);
    }

    #[test]
    fn test_find_latest_run_number_property_other_tasks_runs_never_count(
        later_runs in 1..=MOST_RUNS_PER_TASK,
    ) {
        let status = block_on(async {
            let desk = open_two_task_desk().await;
            let only_run = desk.start_and_cancel(desk.first_task).await;
            for _ in 0..later_runs {
                desk.start_and_cancel(desk.second_task).await;
            }
            desk.retry(&only_run).await.status
        });

        prop_assert_eq!(status, StatusCode::OK);
    }

    #[test]
    fn test_refuse_retrying_older_run_property_every_older_run_is_refused(
        run_count in 2..=MOST_RUNS_PER_TASK,
    ) {
        let (older_statuses, latest_status) = block_on(async {
            let desk = open_two_task_desk().await;
            let task_id = desk.first_task;
            for _ in 0..run_count {
                desk.start_and_cancel(task_id).await;
            }
            let runs = desk.list_runs(task_id).await;
            let mut older_statuses = Vec::new();
            for older_run in &runs[..run_count - 1] {
                older_statuses.push(desk.retry(older_run).await.status);
            }
            let latest_status = desk.retry(&runs[run_count - 1]).await.status;
            (older_statuses, latest_status)
        });

        prop_assert!(older_statuses
            .iter()
            .all(|status| *status == StatusCode::CONFLICT));
        prop_assert_eq!(latest_status, StatusCode::OK);
    }

    #[test]
    fn test_refuse_retrying_older_run_property_an_active_latest_names_running(
        run_count in 2..=MOST_RUNS_PER_TASK,
        older_choice in any::<usize>(),
    ) {
        let older = block_on(async {
            let desk = open_two_task_desk().await;
            let task_id = desk.first_task;
            for _ in 0..run_count {
                desk.start_and_cancel(task_id).await;
            }
            let runs = desk.list_runs(task_id).await;
            desk.retry(&runs[run_count - 1]).await;
            let older_run = &runs[older_choice % (run_count - 1)];
            desk.retry(older_run).await
        });

        prop_assert_eq!(older.status, StatusCode::CONFLICT);
        prop_assert_eq!(older.error_message(), ALREADY_RUNNING);
    }

    #[test]
    fn test_refuse_retrying_older_run_property_the_older_run_stays_stopped(
        run_count in 2..=MOST_RUNS_PER_TASK,
        older_choice in any::<usize>(),
    ) {
        let (before, after) = block_on(async {
            let desk = open_two_task_desk().await;
            let task_id = desk.first_task;
            for _ in 0..run_count {
                desk.start_and_cancel(task_id).await;
            }
            let before = desk.list_runs(task_id).await;
            let older_run = &before[older_choice % (run_count - 1)];
            desk.retry(older_run).await;
            let after = desk.list_runs(task_id).await;
            (before, after)
        });

        prop_assert_eq!(after, before);
    }
}
