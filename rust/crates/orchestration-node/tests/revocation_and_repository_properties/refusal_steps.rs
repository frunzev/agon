use std::fs;
use std::path::Path;

use serde_json::Value;

use crate::backup_group::{READY_TAKEOVER_SECONDS, start_backup_group};
use crate::hosting_desk::keeping_configuration;
use crate::logged_host::LoggedHost;
use crate::process_group::{
    ProcessBackup, move_backup_into_a_process, revoke_the_backup,
    wait_for_logged_line,
};
use crate::support::test_device::describe;

pub const REMOVAL_LINE: &str = "the app server group keeper hit a problem: \
                                this device no longer keeps the app server";
pub const MISDIRECTED_ANSWER_START: &str = "HTTP/1.1 421";
const STATE_FILE_PATH: &str = "hosted-app-server/state.json";

#[derive(Debug)]
pub struct KeptBackup {
    pub backup: ProcessBackup,
    pub port: u16,
}

pub fn keep_a_process_backup() -> Result<KeptBackup, String> {
    let group = start_backup_group(READY_TAKEOVER_SECONDS)?;
    let port = group.backup_port;
    let backup = move_backup_into_a_process(group, READY_TAKEOVER_SECONDS)?;
    Ok(KeptBackup { backup, port })
}

pub fn refuse_a_process_backup() -> Result<KeptBackup, String> {
    let kept = keep_a_process_backup()?;
    revoke_the_backup(&kept.backup)?;
    wait_for_logged_line(&kept.backup.host, REMOVAL_LINE)?;
    Ok(kept)
}

pub fn restart_logged_host(
    host: LoggedHost,
    data_directory: &Path,
    port: u16,
) -> Result<LoggedHost, String> {
    host.stop()?;
    let configuration =
        keeping_configuration(data_directory, port, READY_TAKEOVER_SECONDS);
    LoggedHost::start(&configuration)
}

pub fn read_state_in(data_directory: &Path) -> Result<Value, String> {
    let state_path = data_directory.join(STATE_FILE_PATH);
    let state_text = fs::read_to_string(state_path).map_err(describe)?;
    serde_json::from_str(&state_text).map_err(describe)
}
