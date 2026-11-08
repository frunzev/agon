use std::thread;
use std::time::Duration;

use proptest::prelude::*;

use crate::backup_group::TAKEOVER_LIMIT;
use crate::hosting_desk::{heavy_cases, read_loopback_health};
use crate::logged_host::count_lines_starting;
use crate::process_group::{ProcessBackup, wait_for_logged_line};
use crate::refusal_steps::{
    KeptBackup, MISDIRECTED_ANSWER_START, REMOVAL_LINE, read_state_in,
    refuse_a_process_backup, restart_logged_host,
};
use crate::support::server_backups::{create_project, read_hosted_state};
use crate::support::test_device::fail;

const QUIET_PERIOD: Duration = Duration::from_secs(8);
const LATE_PROJECT_PATTERN: &str = "late-[a-z]{6}";

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_follow_leader_property_a_refusal_ends_keeping_once(
        _round in 0_u8..1,
    ) {
        let refused = refuse_a_process_backup().map_err(fail)?;

        thread::sleep(QUIET_PERIOD);
        let lines = refused.backup.host.stop().map_err(fail)?;

        prop_assert_eq!(count_lines_starting(&lines, REMOVAL_LINE), 1);
    }

    #[test]
    fn test_follow_leader_property_a_restarted_refused_backup_copies_nothing(
        late_project in LATE_PROJECT_PATTERN,
    ) {
        let KeptBackup { backup, port } =
            refuse_a_process_backup().map_err(fail)?;
        let ProcessBackup {
            hosting,
            host,
            data_directory,
            workspace_id,
            ..
        } = backup;

        let restarted = restart_logged_host(host, data_directory.path(), port)
            .map_err(fail)?;
        let ended = wait_for_logged_line(&restarted, REMOVAL_LINE);
        create_project(&hosting.device, &workspace_id, &late_project)
            .map_err(fail)?;
        thread::sleep(QUIET_PERIOD);
        let copied = read_state_in(data_directory.path()).map_err(fail)?;
        let source = read_hosted_state(&hosting.device).map_err(fail)?;
        drop(restarted);

        prop_assert!(ended.is_ok(), "{ended:?}");
        let source_projects = source["projects"].to_string();
        let copied_projects = copied["projects"].to_string();
        prop_assert!(source_projects.contains(&late_project));
        prop_assert!(!copied_projects.contains(&late_project));
    }

    #[test]
    fn test_follow_leader_property_a_refused_backup_never_takes_over_later(
        _round in 0_u8..1,
    ) {
        let KeptBackup { backup, port } =
            refuse_a_process_backup().map_err(fail)?;
        let ProcessBackup {
            hosting,
            host,
            data_directory,
            ..
        } = backup;

        drop(hosting);
        let restarted = restart_logged_host(host, data_directory.path(), port)
            .map_err(fail)?;
        thread::sleep(TAKEOVER_LIMIT);
        let health = read_loopback_health(port).map_err(fail)?;
        let lines = restarted.stop().map_err(fail)?;

        prop_assert!(health.starts_with(MISDIRECTED_ANSWER_START), "{health}");
        prop_assert_eq!(count_lines_starting(&lines, REMOVAL_LINE), 1);
    }
}
