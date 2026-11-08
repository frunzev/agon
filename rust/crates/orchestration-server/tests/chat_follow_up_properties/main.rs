#![allow(clippy::expect_used)]

#[allow(dead_code)]
#[path = "../server_properties/claim_fixtures.rs"]
mod claim_fixtures;
#[allow(dead_code)]
#[path = "../server_properties/fixtures.rs"]
mod fixtures;
#[allow(dead_code)]
#[path = "../server_properties/follow_up_fixtures.rs"]
mod follow_up_fixtures;
#[allow(dead_code)]
#[path = "../server_properties/manual_clock.rs"]
mod manual_clock;
#[allow(dead_code)]
#[path = "../server_properties/pairing_fixtures.rs"]
mod pairing_fixtures;
#[allow(dead_code)]
#[path = "../server_properties/run_fixtures.rs"]
mod run_fixtures;
#[allow(dead_code)]
#[path = "../server_properties/test_client.rs"]
mod test_client;

mod follow_up_desk;
mod latest_run_properties;
mod legacy_active_run_properties;
mod older_run_message_properties;
mod relayed_message_properties;
mod run_event_coverage_properties;
mod run_history_properties;
mod task_status_properties;
