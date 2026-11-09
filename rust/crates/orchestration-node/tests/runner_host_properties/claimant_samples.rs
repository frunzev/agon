use orchestration_core::device::{Device, DeviceRole};
use orchestration_core::peer_address::PeerAddress;
use orchestration_node::node_error::NodeError;
use orchestration_node::runner_bridge::check_file_reader;
use orchestration_security::identity::{
    DeviceIdentity, IDENTITY_SECRET_LENGTH,
};
use orchestration_security::peer_addresses::sign_peer_address;
use proptest::prelude::*;

use crate::support::entity_strategies::sample_time;
use crate::support::file_reader_samples::{
    ADDRESS, READER_KEY, ReaderShape, build_device, project, reader_shape,
    reference,
};
use crate::support::test_device::describe;

pub const OTHER_KEY: [u8; 32] = [43; 32];
pub const MOST_CLAIMANTS: usize = 5;
const ADMITTED: &str = "admitted";

#[derive(Clone, Copy, Debug)]
pub struct Claimant {
    pub shape: ReaderShape,
    pub claims_reader_key: bool,
}

fn build_claimant_shape(parts: (ReaderShape, bool)) -> Claimant {
    let (shape, claims_reader_key) = parts;
    Claimant {
        shape,
        claims_reader_key,
    }
}

pub fn claimant_strategy() -> impl Strategy<Value = Claimant> {
    (reader_shape(), any::<bool>()).prop_map(build_claimant_shape)
}

pub fn forge_claim(claimant: Claimant) -> Claimant {
    let forged_shape = ReaderShape {
        signs_address: false,
        ..claimant.shape
    };
    Claimant {
        shape: forged_shape,
        ..claimant
    }
}

pub fn claim_other_key(claimant: Claimant) -> Claimant {
    Claimant {
        claims_reader_key: false,
        ..claimant
    }
}

fn build_claimant(claimant: Claimant, seed: u8) -> Result<Device, String> {
    let mut device = build_device(claimant.shape, seed)?;
    if claimant.claims_reader_key {
        return Ok(device);
    }
    let secret = [seed; IDENTITY_SECRET_LENGTH];
    let identity =
        DeviceIdentity::from_secret_bytes(&secret).map_err(describe)?;
    let address = PeerAddress {
        endpoint_public_key: OTHER_KEY,
        direct_addresses: Vec::new(),
        relay_url: None,
    };
    let signed = sign_peer_address(&identity, &address, sample_time());
    device.peer_address = Some(signed);
    Ok(device)
}

pub fn build_claimants(claimants: &[Claimant]) -> Result<Vec<Device>, String> {
    let mut devices = Vec::new();
    for (index, claimant) in claimants.iter().enumerate() {
        let seed = u8::try_from(index + 1).map_err(describe)?;
        devices.push(build_claimant(*claimant, seed)?);
    }
    Ok(devices)
}

pub fn is_trusted_client(shape: ReaderShape) -> bool {
    shape.role != DeviceRole::Runner && !shape.revoked && shape.in_workspace
}

pub fn is_trusted_claim(claimant: Claimant) -> bool {
    claimant.claims_reader_key
        && claimant.shape.signs_address
        && is_trusted_client(claimant.shape)
}

pub fn describe_verdict(verdict: &Result<(), NodeError>) -> String {
    match verdict {
        Ok(()) => ADMITTED.to_owned(),
        Err(problem) => problem.to_string(),
    }
}

pub fn read_with(devices: &[Device]) -> Result<(), NodeError> {
    check_file_reader(devices, &[project()], &READER_KEY, &reference(ADDRESS))
}
