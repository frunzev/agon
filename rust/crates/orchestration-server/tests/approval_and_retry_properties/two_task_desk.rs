use orchestration_api::work::TaskStart;
use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::TaskId;
use orchestration_core::run::Run;

use crate::fixtures::{
    Account, create_account, create_project, one_agent_task, save_task,
};
use crate::test_client::{TestResponse, TestServer};

#[derive(Debug)]
pub struct TwoTaskDesk {
    pub test: TestServer,
    pub account: Account,
    pub first_task: TaskId,
    pub second_task: TaskId,
}

pub async fn open_two_task_desk() -> TwoTaskDesk {
    let test = TestServer::start();
    let account = create_account(&test).await;
    let project = create_project(&test, &account).await;
    let mut task_ids = Vec::new();
    for _ in 0..2 {
        let task =
            one_agent_task(project.id, RunnerTarget::AnyFreeRunner, None);
        let saved = save_task(&test, &account, task, TaskStart::Later).await;
        task_ids.push(saved.task.id);
    }
    TwoTaskDesk {
        test,
        account,
        first_task: task_ids[0],
        second_task: task_ids[1],
    }
}

impl TwoTaskDesk {
    pub async fn start_and_cancel(&self, task_id: TaskId) -> Run {
        let start_path = format!("/tasks/{}/runs", task_id.0);
        let owner = &self.account.owner;
        let started: Run =
            self.test.post_empty(owner, &start_path).await.json();
        let cancel_path = format!("/runs/{}/cancel", started.id.0);
        self.test.post_empty(owner, &cancel_path).await.json()
    }

    pub async fn retry(&self, run: &Run) -> TestResponse {
        let path = format!("/runs/{}/retry", run.id.0);
        self.test.post_empty(&self.account.owner, &path).await
    }

    pub async fn cancel(&self, run: &Run) -> TestResponse {
        let path = format!("/runs/{}/cancel", run.id.0);
        self.test.post_empty(&self.account.owner, &path).await
    }

    pub async fn list_runs(&self, task_id: TaskId) -> Vec<Run> {
        let path = format!("/tasks/{}/runs", task_id.0);
        let mut runs: Vec<Run> =
            self.test.get(&self.account.owner, &path).await.json();
        runs.sort_by_key(|run| run.number);
        runs
    }
}
