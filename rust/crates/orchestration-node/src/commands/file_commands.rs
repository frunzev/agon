use orchestration_core::identifiers::{DeviceId, ProjectId};
use orchestration_core::repository_files::RepositoryEntry;
use orchestration_core::repository_paths::{
    normalize_file_path, normalize_folder_path,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;

use super::file_holders::ask_holder_for_files;
use super::repository_sources::{
    SourceSearch, find_runner_device, open_repository_source,
    require_project_repository, unexpected_answer,
};
use crate::command_reply::encode_reply;
use crate::live_link_messages::{
    FileAnswer, FileRequest, RepositoryReference,
};
use crate::node::{DeviceSession, Node};
use crate::node_error::NodeError;

pub(super) const FILE_COMMAND_NAMES: [&str; 3] = [
    "list_repository_branches",
    "list_repository_files",
    "read_repository_file",
];

#[derive(Debug, Deserialize)]
#[serde(tag = "command", rename_all = "snake_case", deny_unknown_fields)]
pub(super) enum FileCommand {
    ListRepositoryBranches {
        project_id: ProjectId,
        repository_address: String,
        #[serde(default)]
        preferred_runner_id: Option<DeviceId>,
    },
    ListRepositoryFiles {
        project_id: ProjectId,
        repository_address: String,
        runner_id: DeviceId,
        branch: String,
        folder: String,
    },
    ReadRepositoryFile {
        project_id: ProjectId,
        repository_address: String,
        runner_id: DeviceId,
        branch: String,
        path: String,
    },
}

#[derive(Debug, Serialize)]
struct FolderView {
    entries: Vec<RepositoryEntry>,
}

pub(super) async fn handle_file_command(
    node: &Node,
    command: FileCommand,
) -> Result<Value, NodeError> {
    match command {
        FileCommand::ListRepositoryBranches {
            project_id,
            repository_address,
            preferred_runner_id,
        } => {
            let session = node.open_session()?;
            let repository = require_project_repository(
                &session,
                project_id,
                &repository_address,
            )
            .await?;
            let preferred = preferred_runner_id.as_ref();
            list_repository_branches(node, &session, &repository, preferred)
                .await
        }
        FileCommand::ListRepositoryFiles {
            project_id,
            repository_address,
            runner_id,
            branch,
            folder,
        } => {
            let folder = normalize_folder_path(&folder)?;
            let session = node.open_session()?;
            let repository = require_project_repository(
                &session,
                project_id,
                &repository_address,
            )
            .await?;
            let request = FileRequest::ListFolder {
                repository,
                branch,
                folder,
            };
            let answer =
                ask_runner(node, &session, &runner_id, request).await?;
            let FileAnswer::Folder { entries } = answer else {
                return Err(unexpected_answer());
            };
            encode_reply(&FolderView { entries })
        }
        FileCommand::ReadRepositoryFile {
            project_id,
            repository_address,
            runner_id,
            branch,
            path,
        } => {
            let path = normalize_file_path(&path)?;
            let session = node.open_session()?;
            let repository = require_project_repository(
                &session,
                project_id,
                &repository_address,
            )
            .await?;
            let request = FileRequest::ReadFile {
                repository,
                branch,
                path,
            };
            let answer =
                ask_runner(node, &session, &runner_id, request).await?;
            let FileAnswer::File { file } = answer else {
                return Err(unexpected_answer());
            };
            encode_reply(&file)
        }
    }
}

async fn list_repository_branches(
    node: &Node,
    session: &DeviceSession,
    repository: &RepositoryReference,
    preferred_runner_id: Option<&DeviceId>,
) -> Result<Value, NodeError> {
    let client = session.client();
    let runners = client.list_runners().await?;
    let devices = client.list_devices().await?;
    let search = SourceSearch {
        node,
        session,
        runners: &runners,
        devices: &devices,
        preferred_runner_id,
    };
    let source = open_repository_source(&search, repository).await?;
    encode_reply(&source)
}

async fn ask_runner(
    node: &Node,
    session: &DeviceSession,
    runner_id: &DeviceId,
    request: FileRequest,
) -> Result<FileAnswer, NodeError> {
    let devices = session.client().list_devices().await?;
    let runner = find_runner_device(&devices, runner_id)?;
    ask_holder_for_files(node, session, runner, request).await
}
