use proptest::prelude::*;
use serde_json::Value;

use crate::forget_race_desk::{
    check_forget_races, create_workspace_command, is_no_account_refusal,
    is_success, race_one_command, read_saved_account, read_saved_server_group,
    stall_one_command, status_command,
};
use crate::support::test_device::fail;

#[test]
fn test_require_current_identity_property_a_refused_status_names_no_account() {
    check_forget_races(|desk, race| {
        let outcome = race_one_command(desk, race, &status_command());

        let reply = &outcome.racing_reply;
        prop_assert!(
            is_success(reply) || is_no_account_refusal(reply),
            "{:?}",
            outcome
        );
        Ok(())
    });
}

#[test]
fn test_require_current_identity_property_a_refused_creation_names_no_account()
{
    check_forget_races(|desk, race| {
        let command = create_workspace_command(&race.workspace_name);

        let outcome = race_one_command(desk, race, &command);

        let reply = &outcome.racing_reply;
        prop_assert!(
            is_success(reply) || is_no_account_refusal(reply),
            "{:?}",
            outcome
        );
        Ok(())
    });
}

#[test]
fn test_require_current_identity_property_a_kept_device_refreshes() {
    check_forget_races(|desk, race| {
        let status = stall_one_command(desk, race, &status_command());

        prop_assert!(is_success(&status), "{:?}", status);
        let saved = read_saved_account(&desk.device).map_err(fail)?;
        let saved_device_id = saved.map(|account| account.device.id.0);
        let shown_device_id = status["ok"]["device_id"].as_str();
        prop_assert_eq!(saved_device_id.as_deref(), shown_device_id);
        Ok(())
    });
}

#[test]
fn test_describe_status_property_a_successful_status_shows_the_account() {
    check_forget_races(|desk, race| {
        let outcome = race_one_command(desk, race, &status_command());

        let reply = &outcome.racing_reply;
        if is_success(reply) {
            prop_assert_ne!(&reply["ok"]["device_id"], &Value::Null);
            prop_assert_ne!(&reply["ok"]["account"], &Value::Null);
        }
        Ok(())
    });
}

#[test]
fn test_describe_status_property_a_kept_device_records_the_server_group() {
    check_forget_races(|desk, race| {
        let status = stall_one_command(desk, race, &status_command());

        prop_assert!(is_success(&status), "{:?}", status);
        let group = read_saved_server_group(&desk.device).map_err(fail)?;
        prop_assert!(group.is_some());
        Ok(())
    });
}

#[test]
fn test_describe_status_property_a_status_after_the_race_reaches_no_server() {
    check_forget_races(|desk, race| {
        race_one_command(desk, race, &status_command());

        let status = desk.device.run(&status_command()).map_err(fail)?;

        prop_assert_eq!(&status["server_address"], &Value::Null);
        prop_assert_eq!(&status["server_reachable"], &Value::Bool(false));
        Ok(())
    });
}

#[test]
fn test_create_workspace_property_a_forgotten_device_lists_no_workspace() {
    check_forget_races(|desk, race| {
        let command = create_workspace_command(&race.workspace_name);
        race_one_command(desk, race, &command);

        let listed = desk
            .device
            .send(&serde_json::json!({ "command": "list_workspaces" }));

        prop_assert!(is_no_account_refusal(&listed), "{:?}", listed);
        Ok(())
    });
}

#[test]
fn test_create_workspace_property_a_success_names_the_new_workspace() {
    check_forget_races(|desk, race| {
        let command = create_workspace_command(&race.workspace_name);

        let outcome = race_one_command(desk, race, &command);

        let reply = &outcome.racing_reply;
        if is_success(reply) {
            prop_assert_eq!(
                reply["ok"]["name"].as_str(),
                Some(race.workspace_name.as_str())
            );
        }
        Ok(())
    });
}

#[test]
fn test_create_workspace_property_a_kept_device_lists_the_new_workspace() {
    check_forget_races(|desk, race| {
        let command = create_workspace_command(&race.workspace_name);

        let created = stall_one_command(desk, race, &command);

        prop_assert!(is_success(&created), "{:?}", created);
        let listed = desk
            .device
            .run(&serde_json::json!({ "command": "list_workspaces" }))
            .map_err(fail)?;
        let views = listed.as_array().cloned().unwrap_or_default();
        let created_id = &created["ok"]["id"];
        let is_listed = views
            .iter()
            .any(|view| &view["workspace"]["id"] == created_id);
        prop_assert!(is_listed, "{:?}", listed);
        Ok(())
    });
}
