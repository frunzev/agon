use proptest::prelude::*;
use serde_json::json;

use crate::forget_race_desk::{
    check_forget_races, is_success, race_one_command, read_saved_account,
    read_saved_server_group, status_command,
};
use crate::support::test_device::fail;

#[test]
fn test_refresh_server_group_property_a_racing_status_leaves_no_group_file() {
    check_forget_races(|desk, race| {
        let outcome = race_one_command(desk, race, &status_command());

        prop_assert!(is_success(&outcome.forget_reply), "{:?}", outcome);
        let group = read_saved_server_group(&desk.device).map_err(fail)?;
        prop_assert!(group.is_none(), "{:?} {:?}", group, outcome);
        Ok(())
    });
}

#[test]
fn test_refresh_server_group_property_the_group_never_outlives_the_account() {
    check_forget_races(|desk, race| {
        race_one_command(desk, race, &status_command());

        let group = read_saved_server_group(&desk.device).map_err(fail)?;
        let account = read_saved_account(&desk.device).map_err(fail)?;
        prop_assert!(group.is_none() || account.is_some());
        Ok(())
    });
}

#[test]
fn test_refresh_server_group_property_polling_after_forgetting_writes_nothing()
{
    check_forget_races(|desk, race| {
        race_one_command(desk, race, &status_command());

        let polled = desk
            .device
            .send(&json!({ "command": "poll_events", "after": 0 }));

        prop_assert!(!is_success(&polled), "{:?}", polled);
        let group = read_saved_server_group(&desk.device).map_err(fail)?;
        prop_assert!(group.is_none());
        Ok(())
    });
}
