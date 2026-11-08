#![cfg(not(any(feature = "runner", feature = "app-server")))]

#[allow(dead_code)]
#[path = "../node/support/test_server.rs"]
mod test_server;

mod featureless_node;
mod hosting_refusal_properties;
mod own_copy_properties;
mod runner_refusal_properties;
mod test_device;
