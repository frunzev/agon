use chrono::{DateTime, Utc};
use orchestration_core::identifiers::RunId;
use orchestration_p2p::peer_link::PeerLink;
use proptest::sample::Index;
use serde_json::Value;

use crate::live_link_steps::{LinkSide, close_link, watch};
use crate::run_view_steps::{
    DIRECT_LINK, LOST_AT_FIELD, UNREACHABLE_LINK, wait_for_server_link,
};
use crate::support::test_device::describe;

pub fn open_watchers_of(
    side: &LinkSide,
    run_id: RunId,
    watcher_count: usize,
) -> Result<Vec<PeerLink>, String> {
    side.runtime.block_on(async {
        let mut links = Vec::new();
        for _ in 0..watcher_count {
            links.push(watch(side, run_id).await?);
        }
        Ok(links)
    })
}

pub fn open_watchers(
    side: &LinkSide,
    watcher_count: usize,
) -> Result<Vec<PeerLink>, String> {
    open_watchers_of(side, side.lone_run, watcher_count)
}

pub fn open_watchers_at_once(
    side: &'static LinkSide,
    watcher_count: usize,
) -> Result<Vec<PeerLink>, String> {
    side.runtime.block_on(async {
        let mut watchings = Vec::new();
        for _ in 0..watcher_count {
            watchings.push(tokio::spawn(watch(side, side.lone_run)));
        }
        let mut links = Vec::new();
        for watching in watchings {
            links.push(watching.await.map_err(describe)??);
        }
        Ok(links)
    })
}

pub fn close_watchers(
    side: &LinkSide,
    links: Vec<PeerLink>,
) -> Result<(), String> {
    side.runtime.block_on(async {
        for link in links {
            close_link(link).await?;
        }
        Ok(())
    })
}

pub fn link_and_wait(
    side: &LinkSide,
    watcher_count: usize,
) -> Result<Vec<PeerLink>, String> {
    let links = open_watchers(side, watcher_count)?;
    wait_for_server_link(side.host, side.lone_run, DIRECT_LINK)?;
    Ok(links)
}

pub fn unlink_and_wait(
    side: &LinkSide,
    links: Vec<PeerLink>,
) -> Result<Value, String> {
    close_watchers(side, links)?;
    wait_for_server_link(side.host, side.lone_run, UNREACHABLE_LINK)
}

pub fn read_lost_at(run: &Value) -> Result<DateTime<Utc>, String> {
    serde_json::from_value(run[LOST_AT_FIELD].clone()).map_err(describe)
}

pub fn take_one(
    mut links: Vec<PeerLink>,
    chosen: Index,
) -> (PeerLink, Vec<PeerLink>) {
    let chosen_position = chosen.index(links.len());
    let chosen_link = links.remove(chosen_position);
    (chosen_link, links)
}
