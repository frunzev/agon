use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::folder_checks::prepared_or_panic;
use crate::support::runner_access::started_task_command;
use crate::support::test_device::{fail, read_text};

const LIVE_CASES: u32 = 3;
const MOST_COMMANDS: usize = 3;
const UNREACHABLE_LINK: &str = "unreachable";

fn run_id_strategy() -> impl Strategy<Value = String> {
    "[0-9a-f]{8}"
        .prop_map(|tail| format!("00000000-0000-4000-8000-0000{tail}"))
}

fn live_command(name: &str, run_id: &str) -> Value {
    json!({ "command": name, "run_id": run_id })
}

#[test]
fn test_handle_live_command_property_stopping_a_watch_is_always_quiet() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIVE_CASES));
    let drawn = (run_id_strategy(), 1..=MOST_COMMANDS);

    let outcome = runner.run(&drawn, |(run_id, stop_count)| {
        for _ in 0..stop_count {
            let stopped = prepared
                .device
                .run(&live_command("stop_watching_run", &run_id));
            prop_assert_eq!(stopped, Ok(Value::Null));
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_handle_live_command_property_an_unknown_run_starts_no_watch() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIVE_CASES));
    let drawn = (run_id_strategy(), 1..=MOST_COMMANDS);

    let outcome = runner.run(&drawn, |(run_id, watch_count)| {
        let mut refusals = Vec::new();
        for _ in 0..watch_count {
            let watched =
                prepared.device.run(&live_command("watch_run", &run_id));
            refusals.push(watched);
        }

        for refusal in &refusals {
            prop_assert!(refusal.is_err(), "{:?}", refusal);
            prop_assert_eq!(refusal, &refusals[0]);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_handle_live_command_property_a_run_without_a_runner_is_unreachable() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIVE_CASES));

    let outcome = runner.run(&(1..=MOST_COMMANDS), |watch_count| {
        let started = prepared
            .device
            .run(&started_task_command(&prepared, "Watch me"))
            .map_err(fail)?;
        let task_id = read_text(&started, "/id").map_err(fail)?;
        let runs = prepared
            .device
            .run(&json!({ "command": "list_runs", "task_id": task_id }))
            .map_err(fail)?;
        let run_id = runs[0]["id"].as_str().unwrap_or_default().to_owned();
        for _ in 0..watch_count {
            let view = prepared
                .device
                .run(&live_command("watch_run", &run_id))
                .map_err(fail)?;
            prop_assert_eq!(&view["link"], &json!(UNREACHABLE_LINK));
            prop_assert_eq!(&view["link_lost_at"], &Value::Null);
            prop_assert!(view["problem"].is_string(), "{}", view);
            prop_assert_eq!(&view["events"], &json!([]));
        }
        let stopped = prepared
            .device
            .run(&live_command("stop_watching_run", &run_id));
        prop_assert_eq!(stopped, Ok(Value::Null));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
