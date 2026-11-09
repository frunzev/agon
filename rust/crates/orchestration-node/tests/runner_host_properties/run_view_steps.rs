use std::thread;
use std::time::{Duration, Instant};

use orchestration_core::identifiers::RunId;
use serde_json::{Value, json};

use crate::file_host_fixture::FileHost;
use crate::support::command_builders::create_task_command;
use crate::support::test_device::{describe, read_text};
use crate::support::waiting::wait_for;

pub const DIRECT_LINK: &str = "direct";
pub const UNREACHABLE_LINK: &str = "unreachable";
pub const LOST_AT_FIELD: &str = "link_lost_at";
const RUN_LIMIT: Duration = Duration::from_secs(120);
const VIEW_LIMIT: Duration = Duration::from_secs(30);
const VIEW_PAUSE: Duration = Duration::from_millis(200);
const PLAN_DETAILS: &str = "plan the watched change";
const DONE_STATUS: &str = "done";

fn show_run(host: &FileHost, run_id: RunId) -> Result<Value, String> {
    let shown = host.nodes.client.run(&json!({
        "command": "show_run",
        "run_id": run_id.0.to_string(),
    }))?;
    Ok(shown["run"].clone())
}

pub fn finish_new_run(host: &FileHost) -> Result<RunId, String> {
    let client = &host.nodes.client;
    let workspace_id = &host.nodes.workspace_id;
    let task =
        create_task_command(workspace_id, &host.project_id, PLAN_DETAILS);
    let created = client.run(&task)?;
    let started = client.run(&json!({
        "command": "start_task",
        "task_id": read_text(&created, "/id")?,
    }))?;
    let run_text = read_text(&started, "/id")?;
    let run_id: RunId =
        serde_json::from_value(json!(run_text)).map_err(describe)?;
    wait_for(RUN_LIMIT, "the run to finish", || {
        let run = show_run(host, run_id)?;
        Ok((run["status"] == DONE_STATUS).then_some(()))
    })?;
    Ok(run_id)
}

pub fn wait_for_server_link(
    host: &FileHost,
    run_id: RunId,
    expected_link: &str,
) -> Result<Value, String> {
    wait_for(VIEW_LIMIT, "the recorded runner link", || {
        let run = show_run(host, run_id)?;
        Ok((run["link"] == expected_link).then_some(run))
    })
}

pub fn stays_linked(
    host: &FileHost,
    run_id: RunId,
    period: Duration,
) -> Result<bool, String> {
    let deadline = Instant::now() + period;
    while Instant::now() < deadline {
        let run = show_run(host, run_id)?;
        if run["link"] != DIRECT_LINK {
            return Ok(false);
        }
        thread::sleep(VIEW_PAUSE);
    }
    Ok(true)
}

pub fn read_chat_texts(
    host: &FileHost,
    run_id: RunId,
) -> Result<Vec<String>, String> {
    let run = show_run(host, run_id)?;
    let messages = run["chat"].as_array().cloned().unwrap_or_default();
    let mut texts = Vec::new();
    for message in messages {
        if let Some(text) = message["text"].as_str() {
            texts.push(text.to_owned());
        }
    }
    Ok(texts)
}

pub fn wait_for_chat_text(
    host: &FileHost,
    run_id: RunId,
    text: &str,
) -> Result<(), String> {
    wait_for(VIEW_LIMIT, "the chat in the run history", || {
        let texts = read_chat_texts(host, run_id)?;
        Ok(texts.iter().any(|known| known == text).then_some(()))
    })
}
