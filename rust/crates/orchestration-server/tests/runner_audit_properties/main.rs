#![allow(clippy::expect_used)]

#[allow(dead_code)]
#[path = "../server_properties/fixtures.rs"]
mod fixtures;
#[allow(dead_code)]
#[path = "../server_properties/manual_clock.rs"]
mod manual_clock;
#[allow(dead_code)]
#[path = "../server_properties/pairing_fixtures.rs"]
mod pairing_fixtures;
#[allow(dead_code)]
#[path = "../server_properties/test_client.rs"]
mod test_client;

mod heartbeat_audit_properties;
