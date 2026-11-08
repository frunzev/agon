use axum::http::StatusCode;
use orchestration_api::routes::TASKS;
use orchestration_api::work::{RunEvent, SendChatMessageRequest, TaskStart};
use orchestration_core::device::{DeviceRole, RunnerTarget};
use orchestration_core::identifiers::TaskId;
use orchestration_core::run::{Run, RunFailure, RunStatus, StepStatus};
use orchestration_core::run_lifecycle::is_run_finished;
use orchestration_core::task::{Task, TaskStatus};
use orchestration_security::identity::DeviceIdentity;
use proptest::prelude::*;

use crate::fixtures::{
    Account, SEALED_DETAILS, create_account, create_project, heartbeat_with,
    identity_from_seed, one_agent_task, pair_device, save_task,
    send_heartbeat,
};
use crate::follow_up_fixtures::{RunEnding, person_message};
use crate::run_fixtures::{claim_by, post_events, run_path};
use crate::test_client::{TestResponse, TestServer};

const RUNNER_SEED: u8 = 150;
const RUNNER_NAME: &str = "studio-runner";
const RUNNER_SLOTS: u32 = 1;
pub const FEWEST_RUNS: usize = 2;
pub const MOST_RUNS: usize = 4;

#[derive(Debug)]
pub struct FollowUpDesk {
    pub test: TestServer,
    pub account: Account,
    pub runner: DeviceIdentity,
    pub task_id: TaskId,
}

pub fn run_endings_strategy() -> impl Strategy<Value = Vec<RunEnding>> {
    let ending = prop_oneof![
        Just(RunEnding::Done),
        Just(RunEnding::Failed),
        Just(RunEnding::Cancelled),
    ];
    proptest::collection::vec(ending, FEWEST_RUNS..=MOST_RUNS)
}

pub fn status_shown_for(run_status: RunStatus) -> TaskStatus {
    match run_status {
        RunStatus::Queued | RunStatus::Running => TaskStatus::Running,
        RunStatus::WaitingForApproval => TaskStatus::WaitingForApproval,
        RunStatus::Failed => TaskStatus::Failed,
        RunStatus::Cancelled => TaskStatus::ToDo,
        RunStatus::Done => TaskStatus::Done,
    }
}

pub fn count_active_runs(runs: &[Run]) -> usize {
    let mut active_count = 0;
    for run in runs {
        if !is_run_finished(run.status) {
            active_count += 1;
        }
    }
    active_count
}

pub fn find_latest_run(runs: &[Run]) -> Option<&Run> {
    runs.iter().max_by_key(|run| run.number)
}

pub async fn open_follow_up_desk() -> FollowUpDesk {
    let test = TestServer::start();
    let account = create_account(&test).await;
    let project = create_project(&test, &account).await;
    let runner = identity_from_seed(RUNNER_SEED);
    pair_device(&test, &account, &runner, RUNNER_NAME, DeviceRole::Runner)
        .await;
    let task = one_agent_task(project.id, RunnerTarget::AnyFreeRunner, None);
    let saved = save_task(&test, &account, task, TaskStart::Later).await;
    FollowUpDesk {
        test,
        account,
        runner,
        task_id: saved.task.id,
    }
}

impl FollowUpDesk {
    pub async fn start(&self) -> TestResponse {
        let path = format!("/tasks/{}/runs", self.task_id.0);
        self.test.post_empty(&self.account.owner, &path).await
    }

    pub async fn claim(&self) -> Option<Run> {
        let heartbeat = heartbeat_with(&[], RUNNER_SLOTS, 0);
        send_heartbeat(&self.test, &self.runner, &heartbeat).await;
        claim_by(&self.test, &self.runner).await
    }

    pub async fn run_to_end(&self, ending: RunEnding) -> Run {
        let response = self.start().await;
        assert_eq!(response.status, StatusCode::CREATED, "{response:?}");
        let claimed = self.claim().await.expect("the runner claims the run");
        self.change_step(&claimed, StepStatus::Running).await;
        self.end(&claimed, ending).await;
        self.read_run(&claimed).await
    }

    pub async fn run_all_to_end(&self, endings: &[RunEnding]) -> Vec<Run> {
        for ending in endings {
            self.run_to_end(*ending).await;
        }
        self.list_runs().await
    }

    pub async fn change_step(&self, run: &Run, status: StepStatus) {
        let event = RunEvent::StepStatusChanged {
            step_name: run.steps[0].name.clone(),
            status,
        };
        let (response_status, _run) =
            post_events(&self.test, &self.runner, run, vec![event]).await;
        assert_eq!(response_status, StatusCode::OK);
    }

    pub async fn end(&self, run: &Run, ending: RunEnding) {
        match ending {
            RunEnding::Done => self.change_step(run, StepStatus::Done).await,
            RunEnding::Failed => self.fail(run).await,
            RunEnding::Cancelled => {
                let path = format!("{}/cancel", run_path(run));
                let owner = &self.account.owner;
                let response = self.test.post_empty(owner, &path).await;
                assert_eq!(response.status, StatusCode::OK, "{response:?}");
            }
        }
    }

    async fn fail(&self, run: &Run) {
        let failure = RunFailure {
            step_name: run.steps[0].name.clone(),
            runner: Some(self.runner.device_id()),
            reason: SEALED_DETAILS.to_owned(),
            retry_runs_on_same_runner: false,
        };
        let events = vec![RunEvent::Failed { failure }];
        let (status, _run) =
            post_events(&self.test, &self.runner, run, events).await;
        assert_eq!(status, StatusCode::OK);
    }

    pub async fn send_message(
        &self,
        run: &Run,
        position: usize,
    ) -> TestResponse {
        let path = format!("{}/messages", run_path(run));
        let request = SendChatMessageRequest {
            message: person_message(&self.test, position),
        };
        self.test.post(&self.account.owner, &path, &request).await
    }

    pub async fn relay_message(
        &self,
        run: &Run,
        position: usize,
    ) -> (StatusCode, Option<Run>) {
        let message = person_message(&self.test, position);
        let events = vec![RunEvent::ChatAppended { message }];
        post_events(&self.test, &self.runner, run, events).await
    }

    pub async fn retry(&self, run: &Run) -> TestResponse {
        let path = format!("{}/retry", run_path(run));
        self.test.post_empty(&self.account.owner, &path).await
    }

    pub async fn read_run(&self, run: &Run) -> Run {
        let response =
            self.test.get(&self.account.owner, &run_path(run)).await;
        response.json()
    }

    pub async fn list_runs(&self) -> Vec<Run> {
        let path = format!("/tasks/{}/runs", self.task_id.0);
        let response = self.test.get(&self.account.owner, &path).await;
        let mut runs: Vec<Run> = response.json();
        runs.sort_by_key(|run| run.number);
        runs
    }

    pub async fn read_task(&self) -> Task {
        let tasks: Vec<Task> =
            self.test.get(&self.account.owner, TASKS).await.json();
        tasks
            .into_iter()
            .find(|task| task.id == self.task_id)
            .expect("the desk task stays saved")
    }
}
