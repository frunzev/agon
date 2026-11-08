use std::collections::BTreeSet;
use std::thread;
use std::time::Duration;

use orchestration_node::device_files::DeviceFiles;
use proptest::collection::btree_set;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::stalling_account_server::StallingAccountServer;
use crate::support::test_device::{TestDevice, describe, fail, read_text};

const CONCURRENT_CASES: u32 = 4;
const WORKSPACE_NAME_PATTERN: &str = "[a-z]{3,10}";
const FEWEST_LATE_CREATIONS: usize = 1;
const MOST_LATE_CREATIONS: usize = 4;
const STALL_MILLISECONDS: std::ops::Range<u64> = 500..700;
const LATE_START_MILLISECONDS: std::ops::Range<u64> = 150..250;

type CommandOutcome = Result<Value, String>;

#[derive(Clone, Debug)]
struct StalledRace {
    late_names: Vec<String>,
    stall: Duration,
    late_start: Duration,
}

struct RaceDesk {
    server: StallingAccountServer,
    device: TestDevice,
}

fn stalled_races() -> impl Strategy<Value = StalledRace> {
    let names = btree_set(
        WORKSPACE_NAME_PATTERN,
        FEWEST_LATE_CREATIONS..=MOST_LATE_CREATIONS,
    );
    (names, STALL_MILLISECONDS, LATE_START_MILLISECONDS).prop_map(
        |(names, stall, late_start)| StalledRace {
            late_names: names.into_iter().collect(),
            stall: Duration::from_millis(stall),
            late_start: Duration::from_millis(late_start),
        },
    )
}

fn create_workspace_command(name: &str) -> Value {
    json!({ "command": "create_workspace", "name": name })
}

fn open_race_desk() -> Result<RaceDesk, String> {
    let server = StallingAccountServer::start()?;
    let device = TestDevice::start()?;
    server.create_account(&device)?;
    Ok(RaceDesk { server, device })
}

fn run_stalled_race(
    desk: &RaceDesk,
    race: &StalledRace,
    first_command: &Value,
) -> (CommandOutcome, Vec<CommandOutcome>) {
    desk.server.stall_next_account_read(race.stall);
    let device = &desk.device;
    thread::scope(|scope| {
        let first = scope.spawn(move || device.run(first_command));
        thread::sleep(race.late_start);
        let mut late_creations = Vec::new();
        for name in &race.late_names {
            let command = create_workspace_command(name);
            late_creations.push(scope.spawn(move || device.run(&command)));
        }
        let mut late_outcomes = Vec::new();
        for late_creation in late_creations {
            late_outcomes.push(join_outcome(late_creation.join()));
        }
        (join_outcome(first.join()), late_outcomes)
    })
}

fn join_outcome<Panic>(
    joined: Result<CommandOutcome, Panic>,
) -> CommandOutcome {
    joined.unwrap_or_else(|_| Err("the command thread panicked".into()))
}

fn read_created_ids(
    outcomes: &[CommandOutcome],
) -> Result<BTreeSet<String>, String> {
    let mut created_ids = BTreeSet::new();
    for outcome in outcomes {
        let created = outcome.as_ref().map_err(Clone::clone)?;
        created_ids.insert(read_text(created, "/id")?);
    }
    Ok(created_ids)
}

fn read_saved_key_ids(
    device: &TestDevice,
) -> Result<BTreeSet<String>, String> {
    let files =
        DeviceFiles::open(device.data_directory.path()).map_err(describe)?;
    let account = files.load_account().map_err(describe)?;
    let account = account.ok_or("the device saved no account")?;
    let mut key_ids = BTreeSet::new();
    for sealed_key in account.sealed_workspace_keys {
        key_ids.insert(sealed_key.workspace_id.0.to_string());
    }
    Ok(key_ids)
}

fn read_listed_ids(device: &TestDevice) -> Result<BTreeSet<String>, String> {
    let listed = device.run(&json!({ "command": "list_workspaces" }))?;
    let views = listed.as_array().cloned().unwrap_or_default();
    let mut listed_ids = BTreeSet::new();
    for view in &views {
        listed_ids.insert(read_text(view, "/workspace/id")?);
    }
    Ok(listed_ids)
}

fn check_races(
    check: impl Fn(&RaceDesk, &StalledRace) -> Result<(), TestCaseError>,
) {
    let mut runner = TestRunner::new(Config::with_cases(CONCURRENT_CASES));
    let outcome = runner.run(&stalled_races(), |race| {
        let desk = open_race_desk().map_err(fail)?;
        check(&desk, &race)
    });
    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_refresh_saved_account_property_concurrent_creations_keep_every_key() {
    check_races(|desk, race| {
        let first_command = create_workspace_command("first");

        let (first, late) = run_stalled_race(desk, race, &first_command);

        let mut outcomes = late;
        outcomes.push(first);
        let created_ids = read_created_ids(&outcomes).map_err(fail)?;
        let saved_key_ids = read_saved_key_ids(&desk.device).map_err(fail)?;
        let lost: Vec<&String> =
            created_ids.difference(&saved_key_ids).collect();
        prop_assert!(lost.is_empty(), "lost keys {:?}", lost);
        Ok(())
    });
}

#[test]
fn test_refresh_saved_account_property_a_stalled_status_keeps_new_keys() {
    check_races(|desk, race| {
        let status_command = json!({ "command": "status" });

        let (status, late) = run_stalled_race(desk, race, &status_command);

        prop_assert!(status.is_ok(), "{:?}", status);
        let created_ids = read_created_ids(&late).map_err(fail)?;
        let saved_key_ids = read_saved_key_ids(&desk.device).map_err(fail)?;
        prop_assert!(
            created_ids.is_subset(&saved_key_ids),
            "created {:?}, saved {:?}",
            created_ids,
            saved_key_ids
        );
        Ok(())
    });
}

#[test]
fn test_refresh_saved_account_property_saved_keys_match_the_listing() {
    check_races(|desk, race| {
        let first_command = create_workspace_command("first");

        let (first, late) = run_stalled_race(desk, race, &first_command);

        prop_assert!(first.is_ok(), "{:?}", first);
        let saved_key_ids = read_saved_key_ids(&desk.device).map_err(fail)?;
        let listed_ids = read_listed_ids(&desk.device).map_err(fail)?;
        prop_assert_eq!(&saved_key_ids, &listed_ids);
        prop_assert_eq!(listed_ids.len(), late.len() + 2);
        Ok(())
    });
}
