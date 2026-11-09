use std::collections::BTreeMap;

use orchestration_api::work::{RunEvent, RunEventsRequest};
use orchestration_core::device::RunnerLink;
use orchestration_core::identifiers::RunId;
use orchestration_runner::runner_server::RunnerServer;
use tokio::sync::Mutex;

use super::node_runner_server::NodeRunnerServer;

#[derive(Debug, Default)]
pub(crate) struct RunWatchers {
    watcher_counts: Mutex<BTreeMap<RunId, usize>>,
}

impl RunWatchers {
    pub(crate) async fn welcome(
        &self,
        server: &NodeRunnerServer,
        run_id: RunId,
        link: RunnerLink,
    ) {
        let mut watcher_counts = self.watcher_counts.lock().await;
        let watcher_count = watcher_counts.entry(run_id).or_default();
        *watcher_count += 1;
        post_link_change(server, run_id, link).await;
    }

    pub(crate) async fn see_off(
        &self,
        server: &NodeRunnerServer,
        run_id: RunId,
    ) {
        let mut watcher_counts = self.watcher_counts.lock().await;
        let watcher_count = watcher_counts.entry(run_id).or_default();
        *watcher_count = watcher_count.saturating_sub(1);
        if *watcher_count > 0 {
            return;
        }
        watcher_counts.remove(&run_id);
        post_link_change(server, run_id, RunnerLink::Unreachable).await;
    }
}

async fn post_link_change(
    server: &NodeRunnerServer,
    run_id: RunId,
    link: RunnerLink,
) {
    let request = RunEventsRequest {
        events: vec![RunEvent::LinkChanged { link }],
    };
    let _link_recorded = server.post_run_events(run_id, &request).await;
}
