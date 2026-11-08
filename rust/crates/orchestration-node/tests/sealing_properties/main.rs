#[allow(dead_code)]
#[path = "../node/support/mod.rs"]
mod support;

#[allow(dead_code)]
#[path = "../command_handler_properties/handler_desk.rs"]
mod handler_desk;
#[allow(dead_code)]
#[path = "../work_command_properties/work_desk.rs"]
mod work_desk;
#[allow(dead_code)]
#[path = "../work_command_properties/workflow_desk.rs"]
mod workflow_desk;

mod chat_and_log_properties;
mod command_reading_properties;
mod dispatch_routing_properties;
mod keyless_listing_properties;
mod run_assignment_properties;
mod run_event_properties;
mod run_opening_properties;
mod run_sealing_samples;
mod sealed_document_properties;
mod sealed_key_properties;
mod sealed_line_properties;
mod sealing_samples;
mod skill_opening_properties;
mod task_and_rule_sealing_properties;
mod workflow_sealing_properties;
mod workflow_signature_properties;
mod workflow_view_properties;
mod workspace_keyring_properties;
