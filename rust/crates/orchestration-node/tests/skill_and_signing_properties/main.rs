#[allow(dead_code)]
#[path = "../node/support/mod.rs"]
mod support;

#[allow(dead_code)]
#[path = "../sealing_properties/sealing_samples.rs"]
mod sealing_samples;
#[allow(dead_code)]
#[path = "../approval_and_forget_properties/unreadable_approval_desk.rs"]
mod unreadable_approval_desk;
#[allow(dead_code)]
#[path = "../work_command_properties/work_desk.rs"]
mod work_desk;
#[allow(dead_code)]
#[path = "../work_command_properties/workflow_desk.rs"]
mod workflow_desk;

mod reseal_helper_properties;
mod reverted_workflow_properties;
mod signed_reseal_properties;
mod unreadable_skill_desk;
mod unreadable_skill_listing_properties;
mod unreadable_skill_opening_properties;
