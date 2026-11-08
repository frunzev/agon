use std::time::Duration;

use proptest::prelude::*;

use crate::backup_group::TAKEOVER_LIMIT;
use crate::hosting_desk::{heavy_cases, read_loopback_health};
use crate::logged_host::{LoggedHost, count_lines_starting};
use crate::process_group::{ProcessBackup, wait_for_logged_line};
use crate::refusal_steps::{
    KeptBackup, MISDIRECTED_ANSWER_START, REMOVAL_LINE, keep_a_process_backup,
    refuse_a_process_backup, restart_logged_host,
};
use crate::support::test_device::fail;
use crate::support::waiting::wait_for;

const MOST_RESTARTS: usize = 3;
const ACTIVE_WAIT: &str = "the restarted backup to take over";

fn wait_until_answering(port: u16, limit: Duration) -> Result<(), String> {
    wait_for(limit, ACTIVE_WAIT, || {
        let Ok(health) = read_loopback_health(port) else {
            return Ok(None);
        };
        let is_active = !health.starts_with(MISDIRECTED_ANSWER_START);
        Ok(is_active.then_some(()))
    })
}

#[derive(Debug)]
struct AloneRestart {
    host: LoggedHost,
    endings: Vec<Result<String, String>>,
}

fn restart_while_alone(
    kept: KeptBackup,
    restart_count: usize,
) -> Result<AloneRestart, String> {
    let KeptBackup { backup, port } = kept;
    let ProcessBackup {
        hosting,
        mut host,
        data_directory,
        ..
    } = backup;
    drop(hosting);
    let mut endings = Vec::new();
    for _ in 0..restart_count {
        host = restart_logged_host(host, data_directory.path(), port)?;
        endings.push(wait_for_logged_line(&host, REMOVAL_LINE));
    }
    Ok(AloneRestart { host, endings })
}

proptest! {
    #![proptest_config(heavy_cases(1))]

    #[test]
    fn test_run_round_property_a_remembered_refusal_ends_keeping_at_once(
        _round in 0_u8..1,
    ) {
        let refused = refuse_a_process_backup().map_err(fail)?;
        let port = refused.port;

        let restart = restart_while_alone(refused, 1).map_err(fail)?;
        let health = read_loopback_health(port).map_err(fail)?;
        drop(restart.host);

        for ending in &restart.endings {
            prop_assert!(ending.is_ok(), "{ending:?}");
        }
        prop_assert!(health.starts_with(MISDIRECTED_ANSWER_START), "{health}");
    }

    #[test]
    fn test_run_round_property_restarts_never_forget_the_refusal(
        restart_count in 2..=MOST_RESTARTS,
    ) {
        let refused = refuse_a_process_backup().map_err(fail)?;
        let port = refused.port;

        let restart =
            restart_while_alone(refused, restart_count).map_err(fail)?;
        let health = read_loopback_health(port).map_err(fail)?;
        let lines = restart.host.stop().map_err(fail)?;

        prop_assert_eq!(restart.endings.len(), restart_count);
        for ending in &restart.endings {
            prop_assert!(ending.is_ok(), "{ending:?}");
        }
        prop_assert!(health.starts_with(MISDIRECTED_ANSWER_START), "{health}");
        prop_assert_eq!(count_lines_starting(&lines, REMOVAL_LINE), 1);
    }

    #[test]
    fn test_run_round_property_silence_alone_leaves_keeping_on(
        _round in 0_u8..1,
    ) {
        let kept = keep_a_process_backup().map_err(fail)?;
        let KeptBackup { backup, port } = kept;
        let ProcessBackup {
            hosting,
            host,
            data_directory,
            ..
        } = backup;

        let restarted = restart_logged_host(host, data_directory.path(), port)
            .map_err(fail)?;
        drop(hosting);
        let took_over = wait_until_answering(port, TAKEOVER_LIMIT);
        let lines = restarted.stop().map_err(fail)?;

        prop_assert!(took_over.is_ok(), "{took_over:?}");
        prop_assert_eq!(count_lines_starting(&lines, REMOVAL_LINE), 0);
    }
}
