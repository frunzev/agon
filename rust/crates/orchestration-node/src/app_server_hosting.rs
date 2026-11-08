mod group_keeping;
mod hosted_app_server;
mod hosted_endpoint;
mod hosted_listener;
mod hosting_logging;
mod peer_serving;
mod server_backup;

use std::fs;
use std::io::ErrorKind;

pub(crate) use group_keeping::keep_server_group;
pub(crate) use hosted_app_server::HostedAppServer;
pub use hosting_logging::describe_write_stopping_problem;
pub(crate) use server_backup::{start_server_backup, stop_server_backup};

use crate::device_files::HostedServerRecord;
use crate::file_removal::remove_file_if_present;
use crate::hosting_problem::{HostingProblem, HostingProblemKind};
use crate::node::Node;
use crate::node_error::NodeError;
use hosted_endpoint::bind_hosted_endpoint;
use hosted_listener::bind_hosted_listener;

#[derive(Debug)]
pub(crate) struct HostedServerAccess {
    pub(crate) local_address: String,
    pub(crate) setup_code: Option<String>,
}

pub(crate) async fn host_app_server(
    node: &Node,
) -> Result<HostedServerAccess, NodeError> {
    if let Some(hosted) = node.lock_hosted_app_server().as_ref() {
        return hosted.describe_access();
    }

    let record = HostedServerRecord {
        port: node.app_server_port(),
    };
    let hosted = start_hosted_server(node, &record).await?;
    node.device_files().save_hosted_server(&record)?;

    let access = hosted.describe_access();
    *node.lock_hosted_app_server() = Some(hosted);
    access
}

pub(crate) async fn restart_recorded_app_server(
    node: &Node,
) -> Result<(), HostingProblem> {
    let loaded_record = node
        .device_files()
        .load_hosted_server()
        .map_err(|problem| describe_unreadable_record(&problem))?;
    let Some(record) = loaded_record else {
        return Ok(());
    };
    let hosted = start_hosted_server(node, &record)
        .await
        .map_err(|problem| describe_failed_start(&problem))?;
    *node.lock_hosted_app_server() = Some(hosted);
    keep_server_group(node).map_err(|problem| describe_failed_start(&problem))
}

pub(crate) async fn stop_hosted_app_server(node: &Node) {
    let stopped_server = node.lock_hosted_app_server().take();
    if let Some(hosted) = stopped_server {
        hosted.stop().await;
    }
}

pub(crate) async fn forget_hosted_app_server(
    node: &Node,
) -> Result<(), NodeError> {
    stop_hosted_app_server(node).await;
    let record_path = node.device_files().hosted_server_record_path();
    remove_file_if_present(&record_path)
        .map_err(|problem| describe_not_removed(&problem))?;
    node.forget_hosting_problem();
    let server_directory = node.device_files().hosted_server_directory();
    match fs::remove_dir_all(&server_directory) {
        Err(problem) if problem.kind() != ErrorKind::NotFound => {
            Err(describe_not_removed(&problem))
        }
        _ => Ok(()),
    }
}

async fn start_hosted_server(
    node: &Node,
    record: &HostedServerRecord,
) -> Result<HostedAppServer, NodeError> {
    let listener = bind_hosted_listener(record.port)?;
    let server_directory = node.device_files().hosted_server_directory();
    let endpoint =
        bind_hosted_endpoint(&server_directory, node.peer_relay()).await?;
    HostedAppServer::start(listener, endpoint, &server_directory)
}

fn describe_not_removed(problem: &std::io::Error) -> NodeError {
    NodeError::HostedServerNotRemoved(problem.to_string())
}

fn describe_unreadable_record(problem: &NodeError) -> HostingProblem {
    let kind = match problem {
        NodeError::Json(_) => HostingProblemKind::RecordDamaged,
        _ => HostingProblemKind::ServerFailed,
    };
    HostingProblem {
        kind,
        explanation: problem.to_string(),
    }
}

fn describe_failed_start(problem: &NodeError) -> HostingProblem {
    let kind = match problem {
        NodeError::AppServerPortUnavailable { .. } => {
            HostingProblemKind::PortUnavailable
        }
        NodeError::HostedServerDamaged(_) => HostingProblemKind::RecordDamaged,
        _ => HostingProblemKind::ServerFailed,
    };
    HostingProblem {
        kind,
        explanation: problem.to_string(),
    }
}
