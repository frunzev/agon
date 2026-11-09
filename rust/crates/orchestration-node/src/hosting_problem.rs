use serde::Serialize;

use crate::node_error::NodeError;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum HostingProblemKind {
    PortUnavailable,
    RecordDamaged,
    ServerFailed,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct HostingProblem {
    pub kind: HostingProblemKind,
    pub explanation: String,
}

pub(crate) fn describe_failed_start(problem: &NodeError) -> HostingProblem {
    let kind = match problem {
        NodeError::AppServerPortUnavailable { .. } => {
            HostingProblemKind::PortUnavailable
        }
        NodeError::HostedServerDamaged(_)
        | NodeError::InvalidServerAddress(_)
        | NodeError::DamagedRecord(_) => HostingProblemKind::RecordDamaged,
        _ => HostingProblemKind::ServerFailed,
    };
    HostingProblem {
        kind,
        explanation: problem.to_string(),
    }
}
