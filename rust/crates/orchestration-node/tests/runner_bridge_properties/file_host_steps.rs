use orchestration_node::live_link_messages::{
    ClientMessage, FileRequest, RepositoryReference, RunnerMessage,
    decode_link_message, encode_link_message,
};
use orchestration_p2p::peer_configuration::{PeerConfiguration, RelayChoice};
use orchestration_p2p::peer_endpoint::PeerEndpoint;
use serde_json::{Value, json};

use crate::file_host_fixture::FileHost;
use crate::support::git_origin::LOCAL_REPOSITORY_ADDRESS;
use crate::support::runner_access::test_runtime;
use crate::support::test_device::describe;

const RUNNER_HUNG_UP: &str = "the runner hung up";

pub fn repository_of(
    host: &FileHost,
    address: &str,
) -> Result<RepositoryReference, String> {
    let project_id =
        serde_json::from_value(json!(host.project_id)).map_err(describe)?;
    Ok(RepositoryReference {
        project_id,
        address: address.to_owned(),
    })
}

pub fn own_repository(host: &FileHost) -> Result<RepositoryReference, String> {
    repository_of(host, LOCAL_REPOSITORY_ADDRESS)
}

pub fn ask_raw(
    host: &FileHost,
    secret_key: [u8; 32],
    request: FileRequest,
) -> Result<RunnerMessage, String> {
    let runtime = test_runtime()?;
    runtime.block_on(async {
        let configuration = PeerConfiguration {
            secret_key,
            relay: RelayChoice::Disabled,
        };
        let endpoint =
            PeerEndpoint::bind(configuration).await.map_err(describe)?;
        let asked = ask_over(&endpoint, host, request).await;
        endpoint.close().await;
        asked
    })
}

async fn ask_over(
    endpoint: &PeerEndpoint,
    host: &FileHost,
    request: FileRequest,
) -> Result<RunnerMessage, String> {
    let mut link = endpoint
        .connect(&host.runner_address)
        .await
        .map_err(describe)?;
    let frame = encode_link_message(&ClientMessage::Browse { request })
        .map_err(describe)?;
    link.sender.send_frame(&frame).await.map_err(describe)?;
    let reply = link.receiver.receive_frame().await.map_err(describe)?;
    let reply = reply.ok_or_else(|| RUNNER_HUNG_UP.to_owned())?;
    decode_link_message::<RunnerMessage>(&reply).map_err(describe)
}

pub fn ask_client(host: &FileHost, command: &str, extra: &Value) -> Value {
    let mut request = json!({
        "command": command,
        "project_id": host.project_id,
        "repository_address": LOCAL_REPOSITORY_ADDRESS,
        "runner_id": host.runner_id,
    });
    if let (Some(fields), Some(extra_fields)) =
        (request.as_object_mut(), extra.as_object())
    {
        for (name, value) in extra_fields {
            fields.insert(name.clone(), value.clone());
        }
    }
    host.nodes.client.send(&request)
}

pub fn read_file(host: &FileHost, branch: &str, path: &str) -> Value {
    ask_client(
        host,
        "read_repository_file",
        &json!({ "branch": branch, "path": path }),
    )
}

pub fn list_folder(host: &FileHost, branch: &str, folder: &str) -> Value {
    ask_client(
        host,
        "list_repository_files",
        &json!({ "branch": branch, "folder": folder }),
    )
}

pub fn entry_names(reply: &Value) -> Vec<String> {
    let entries = reply["ok"]["entries"].as_array().cloned();
    let mut names = Vec::new();
    for entry in entries.unwrap_or_default() {
        if let Some(name) = entry["name"].as_str() {
            names.push(name.to_owned());
        }
    }
    names
}
