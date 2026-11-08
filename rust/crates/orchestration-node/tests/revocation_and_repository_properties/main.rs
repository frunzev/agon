#[allow(dead_code)]
#[path = "../node/support/mod.rs"]
mod support;

#[allow(dead_code)]
#[path = "../../../orchestration-core/tests/repository_and_run_properties/address_strategies.rs"]
mod address_strategies;
#[allow(dead_code)]
#[path = "../hosting_properties/backup_group.rs"]
mod backup_group;
#[allow(dead_code)]
#[path = "../hosting_properties/hosting_desk.rs"]
mod hosting_desk;
#[allow(dead_code)]
#[path = "../node_leftover_properties/hosting_problem_steps.rs"]
mod hosting_problem_steps;
#[allow(dead_code)]
#[path = "../hosting_properties/logged_host.rs"]
mod logged_host;
#[allow(dead_code)]
#[path = "../hosting_properties/process_group.rs"]
mod process_group;
#[allow(dead_code)]
#[path = "../server_hosting_backup_properties/runtime_steps.rs"]
mod runtime_steps;

mod address_spellings;
mod answer_mismatch_properties;
mod damage_kind_properties;
mod damaged_hosting_steps;
mod endpoint_damage_properties;
mod fake_peer_answers;
mod fake_runner_peer;
mod file_question_steps;
mod file_spelling_properties;
mod node_side_check_properties;
mod refusal_following_properties;
mod refusal_steps;
mod remembered_refusal_properties;
