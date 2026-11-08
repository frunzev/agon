#![cfg(not(any(feature = "runner", feature = "app-server")))]

#[allow(dead_code)]
#[path = "../command_handler_featureless_properties/featureless_node.rs"]
mod featureless_node;
#[allow(dead_code)]
#[path = "../command_handler_featureless_properties/test_device.rs"]
mod test_device;
#[allow(dead_code)]
#[path = "../node/support/test_server.rs"]
mod test_server;

mod backup_refusal_properties;
