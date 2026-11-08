use serde::Serialize;

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
