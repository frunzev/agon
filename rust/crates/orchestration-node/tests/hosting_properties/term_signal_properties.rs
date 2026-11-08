use std::thread;
use std::time::Duration;

use orchestration_core::server_group::{ServerStanding, ServerTerm};
use orchestration_security::server_group::verify_server_term;
use proptest::prelude::*;

use crate::backup_group::{
    READY_TAKEOVER_SECONDS, RETURN_LIMIT, STEADY_TAKEOVER_SECONDS,
    TAKEOVER_LIMIT, start_and_take_over, start_backup_group,
};
use crate::hosting_desk::{
    heavy_cases, loopback_address, read_group_with, read_loopback_health,
    read_own_group,
};
use crate::logged_host::count_lines_starting;
use crate::process_group::{
    move_backup_into_a_process, revoke_the_backup, wait_for_logged_line,
};
use crate::refusal_steps::{
    KeptBackup, MISDIRECTED_ANSWER_START, REMOVAL_LINE, read_state_in,
    refuse_a_process_backup, restart_logged_host,
};
use crate::support::server_backups::{
    create_project, read_hosted_state, wait_until_standing,
};
use crate::support::test_device::{TestDevice, fail};
use crate::support::waiting::wait_for;

const KEEPER_LINE_START: &str = "the app server group keeper hit a problem: ";
const QUIET_PERIOD: Duration = Duration::from_secs(8);
const LATE_PROJECT: &str = "after-the-revocation";
const LEARNED_TERM_WAIT: &str = "the returning server to learn the term";

fn read_term(
    device: &TestDevice,
    port: u16,
) -> Result<ServerTerm, TestCaseError> {
    let view = read_own_group(device, port).map_err(fail)?;
    view.group.term.ok_or_else(|| fail("the group has no term"))
}

fn wait_until_term_learned(
    device: &TestDevice,
    port: u16,
    term: &ServerTerm,
) -> Result<(), String> {
    wait_for(RETURN_LIMIT, LEARNED_TERM_WAIT, || {
        let Ok(own_view) = read_own_group(device, port) else {
            return Ok(None);
        };
        let has_learned = own_view.group.term.as_ref() == Some(term);
        Ok(has_learned.then_some(()))
    })
}

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_remember_term_property_a_takeover_claims_the_next_term(
        _round in 0_u8..1,
    ) {
        let taken = start_and_take_over().map_err(fail)?;
        let identity = taken.backup.load_identity().map_err(fail)?;

        let term = read_term(&taken.backup, taken.backup_port)?;
        let view = read_own_group(&taken.backup, taken.backup_port)
            .map_err(fail)?;
        let device_id = identity.device_id();
        let own_member = view.group.find_member_of_device(&device_id);

        prop_assert_eq!(term.number, 2);
        prop_assert_eq!(&term.claimed_by, &identity.device_id());
        prop_assert_eq!(
            Some(&term.server_id),
            own_member.map(|member| &member.membership.server_id)
        );
        let device_key = identity.public_identity().signing_public_key;
        prop_assert!(verify_server_term(&term, &device_key).is_ok());
    }

    #[test]
    fn test_remember_term_property_the_returning_server_never_claims_again(
        _round in 0_u8..1,
    ) {
        let taken = start_and_take_over().map_err(fail)?;
        let term_before = read_term(&taken.backup, taken.backup_port)?;

        let returned = taken.stopped.start_again().map_err(fail)?;
        let rejoined = wait_until_standing(&returned, "backup", RETURN_LIMIT);
        thread::sleep(QUIET_PERIOD);
        let term_after = read_term(&taken.backup, taken.backup_port)?;
        let returned_term = read_term(&returned, taken.active_port)?;

        prop_assert!(rejoined.is_ok(), "{rejoined:?}");
        prop_assert_eq!(&term_after, &term_before);
        prop_assert_eq!(&returned_term, &term_before);
    }

    #[test]
    fn test_remember_term_property_terms_grow_with_every_takeover(
        _round in 0_u8..1,
    ) {
        let taken = start_and_take_over().map_err(fail)?;
        let second = read_term(&taken.backup, taken.backup_port)?;
        let returned = taken.stopped.start_again().map_err(fail)?;
        wait_until_standing(&returned, "backup", RETURN_LIMIT).map_err(fail)?;
        wait_until_term_learned(&returned, taken.active_port, &second)
            .map_err(fail)?;

        let stopped_second = taken.backup.stop();
        let again = wait_until_standing(&returned, "active", RETURN_LIMIT);
        let third = read_term(&returned, taken.active_port)?;
        drop(stopped_second);

        prop_assert!(again.is_ok(), "{again:?}");
        prop_assert_eq!(second.number, 2);
        prop_assert_eq!(third.number, 3);
        prop_assert!(third.outranks(&second));
        prop_assert_ne!(&third.server_id, &second.server_id);
    }

    #[test]
    fn test_is_refusal_property_a_revoked_backup_never_takes_over(
        _round in 0_u8..1,
    ) {
        let KeptBackup { backup, port } =
            refuse_a_process_backup().map_err(fail)?;
        let hosting_identity =
            backup.hosting.device.load_identity().map_err(fail)?;

        drop(backup.hosting);
        thread::sleep(TAKEOVER_LIMIT);
        let health = read_loopback_health(port).map_err(fail)?;
        let backup_route = loopback_address(port);
        let view =
            read_group_with(&hosting_identity, &backup_route).map_err(fail)?;
        drop(backup.host);

        prop_assert!(health.starts_with(MISDIRECTED_ANSWER_START), "{health}");
        prop_assert_eq!(view.standing, ServerStanding::Backup);
    }

    #[test]
    fn test_is_refusal_property_a_revoked_backup_stops_copying(
        _round in 0_u8..1,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let backup = move_backup_into_a_process(group, STEADY_TAKEOVER_SECONDS)
            .map_err(fail)?;

        revoke_the_backup(&backup).map_err(fail)?;
        wait_for_logged_line(&backup.host, REMOVAL_LINE).map_err(fail)?;
        let hosting_device = &backup.hosting.device;
        create_project(hosting_device, &backup.workspace_id, LATE_PROJECT)
            .map_err(fail)?;
        thread::sleep(QUIET_PERIOD);
        let copied =
            read_state_in(backup.data_directory.path()).map_err(fail)?;
        let source = read_hosted_state(hosting_device).map_err(fail)?;

        prop_assert!(source["projects"].to_string().contains(LATE_PROJECT));
        prop_assert!(!copied["projects"].to_string().contains(LATE_PROJECT));
    }

    #[test]
    fn test_is_refusal_property_a_restarted_revoked_backup_stays_a_backup(
        _round in 0_u8..1,
    ) {
        let group = start_backup_group(READY_TAKEOVER_SECONDS).map_err(fail)?;
        let backup_port = group.backup_port;
        let backup = move_backup_into_a_process(group, READY_TAKEOVER_SECONDS)
            .map_err(fail)?;

        revoke_the_backup(&backup).map_err(fail)?;
        wait_for_logged_line(&backup.host, REMOVAL_LINE).map_err(fail)?;
        let data_directory = backup.data_directory.path();
        let restarted =
            restart_logged_host(backup.host, data_directory, backup_port)
                .map_err(fail)?;
        wait_for_logged_line(&restarted, REMOVAL_LINE).map_err(fail)?;
        drop(backup.hosting);
        thread::sleep(TAKEOVER_LIMIT);
        let health = read_loopback_health(backup_port).map_err(fail)?;
        drop(restarted);

        prop_assert!(health.starts_with(MISDIRECTED_ANSWER_START), "{health}");
    }

    #[test]
    fn test_is_silence_property_a_silent_active_is_taken_over(
        _round in 0_u8..1,
    ) {
        let taken = start_and_take_over().map_err(fail)?;

        let view = read_own_group(&taken.backup, taken.backup_port)
            .map_err(fail)?;
        let health = read_loopback_health(taken.backup_port).map_err(fail)?;

        prop_assert_eq!(&taken.took_over["this_device"], "active");
        prop_assert_eq!(view.standing, ServerStanding::Active);
        let is_misdirected = health.starts_with(MISDIRECTED_ANSWER_START);
        prop_assert!(!is_misdirected, "{health}");
    }

    #[test]
    fn test_is_silence_property_a_steady_backup_outwaits_the_silence(
        _round in 0_u8..1,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;

        let backup_port = group.backup_port;
        let backup = group.backup;
        drop(group.hosting);
        thread::sleep(QUIET_PERIOD);
        let health = read_loopback_health(backup_port).map_err(fail)?;
        let view = read_own_group(&backup, backup_port).map_err(fail)?;

        prop_assert!(health.starts_with(MISDIRECTED_ANSWER_START), "{health}");
        prop_assert_eq!(view.standing, ServerStanding::Backup);
    }

    #[test]
    fn test_is_silence_property_silence_is_never_logged(
        _round in 0_u8..1,
    ) {
        let group =
            start_backup_group(STEADY_TAKEOVER_SECONDS).map_err(fail)?;
        let backup = move_backup_into_a_process(group, STEADY_TAKEOVER_SECONDS)
            .map_err(fail)?;

        drop(backup.hosting);
        thread::sleep(QUIET_PERIOD);
        let lines = backup.host.stop().map_err(fail)?;

        prop_assert_eq!(count_lines_starting(&lines, KEEPER_LINE_START), 0);
    }
}
