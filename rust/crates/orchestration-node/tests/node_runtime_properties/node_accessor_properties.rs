use std::time::Duration;

use orchestration_core::agent_place::AgentPlace;
use orchestration_node::commands::dispatch_command;
use orchestration_node::node::Node;
use orchestration_node::node_error::NodeError;
use orchestration_node::place_offers::normalize_offers;
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::access_node::{ACCESS_CASES, open_node};
use crate::support::fake_engine::{
    EngineAnswers, EngineRunner, local_sandbox,
};
use crate::support::runner_access::test_runtime;
use crate::support::test_device::{TestDevice, fail, read_success};
use crate::support::waiting::wait_for;

const MOST_OFFERS: usize = 5;
const MOST_CALLS: usize = 4;
const RUNTIME_CASES: u32 = 2;
const SETTINGS_LIMIT: Duration = Duration::from_secs(20);
const NO_PEER_ENDPOINT: &str = "this node has no peer endpoint";
const NO_OFFERS: &str = "a runner offers at least one place for agents to run";
const LIVE_COMMAND_NAMES: [&str; 2] = ["watch_run", "stop_watching_run"];
const READY_ENGINE: EngineAnswers = EngineAnswers {
    info_exit_code: 0,
    image_exit_code: 0,
};

fn agent_place_strategy() -> impl Strategy<Value = AgentPlace> {
    prop::sample::select(vec![AgentPlace::LocalProcess, AgentPlace::Container])
}

fn run_id_strategy() -> impl Strategy<Value = String> {
    "[0-9a-f]{8}"
        .prop_map(|tail| format!("00000000-0000-4000-8000-0000{tail}"))
}

fn run_on_bare_node(node: &Node, command: &Value) -> Result<Value, String> {
    let runtime = test_runtime()?;
    let command_text = command.to_string();
    let reply_text = runtime.block_on(dispatch_command(node, &command_text));
    let reply: Value = serde_json::from_str(&reply_text)
        .map_err(|error| error.to_string())?;
    read_success(&reply)
}

fn read_status_on_bare_node(node: &Node) -> Result<Value, TestCaseError> {
    run_on_bare_node(node, &json!({ "command": "status" })).map_err(fail)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ACCESS_CASES))]

    #[test]
    fn test_runner_state_property_a_fresh_node_has_no_runner(
        read_count in 1..MOST_CALLS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        for _ in 0..read_count {
            let runner_state = node.runner_state();
            prop_assert_eq!(runner_state.settings_in_effect(), None);
            prop_assert_eq!(runner_state.problem(), None);
            prop_assert!(runner_state.checked_offers().is_empty());
            prop_assert_eq!(runner_state.chosen_offers(), None);
        }
    }

    #[test]
    fn test_runner_state_property_saved_offers_are_chosen_on_open(
        offers in vec(agent_place_strategy(), 1..MOST_OFFERS),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let first = open_node(&data_directory).map_err(fail)?;
        let normalized = normalize_offers(&offers);
        first.device_files().save_agent_offers(&normalized).map_err(fail)?;
        drop(first);

        let reopened = open_node(&data_directory).map_err(fail)?;

        let chosen = reopened.runner_state().chosen_offers();
        prop_assert_eq!(chosen, Some(normalized));
    }

    #[test]
    fn test_runner_state_property_a_refused_choice_changes_nothing(
        saved in vec(agent_place_strategy(), 1..MOST_OFFERS),
        offered in vec(agent_place_strategy(), 0..MOST_OFFERS),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let first = open_node(&data_directory).map_err(fail)?;
        let normalized = normalize_offers(&saved);
        first.device_files().save_agent_offers(&normalized).map_err(fail)?;
        drop(first);
        let node = open_node(&data_directory).map_err(fail)?;

        let refused = node.choose_agent_offers(&offered);

        prop_assert!(refused.is_err());
        let chosen = node.runner_state().chosen_offers();
        prop_assert_eq!(chosen, Some(normalized.clone()));
        let stored = node.device_files().load_agent_offers().map_err(fail)?;
        prop_assert_eq!(stored, Some(normalized));
    }

    #[test]
    fn test_choose_agent_offers_property_without_settings_is_refused(
        offers in vec(agent_place_strategy(), 0..MOST_OFFERS),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        let refused = node.choose_agent_offers(&offers);

        prop_assert!(matches!(refused, Err(NodeError::RunnerUnavailable)));
        let stored = node.device_files().load_agent_offers().map_err(fail)?;
        prop_assert_eq!(stored, None);
        prop_assert_eq!(node.runner_state().chosen_offers(), None);
    }

    #[test]
    fn test_peer_side_property_a_bare_node_refuses_live_commands(
        command_name in prop::sample::select(LIVE_COMMAND_NAMES.to_vec()),
        run_id in run_id_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        let refused = run_on_bare_node(
            &node,
            &json!({ "command": command_name, "run_id": run_id }),
        );

        prop_assert_eq!(refused, Err(NO_PEER_ENDPOINT.to_owned()));
    }

    #[test]
    fn test_peer_side_property_a_bare_node_shows_no_peer(
        read_count in 1..MOST_CALLS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        for _ in 0..read_count {
            let status = read_status_on_bare_node(&node)?;
            prop_assert_eq!(&status["peer"], &Value::Null);
        }
    }

    #[test]
    fn test_published_codes_property_a_bare_node_has_no_problem(
        read_count in 1..MOST_CALLS,
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;

        for _ in 0..read_count {
            let status = read_status_on_bare_node(&node)?;
            prop_assert_eq!(&status["rendezvous_problem"], &Value::Null);
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RUNTIME_CASES))]

    #[test]
    fn test_peer_side_property_a_runtime_takes_live_commands(
        run_id in run_id_strategy(),
    ) {
        let device = TestDevice::start().map_err(fail)?;

        let stopped = device.run(&json!({
            "command": "stop_watching_run",
            "run_id": run_id,
        }));

        prop_assert_eq!(stopped, Ok(Value::Null));
    }

    #[test]
    fn test_attach_peer_side_property_a_started_node_shows_its_peer(
        restart_count in 0..MOST_CALLS,
    ) {
        let mut device = TestDevice::start().map_err(fail)?;
        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
        }

        let status = device.run(&json!({ "command": "status" }))
            .map_err(fail)?;

        let quiet = json!({ "published_address": null, "problem": null });
        prop_assert_eq!(&status["peer"], &quiet);
    }

    #[test]
    fn test_attach_peer_side_property_each_runtime_answers_live_commands(
        run_ids in vec(run_id_strategy(), 1..MOST_CALLS),
    ) {
        let device = TestDevice::start().map_err(fail)?;
        let restarted = device.stop_and_start_again().map_err(fail)?;

        for run_id in &run_ids {
            let stopped = restarted.run(&json!({
                "command": "stop_watching_run",
                "run_id": run_id,
            }));
            prop_assert_eq!(stopped, Ok(Value::Null));
        }
    }

    #[test]
    fn test_attach_peer_side_property_a_bare_node_beside_it_stays_bare(
        run_id in run_id_strategy(),
    ) {
        let device = TestDevice::start().map_err(fail)?;
        let bare_node = open_node(&device.data_directory).map_err(fail)?;

        let refused = run_on_bare_node(
            &bare_node,
            &json!({ "command": "stop_watching_run", "run_id": run_id }),
        );
        let status = device.run(&json!({ "command": "status" }))
            .map_err(fail)?;

        prop_assert_eq!(refused, Err(NO_PEER_ENDPOINT.to_owned()));
        prop_assert!(status["peer"].is_object(), "{}", status);
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(1))]

    #[test]
    fn test_choose_agent_offers_property_a_runner_refuses_no_offers(
        _seed in any::<u8>(),
    ) {
        let started = EngineRunner::start(&local_sandbox(), READY_ENGINE)
            .map_err(fail)?;
        wait_for(SETTINGS_LIMIT, "the runner settings", || {
            let has_settings = started.read_status()["runner_settings"]
                .is_object();
            Ok(has_settings.then_some(()))
        })
        .map_err(fail)?;

        let refused = started.choose_offers(&json!([]));

        prop_assert_eq!(refused, Err(NO_OFFERS.to_owned()));
    }
}
