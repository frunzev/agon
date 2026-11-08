use orchestration_core::run::Run;
use orchestration_core::run_lifecycle::is_run_finished;
use orchestration_core::task::Task;
use proptest::prelude::*;

use crate::follow_up_desk::{
    FollowUpDesk, count_active_runs, find_latest_run, open_follow_up_desk,
    status_shown_for,
};
use crate::follow_up_fixtures::{RunEnding, run_ending_strategy};
use crate::test_client::block_on;

const HISTORY_CASES: u32 = 8;
const FEWEST_ACTIONS: usize = 3;
const MOST_ACTIONS: usize = 10;

#[derive(Clone, Copy, Debug)]
pub enum HistoryAction {
    RunToEnd(RunEnding),
    StartOnly,
    Message { run_choice: usize },
    Relay { run_choice: usize },
    CancelActive,
}

#[derive(Debug)]
pub struct ObservedHistory {
    pub runs: Vec<Run>,
    pub task: Task,
}

fn history_action_strategy() -> impl Strategy<Value = HistoryAction> {
    prop_oneof![
        3 => run_ending_strategy().prop_map(HistoryAction::RunToEnd),
        1 => Just(HistoryAction::StartOnly),
        3 => any::<usize>()
            .prop_map(|run_choice| HistoryAction::Message { run_choice }),
        2 => any::<usize>()
            .prop_map(|run_choice| HistoryAction::Relay { run_choice }),
        1 => Just(HistoryAction::CancelActive),
    ]
}

pub fn history_strategy() -> impl Strategy<Value = Vec<HistoryAction>> {
    proptest::collection::vec(
        history_action_strategy(),
        FEWEST_ACTIONS..MOST_ACTIONS,
    )
}

async fn perform(desk: &FollowUpDesk, action: HistoryAction) {
    let runs = desk.list_runs().await;
    let active_run = runs.iter().find(|run| !is_run_finished(run.status));
    match action {
        HistoryAction::RunToEnd(ending) => {
            if active_run.is_none() {
                desk.run_to_end(ending).await;
            }
        }
        HistoryAction::StartOnly => {
            desk.start().await;
        }
        HistoryAction::Message { run_choice } => {
            if !runs.is_empty() {
                desk.send_message(&runs[run_choice % runs.len()], 0).await;
            }
        }
        HistoryAction::Relay { run_choice } => {
            if !runs.is_empty() {
                desk.relay_message(&runs[run_choice % runs.len()], 0).await;
            }
        }
        HistoryAction::CancelActive => {
            if let Some(active_run) = active_run {
                desk.end(active_run, RunEnding::Cancelled).await;
            }
        }
    }
}

pub fn observe_history(actions: &[HistoryAction]) -> Vec<ObservedHistory> {
    block_on(async {
        let desk = open_follow_up_desk().await;
        let mut observed = Vec::new();
        for action in actions {
            perform(&desk, *action).await;
            observed.push(ObservedHistory {
                runs: desk.list_runs().await,
                task: desk.read_task().await,
            });
        }
        observed
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(HISTORY_CASES))]

    #[test]
    fn test_append_chat_message_property_the_status_follows_the_latest_run(
        actions in history_strategy(),
    ) {
        let observed = observe_history(&actions);

        for step in &observed {
            let Some(latest) = find_latest_run(&step.runs) else {
                continue;
            };
            let shown = status_shown_for(latest.status);
            prop_assert_eq!(step.task.status, shown, "{:?}", step);
        }
    }

    #[test]
    fn test_send_person_message_property_one_active_run_at_most(
        actions in history_strategy(),
    ) {
        let observed = observe_history(&actions);

        for step in &observed {
            prop_assert!(count_active_runs(&step.runs) <= 1, "{:?}", step);
        }
    }

    #[test]
    fn test_apply_run_event_property_only_the_latest_run_is_ever_active(
        actions in history_strategy(),
    ) {
        let observed = observe_history(&actions);

        for step in &observed {
            let latest = find_latest_run(&step.runs);
            for run in &step.runs {
                let is_latest = latest.is_some_and(|found| found.id == run.id);
                let is_active = !is_run_finished(run.status);
                prop_assert!(!is_active || is_latest, "{:?}", step);
            }
        }
    }
}
