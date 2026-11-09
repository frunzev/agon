use orchestration_core::device::Device;
use orchestration_core::identifiers::WorkspaceId;
use orchestration_core::peer_address::ENDPOINT_PUBLIC_KEY_LENGTH;
use orchestration_core::workspace::Project;

use crate::device_roles::can_decide_approvals;
use crate::live_link_messages::RepositoryReference;
use crate::node_error::NodeError;
use crate::peer_side::trusted_peer_address;

pub fn check_file_reader(
    devices: &[Device],
    projects: &[Project],
    reader_key: &[u8; ENDPOINT_PUBLIC_KEY_LENGTH],
    repository: &RepositoryReference,
) -> Result<(), NodeError> {
    for reader in find_devices_with_peer_key(devices, reader_key) {
        let verdict = check_reader_access(reader, projects, repository);
        if !matches!(verdict, Err(NodeError::UntrustedFileReader)) {
            return verdict;
        }
    }
    Err(NodeError::UntrustedFileReader)
}

pub fn check_reader_access(
    reader: &Device,
    projects: &[Project],
    repository: &RepositoryReference,
) -> Result<(), NodeError> {
    let project = projects
        .iter()
        .find(|project| project.id == repository.project_id)
        .ok_or(NodeError::UntrustedFileReader)?;
    if !is_trusted_client(reader, project.workspace_id) {
        return Err(NodeError::UntrustedFileReader);
    }

    let holds_repository = project
        .repositories
        .iter()
        .any(|listed| listed.address == repository.address);
    if !holds_repository {
        let address = repository.address.clone();
        return Err(NodeError::RepositoryOutsideProject(address));
    }
    Ok(())
}

pub(crate) fn is_trusted_client(
    device: &Device,
    workspace_id: WorkspaceId,
) -> bool {
    !device.revoked
        && can_decide_approvals(device.role)
        && device.workspaces.contains(&workspace_id)
}

pub(crate) fn find_devices_with_peer_key<'devices>(
    devices: &'devices [Device],
    endpoint_key: &[u8; ENDPOINT_PUBLIC_KEY_LENGTH],
) -> Vec<&'devices Device> {
    let mut claimants = Vec::new();
    for device in devices {
        if has_peer_key(device, endpoint_key) {
            claimants.push(device);
        }
    }
    claimants
}

fn has_peer_key(
    device: &Device,
    endpoint_key: &[u8; ENDPOINT_PUBLIC_KEY_LENGTH],
) -> bool {
    trusted_peer_address(device)
        .is_ok_and(|address| &address.endpoint_public_key == endpoint_key)
}
