use proptest::prelude::*;
use serde_json::Value;

use crate::forget_race_desk::{
    check_forget_races, create_workspace_command, is_success, race_forgetting,
    race_one_command, read_saved_account, read_saved_server_group,
    saved_workspace_ids, stall_one_command, status_command,
};
use crate::support::test_device::fail;

#[test]
fn test_refresh_saved_account_property_a_stalled_status_revives_nothing() {
    check_forget_races(|desk, race| {
        let outcome = race_one_command(desk, race, &status_command());

        prop_assert!(is_success(&outcome.forget_reply), "{:?}", outcome);
        let saved = read_saved_account(&desk.device).map_err(fail)?;
        prop_assert!(saved.is_none(), "{:?} {:?}", saved, outcome);
        Ok(())
    });
}

#[test]
fn test_refresh_saved_account_property_a_stalled_creation_revives_nothing() {
    check_forget_races(|desk, race| {
        let command = create_workspace_command(&race.workspace_name);

        let outcome = race_one_command(desk, race, &command);

        prop_assert!(is_success(&outcome.forget_reply), "{:?}", outcome);
        let saved = read_saved_account(&desk.device).map_err(fail)?;
        prop_assert!(saved.is_none(), "{:?} {:?}", saved, outcome);
        Ok(())
    });
}

#[test]
fn test_refresh_saved_account_property_a_kept_device_saves_the_new_key() {
    check_forget_races(|desk, race| {
        let command = create_workspace_command(&race.workspace_name);

        let created = stall_one_command(desk, race, &command);

        prop_assert!(is_success(&created), "{:?}", created);
        let created_id = created["ok"]["id"].as_str().unwrap_or_default();
        let saved = read_saved_account(&desk.device).map_err(fail)?;
        let Some(saved) = saved else {
            return Err(TestCaseError::fail("the account stays saved"));
        };
        prop_assert!(
            saved_workspace_ids(&saved).contains(&created_id.to_owned())
        );
        Ok(())
    });
}

#[test]
fn test_forget_this_device_property_every_race_ends_forgotten() {
    check_forget_races(|desk, race| {
        let commands = [
            status_command(),
            create_workspace_command(&race.workspace_name),
        ];

        let (_replies, outcome) = race_forgetting(desk, race, &commands);

        prop_assert!(is_success(&outcome.forget_reply), "{:?}", outcome);
        let saved = read_saved_account(&desk.device).map_err(fail)?;
        prop_assert!(saved.is_none(), "{:?}", saved);
        let group = read_saved_server_group(&desk.device).map_err(fail)?;
        prop_assert!(group.is_none(), "{:?}", group);
        prop_assert!(desk.device.load_identity().is_err());
        Ok(())
    });
}

#[test]
fn test_forget_this_device_property_waits_for_a_successful_status() {
    check_forget_races(|desk, race| {
        let outcome = race_one_command(desk, race, &status_command());

        if is_success(&outcome.racing_reply) {
            prop_assert!(
                outcome.forget_finished_after >= race.stall,
                "{:?}",
                outcome
            );
        }
        Ok(())
    });
}

#[test]
fn test_forget_this_device_property_a_later_status_knows_no_device() {
    check_forget_races(|desk, race| {
        race_one_command(desk, race, &status_command());

        let status = desk.device.run(&status_command()).map_err(fail)?;

        prop_assert_eq!(&status["device_id"], &Value::Null);
        prop_assert_eq!(&status["account"], &Value::Null);
        Ok(())
    });
}

#[test]
fn test_lock_account_updates_property_a_finished_creation_precedes_forgetting()
{
    check_forget_races(|desk, race| {
        let command = create_workspace_command(&race.workspace_name);

        let outcome = race_one_command(desk, race, &command);

        if is_success(&outcome.racing_reply) {
            prop_assert!(
                outcome.forget_finished_after >= race.stall,
                "{:?}",
                outcome
            );
        }
        Ok(())
    });
}

#[test]
fn test_lock_account_updates_property_two_stalled_refreshes_end_forgotten() {
    check_forget_races(|desk, race| {
        let commands = [
            create_workspace_command(&race.workspace_name),
            create_workspace_command(&format!("{}-two", race.workspace_name)),
        ];

        let (replies, outcome) = race_forgetting(desk, race, &commands);

        prop_assert!(is_success(&outcome.forget_reply), "{:?}", outcome);
        let saved = read_saved_account(&desk.device).map_err(fail)?;
        prop_assert!(saved.is_none(), "{:?} {:?}", saved, replies);
        Ok(())
    });
}

#[test]
fn test_lock_account_updates_property_a_kept_device_keeps_concurrent_keys() {
    check_forget_races(|desk, race| {
        let first = create_workspace_command(&race.workspace_name);
        let second =
            create_workspace_command(&format!("{}-two", race.workspace_name));
        desk.server.stall_next_account_read(race.stall);

        let (first_reply, second_reply) = std::thread::scope(|scope| {
            let first_thread = scope.spawn(|| desk.device.send(&first));
            std::thread::sleep(race.forget_delay);
            let second_reply = desk.device.send(&second);
            (first_thread.join().unwrap_or(Value::Null), second_reply)
        });

        let saved = read_saved_account(&desk.device).map_err(fail)?;
        let Some(saved) = saved else {
            return Err(TestCaseError::fail("the account stays saved"));
        };
        let saved_ids = saved_workspace_ids(&saved);
        for reply in [&first_reply, &second_reply] {
            prop_assert!(is_success(reply), "{:?}", reply);
            let created_id = reply["ok"]["id"].as_str().unwrap_or_default();
            prop_assert!(saved_ids.contains(&created_id.to_owned()));
        }
        Ok(())
    });
}
