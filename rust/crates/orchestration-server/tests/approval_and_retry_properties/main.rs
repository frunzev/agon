#![allow(clippy::expect_used)]

#[allow(dead_code)]
#[path = "../single_active_run_properties/active_run_desk.rs"]
mod active_run_desk;
#[allow(dead_code)]
#[path = "../server_properties/fixtures.rs"]
mod fixtures;
#[allow(dead_code)]
#[path = "../server_properties/library_fixtures.rs"]
mod library_fixtures;
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
#[path = "../server_properties/skill_improvement_fixtures.rs"]
mod skill_improvement_fixtures;
#[allow(dead_code)]
#[path = "../server_properties/test_client.rs"]
mod test_client;

mod latest_run_retry_properties;
mod run_number_properties;
mod skill_proposal_desk;
mod skill_proposal_properties;
mod two_task_desk;
mod unsealed_improvement_properties;
