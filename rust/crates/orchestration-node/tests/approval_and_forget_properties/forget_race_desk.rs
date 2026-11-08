use std::ops::Range;
use std::thread;
use std::time::{Duration, Instant};

use orchestration_api::accounts::AccountView;
use orchestration_core::server_group::ServerGroup;
use orchestration_node::device_files::DeviceFiles;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::stalling_account_server::StallingAccountServer;
use crate::support::test_device::{TestDevice, describe, fail};

pub const NO_ACCOUNT_KIND: &str = "no_account";
pub const NO_ACCOUNT_PROBLEM: &str = "this device has no account yet";
const RACE_CASES: u32 = 3;
const STALL_MILLISECONDS: Range<u64> = 500..700;
const FORGET_DELAY_MILLISECONDS: Range<u64> = 100..250;
const WORKSPACE_NAME_PATTERN: &str = "[a-z]{3,10}";

#[derive(Clone, Debug)]
pub struct ForgetRace {
    pub stall: Duration,
    pub forget_delay: Duration,
    pub workspace_name: String,
}

#[derive(Debug)]
pub struct RaceDesk {
    pub server: StallingAccountServer,
    pub device: TestDevice,
}

#[derive(Debug)]
pub struct RaceOutcome {
    pub racing_reply: Value,
    pub forget_reply: Value,
    pub forget_finished_after: Duration,
}

pub type RaceCheck = Result<(), TestCaseError>;

fn forget_races() -> impl Strategy<Value = ForgetRace> {
    (
        STALL_MILLISECONDS,
        FORGET_DELAY_MILLISECONDS,
        WORKSPACE_NAME_PATTERN,
    )
        .prop_map(|(stall, forget_delay, workspace_name)| ForgetRace {
            stall: Duration::from_millis(stall),
            forget_delay: Duration::from_millis(forget_delay),
            workspace_name,
        })
}

pub fn status_command() -> Value {
    json!({ "command": "status" })
}

pub fn create_workspace_command(name: &str) -> Value {
    json!({ "command": "create_workspace", "name": name })
}

pub fn forget_command() -> Value {
    json!({ "command": "forget_this_device" })
}

fn open_race_desk() -> Result<RaceDesk, String> {
    let server = StallingAccountServer::start()?;
    let device = TestDevice::start()?;
    server.create_account(&device)?;
    Ok(RaceDesk { server, device })
}

pub fn check_forget_races(
    check: impl Fn(&RaceDesk, &ForgetRace) -> RaceCheck,
) {
    let mut runner = TestRunner::new(Config::with_cases(RACE_CASES));
    let outcome = runner.run(&forget_races(), |race| {
        let desk = open_race_desk().map_err(fail)?;
        check(&desk, &race)
    });
    assert!(outcome.is_ok(), "{outcome:?}");
}

pub fn stall_one_command(
    desk: &RaceDesk,
    race: &ForgetRace,
    command: &Value,
) -> Value {
    desk.server.stall_next_account_read(race.stall);
    desk.device.send(command)
}

pub fn race_forgetting(
    desk: &RaceDesk,
    race: &ForgetRace,
    racing_commands: &[Value],
) -> (Vec<Value>, RaceOutcome) {
    for _ in racing_commands {
        desk.server.stall_next_account_read(race.stall);
    }
    let device = &desk.device;
    let started = Instant::now();
    thread::scope(|scope| {
        let mut racing = Vec::new();
        for command in racing_commands {
            racing.push(scope.spawn(move || device.send(command)));
        }
        thread::sleep(race.forget_delay);
        let forgetting = scope.spawn(move || {
            let forget_reply = device.send(&forget_command());
            (forget_reply, started.elapsed())
        });
        let mut racing_replies = Vec::new();
        for racing_command in racing {
            racing_replies.push(racing_command.join().unwrap_or(Value::Null));
        }
        let (forget_reply, forget_finished_after) =
            forgetting.join().unwrap_or((Value::Null, Duration::ZERO));
        let first_reply = racing_replies.first().cloned();
        let outcome = RaceOutcome {
            racing_reply: first_reply.unwrap_or(Value::Null),
            forget_reply,
            forget_finished_after,
        };
        (racing_replies, outcome)
    })
}

pub fn race_one_command(
    desk: &RaceDesk,
    race: &ForgetRace,
    racing_command: &Value,
) -> RaceOutcome {
    let racing_commands = [racing_command.clone()];
    let (_replies, outcome) = race_forgetting(desk, race, &racing_commands);
    outcome
}

fn open_device_files(device: &TestDevice) -> Result<DeviceFiles, String> {
    DeviceFiles::open(device.data_directory.path()).map_err(describe)
}

pub fn read_saved_account(
    device: &TestDevice,
) -> Result<Option<AccountView>, String> {
    open_device_files(device)?.load_account().map_err(describe)
}

pub fn read_saved_server_group(
    device: &TestDevice,
) -> Result<Option<ServerGroup>, String> {
    open_device_files(device)?
        .load_server_group()
        .map_err(describe)
}

pub fn is_success(reply: &Value) -> bool {
    reply.get("ok").is_some()
}

pub fn is_no_account_refusal(reply: &Value) -> bool {
    reply["error"] == json!(NO_ACCOUNT_PROBLEM)
        && reply["error_kind"] == json!(NO_ACCOUNT_KIND)
}

pub fn saved_workspace_ids(account: &AccountView) -> Vec<String> {
    let mut workspace_ids = Vec::new();
    for sealed_key in &account.sealed_workspace_keys {
        workspace_ids.push(sealed_key.workspace_id.0.to_string());
    }
    workspace_ids
}
