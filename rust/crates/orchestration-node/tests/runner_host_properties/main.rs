#[allow(dead_code)]
#[path = "../node/support/mod.rs"]
mod support;

#[allow(dead_code)]
#[path = "../runner_bridge_properties/damaged_device_records.rs"]
mod damaged_device_records;
#[allow(dead_code)]
#[path = "../node_runtime_properties/damaged_server_records.rs"]
mod damaged_server_records;
#[allow(dead_code)]
#[path = "../runner_bridge_properties/file_host_fixture.rs"]
mod file_host_fixture;
#[allow(dead_code)]
#[path = "../runner_bridge_properties/file_host_steps.rs"]
mod file_host_steps;
#[allow(dead_code)]
#[path = "../node_leftover_properties/hosting_problem_steps.rs"]
mod hosting_problem_steps;
#[allow(dead_code)]
#[path = "../server_hosting_backup_properties/runtime_steps.rs"]
mod runtime_steps;

mod claimant_samples;
mod damaged_record_properties;
mod device_record_name_properties;
mod engine_scripts;
mod file_reader_claim_properties;
mod host_fact_properties;
mod host_label_properties;
mod image_name_properties;
mod image_probe_properties;
mod live_link_steps;
mod live_peer_properties;
mod live_refusal_properties;
mod live_watch_properties;
mod reader_trust_properties;
mod run_view_steps;
mod search_path_properties;
mod search_path_steps;
mod watcher_count_properties;
mod watcher_link_properties;
mod watcher_steps;
