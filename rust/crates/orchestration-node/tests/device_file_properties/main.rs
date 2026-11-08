#[allow(dead_code)]
#[path = "../node/support/mod.rs"]
mod support;

mod account_record_properties;
mod agent_offer_file_properties;
mod atomic_write_properties;
mod device_folder;
mod device_path_properties;
mod device_role_properties;
#[cfg(unix)]
mod file_mode_properties;
mod file_replacement_properties;
mod join_and_group_record_properties;
#[cfg(unix)]
mod linked_removal_properties;
mod path_checks;
mod pending_join_view_properties;
mod record_checks;
mod record_removal_properties;
mod record_strategies;
mod role_device;
mod sealed_credential_properties;
mod sealed_file_properties;
mod sealed_forget_properties;
mod sealed_identity_properties;
mod sealed_peer_secret_properties;
mod sealed_store_desk;
mod server_path_properties;
mod server_record_properties;
mod temporary_path_properties;
