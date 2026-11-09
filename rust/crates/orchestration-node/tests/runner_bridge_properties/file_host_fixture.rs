use std::ffi::OsStr;
use std::fs;
use std::os::unix::ffi::OsStrExt;
use std::os::unix::fs::symlink;
use std::path::Path;
use std::process::Command;
use std::sync::LazyLock;
use std::time::Duration;

use orchestration_node::identity_store::{FileIdentityStore, IdentityStore};
use orchestration_p2p::peer_address::PeerAddress;
use serde_json::{Value, json};

use crate::support::command_builders::create_task_command;
use crate::support::git_origin::{LOCAL_REPOSITORY_ADDRESS, run_git};
use crate::support::runner_address::wait_for_runner_address;
use crate::support::test_device::{describe, read_text};
use crate::support::two_nodes::{TwoNodes, start_two_nodes_or_panic};
use crate::support::waiting::wait_for;

pub const CRAFTED_FILES: [(&str, &str); 4] = [
    ("src/app.ts", "export const answer = 42;\n"),
    (
        "docs/\u{fc}ber/na\u{ef}ve notes.md",
        "caf\u{e9} \u{4e16}\u{754c}\n",
    ),
    ("-dash.txt", "starts with a dash\n"),
    ("deep/a/b/c.txt", "deep\n"),
];
pub const LINK_NAME: &str = "outside-link";
pub const ODD_BRANCH: &str = "odd-names";
pub const ODD_TEXT_NAME: &str = "plain.txt";
pub const MAIN_BRANCH: &str = "main";
const LINK_TARGET: &str = "../../../etc/passwd";
const ODD_NAME_BYTES: &[u8] = b"bad-\xff-name.txt";
const WORK_FOLDER_NAME: &str = "crafted-work";
const FILES_LIMIT: Duration = Duration::from_secs(120);
const IDENTITY_FILE_NAME: &str = "device-identity.key";
const GIT_PROGRAM: &str = "git";
const PLAIN_FILE_MODE: &str = "100644";

#[derive(Debug)]
pub struct FileHost {
    pub nodes: TwoNodes,
    pub project_id: String,
    pub runner_id: String,
    pub runner_address: PeerAddress,
    pub client_secret: [u8; 32],
}

pub static FILE_HOST: LazyLock<Result<FileHost, String>> =
    LazyLock::new(prepare_file_host);

pub fn file_host() -> Result<&'static FileHost, String> {
    FILE_HOST.as_ref().map_err(Clone::clone)
}

fn prepare_file_host() -> Result<FileHost, String> {
    let nodes = start_two_nodes_or_panic();
    add_crafted_files(nodes.origin_root.path())?;
    let project_id = run_one_task(&nodes)?;
    let source = wait_for_source(&nodes, &project_id)?;
    let runner_id = read_text(&source, "/runner/device_id")?;
    let runner_address = wait_for_runner_address(&nodes);
    let client_secret = read_client_secret(&nodes)?;
    Ok(FileHost {
        nodes,
        project_id,
        runner_id,
        runner_address,
        client_secret,
    })
}

fn add_crafted_files(origin_root: &Path) -> Result<(), String> {
    let origin = origin_root.join(LOCAL_REPOSITORY_ADDRESS);
    let work = origin_root.join(WORK_FOLDER_NAME);
    let origin_text = origin.display().to_string();
    let work_text = work.display().to_string();
    run_git(origin_root, &["clone", "--quiet", &origin_text, &work_text])?;
    for (path, text) in CRAFTED_FILES {
        let target = work.join(path);
        let folder = target.parent().ok_or("the file has no folder")?;
        fs::create_dir_all(folder).map_err(describe)?;
        fs::write(target, text).map_err(describe)?;
    }
    symlink(LINK_TARGET, work.join(LINK_NAME)).map_err(describe)?;
    run_git(&work, &["add", "--all"])?;
    run_git(&work, &["commit", "--quiet", "--message", "Craft files"])?;
    run_git(&work, &["push", "--quiet", "origin", MAIN_BRANCH])?;
    add_odd_branch(&work)
}

fn add_odd_branch(work: &Path) -> Result<(), String> {
    run_git(work, &["checkout", "--quiet", "-b", ODD_BRANCH])?;
    fs::write(work.join(ODD_TEXT_NAME), "plain\n").map_err(describe)?;
    let blob = run_git(work, &["hash-object", "-w", ODD_TEXT_NAME])?;
    let mut cache_entry = format!("{PLAIN_FILE_MODE},{blob},").into_bytes();
    cache_entry.extend_from_slice(ODD_NAME_BYTES);
    let added = Command::new(GIT_PROGRAM)
        .args(["update-index", "--add", "--cacheinfo"])
        .arg(OsStr::from_bytes(&cache_entry))
        .current_dir(work)
        .status()
        .map_err(describe)?;
    if !added.success() {
        return Err("the odd name was not added".to_owned());
    }
    run_git(work, &["add", ODD_TEXT_NAME])?;
    run_git(work, &["commit", "--quiet", "--message", "Odd names"])?;
    run_git(work, &["push", "--quiet", "origin", ODD_BRANCH])?;
    Ok(())
}

fn run_one_task(nodes: &TwoNodes) -> Result<String, String> {
    let project = nodes.client.run(&json!({
        "command": "create_project",
        "workspace_id": nodes.workspace_id,
        "name": "acme-app",
        "repositories": [{
            "address": LOCAL_REPOSITORY_ADDRESS,
            "default_branch": MAIN_BRANCH,
            "agent_access": "read_only",
        }],
    }))?;
    let project_id = read_text(&project, "/id")?;
    let task = create_task_command(&nodes.workspace_id, &project_id, "plan");
    let created = nodes.client.run(&task)?;
    let run = nodes.client.run(&json!({
        "command": "start_task",
        "task_id": read_text(&created, "/id")?,
    }))?;
    let run_id = read_text(&run, "/id")?;
    wait_for(FILES_LIMIT, "the run to finish", || {
        let shown = nodes
            .client
            .run(&json!({ "command": "show_run", "run_id": run_id }))?;
        Ok((shown["run"]["status"] == "done").then_some(()))
    })?;
    Ok(project_id)
}

fn wait_for_source(
    nodes: &TwoNodes,
    project_id: &str,
) -> Result<Value, String> {
    let request = json!({
        "command": "list_repository_branches",
        "project_id": project_id,
        "repository_address": LOCAL_REPOSITORY_ADDRESS,
    });
    wait_for(FILES_LIMIT, "a runner with the repository", || {
        let reply = nodes.client.send(&request);
        let is_available = reply["ok"]["kind"] == "available";
        Ok(is_available.then(|| reply["ok"].clone()))
    })
}

fn read_client_secret(nodes: &TwoNodes) -> Result<[u8; 32], String> {
    let identity_path =
        nodes.client.data_directory.path().join(IDENTITY_FILE_NAME);
    let store = FileIdentityStore::new(identity_path);
    let secret = store.load_peer_secret().map_err(describe)?;
    let secret = secret.ok_or("the client has no peer secret")?;
    Ok(*secret)
}
