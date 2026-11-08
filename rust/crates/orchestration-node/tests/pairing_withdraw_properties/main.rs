#[allow(dead_code)]
#[path = "../node/support/mod.rs"]
mod support;

#[allow(dead_code)]
#[path = "../rendezvous_pairing_properties/approver_desk.rs"]
mod approver_desk;
#[allow(dead_code)]
#[path = "../rendezvous_pairing_properties/at_once.rs"]
mod at_once;
#[allow(dead_code)]
#[path = "../rendezvous_pairing_properties/command_device.rs"]
mod command_device;
#[allow(dead_code)]
#[path = "../rendezvous_pairing_properties/meddling_server.rs"]
mod meddling_server;
#[allow(dead_code)]
#[path = "../node_leftover_properties/slow_board.rs"]
mod slow_board;

mod board_wait_properties;
mod refused_reject_properties;
mod session_expiry_properties;
mod silent_withdraw_properties;
mod skipping_clock_server;
