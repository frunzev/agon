use std::sync::Arc;
use std::time::Duration;

use chrono::Utc;
use orchestration_api::accounts::PublishPeerAddressRequest;
use orchestration_node::server_address::ServerAddress;
use orchestration_node::server_client::{PeerDialer, ServerClient};
use orchestration_p2p::peer_address::PeerAddress;
use orchestration_p2p::peer_configuration::RelayChoice;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::peer_addresses::sign_peer_address;
use serde_json::{Value, json};

use crate::support::runner_access::test_runtime;
use crate::support::test_device::{TestDevice, describe};
use crate::support::waiting::wait_for;

pub const ANNOUNCEMENT_LIMIT: Duration = Duration::from_secs(20);

pub fn read_announcement(device: &TestDevice) -> Result<Value, String> {
    let status = device.run(&json!({ "command": "status" }))?;
    Ok(status["peer"].clone())
}

pub fn wait_for_announcement(
    device: &TestDevice,
) -> Result<PeerAddress, String> {
    wait_for(ANNOUNCEMENT_LIMIT, "the announcer to publish", || {
        let announcement = read_announcement(device)?;
        let published = announcement["published_address"].clone();
        if published.is_null() {
            return Ok(None);
        }
        let address = serde_json::from_value(published).map_err(describe)?;
        Ok(Some(address))
    })
}

pub fn publish_address_for(
    server_address: &str,
    identity: &DeviceIdentity,
    address: &PeerAddress,
) -> Result<(), String> {
    let runtime = test_runtime()?;
    let dialer = Arc::new(PeerDialer::new(RelayChoice::Disabled));
    let parsed_address =
        ServerAddress::parse(server_address).map_err(describe)?;
    let client =
        ServerClient::connect(&parsed_address, &dialer).map_err(describe)?;
    let request = PublishPeerAddressRequest {
        address: sign_peer_address(identity, address, Utc::now()),
    };
    let signed_client = client.signed(identity);
    let publishing = signed_client.publish_peer_address(&request);
    runtime.block_on(publishing).map_err(describe)
}
