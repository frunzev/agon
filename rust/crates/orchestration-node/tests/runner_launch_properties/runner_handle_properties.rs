use std::thread;
use std::time::Duration;

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::engine_desk::{
    CLAIM_PATH, LONGER_THAN_A_CLAIM_INTERVAL, RUNNER_LIMIT,
};
use crate::launch_desk::{
    LAUNCH_CASES, LaunchDesk, QUIET_PERIOD, SILENCE_LIMIT, ask_live_host,
    ask_live_host_patiently, count_runner_requests, local_settings,
    open_launch_desk, read_heartbeats, unknown_run_refusal,
    wait_for_first_heartbeat, wait_for_own_address,
};
use crate::support::test_device::{describe, fail};
use crate::support::test_server::TestServer;
use crate::support::waiting::wait_for;

const LABEL_PATTERN: &str = "[a-z][a-z0-9]{0,7}";
const MOST_SLOTS: u32 = 8;
const MOST_PARALLEL_COMMANDS: usize = 6;
const CLAIM_WATCH_PERIOD: Duration = Duration::from_millis(10_500);
const MOST_CLAIMS_OF_ONE_LOOP: usize = 3;

fn open_runner_desk() -> Result<LaunchDesk, TestCaseError> {
    open_launch_desk(&local_settings(&[], 1), "runner").map_err(fail)
}

fn count_claims(server: &TestServer) -> usize {
    let mut claim_count = 0;
    for request in server.recorded_requests() {
        if request.path == CLAIM_PATH {
            claim_count += 1;
        }
    }
    claim_count
}

fn send_in_parallel(desk: &LaunchDesk, command_count: usize) -> Vec<bool> {
    let status = json!({ "command": "status" });
    thread::scope(|scope| {
        let mut sendings = Vec::new();
        for _ in 0..command_count {
            sendings.push(scope.spawn(|| desk.device.run(&status).is_ok()));
        }
        let mut outcomes = Vec::new();
        for sending in sendings {
            outcomes.push(sending.join().unwrap_or(false));
        }
        outcomes
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LAUNCH_CASES))]

    #[test]
    fn test_runner_handle_start_property_announces_itself_at_once(
        slot_capacity in 1..MOST_SLOTS,
    ) {
        let settings = local_settings(&[], slot_capacity);
        let desk = open_launch_desk(&settings, "runner").map_err(fail)?;

        let heartbeat = wait_for_first_heartbeat(&desk.server).map_err(fail)?;

        prop_assert_eq!(&heartbeat["slots_busy"], &json!(0));
        prop_assert_eq!(&heartbeat["offers"], &json!(["local_process"]));
    }

    #[test]
    fn test_runner_handle_start_property_the_live_host_answers(
        number in any::<u128>(),
    ) {
        let desk = open_runner_desk()?;
        let address = wait_for_own_address(&desk.device).map_err(fail)?;

        let reply = ask_live_host_patiently(&address, number).map_err(fail)?;

        prop_assert_eq!(reply, unknown_run_refusal(number));
    }

    #[test]
    fn test_runner_handle_start_property_claims_follow_the_heartbeat(
        _seed in any::<u8>(),
    ) {
        let desk = open_runner_desk()?;

        wait_for_first_heartbeat(&desk.server).map_err(fail)?;
        let claimed = wait_for(RUNNER_LIMIT, "a claim", || {
            Ok((count_claims(&desk.server) > 0).then_some(()))
        });

        prop_assert_eq!(claimed, Ok(()));
    }

    #[test]
    fn test_runner_launcher_stop_property_dropping_ends_every_request(
        _seed in any::<u8>(),
    ) {
        let LaunchDesk { server, device } = open_runner_desk()?;
        wait_for_first_heartbeat(&server).map_err(fail)?;

        drop(device);
        let requests_when_stopped = count_runner_requests(&server);
        thread::sleep(LONGER_THAN_A_CLAIM_INTERVAL);

        prop_assert_eq!(count_runner_requests(&server), requests_when_stopped);
    }

    #[test]
    fn test_runner_launcher_stop_property_dropping_ends_the_live_host(
        number in any::<u128>(),
    ) {
        let LaunchDesk { server, device } = open_runner_desk()?;
        let address = wait_for_own_address(&device).map_err(fail)?;
        let served = ask_live_host_patiently(&address, number);
        prop_assert_eq!(served.map_err(fail)?, unknown_run_refusal(number));

        drop(device);
        let after_stop = ask_live_host(&address, number, SILENCE_LIMIT);

        prop_assert!(after_stop.is_err(), "{:?}", after_stop);
        drop(server);
    }

    #[test]
    fn test_runner_launcher_stop_property_a_restart_runs_one_loop_again(
        _seed in any::<u8>(),
    ) {
        let LaunchDesk { server, mut device } = open_runner_desk()?;
        wait_for_first_heartbeat(&server).map_err(fail)?;

        device.restart().map_err(fail)?;
        let announced_again = wait_for(RUNNER_LIMIT, "a second heartbeat", || {
            Ok((read_heartbeats(&server).len() >= 2).then_some(()))
        });
        let claims_before = count_claims(&server);
        thread::sleep(CLAIM_WATCH_PERIOD);
        let claims_in_period = count_claims(&server) - claims_before;

        prop_assert_eq!(announced_again, Ok(()));
        prop_assert!(claims_in_period >= 1, "{}", claims_in_period);
        prop_assert!(
            claims_in_period <= MOST_CLAIMS_OF_ONE_LOOP,
            "{}",
            claims_in_period
        );
    }

    #[test]
    fn test_configure_for_device_property_heartbeats_carry_the_labels(
        labels in prop::collection::vec(LABEL_PATTERN, 0..4),
    ) {
        let settings = local_settings(&labels, 1);
        let desk = open_launch_desk(&settings, "runner").map_err(fail)?;

        let heartbeat = wait_for_first_heartbeat(&desk.server).map_err(fail)?;

        prop_assert_eq!(&heartbeat["labels"], &json!(labels));
    }

    #[test]
    fn test_configure_for_device_property_heartbeats_count_the_slots(
        slot_capacity in 1..MOST_SLOTS,
    ) {
        let settings = local_settings(&[], slot_capacity);
        let desk = open_launch_desk(&settings, "runner").map_err(fail)?;

        let heartbeat = wait_for_first_heartbeat(&desk.server).map_err(fail)?;

        prop_assert_eq!(&heartbeat["slots_total"], &json!(slot_capacity));
    }

    #[test]
    fn test_lock_runner_property_parallel_commands_start_one_loop(
        command_count in 2..=MOST_PARALLEL_COMMANDS,
    ) {
        let desk = open_runner_desk()?;
        wait_for_first_heartbeat(&desk.server).map_err(fail)?;

        send_in_parallel(&desk, command_count);
        let claims_before = count_claims(&desk.server);
        thread::sleep(CLAIM_WATCH_PERIOD);
        let claims_in_period = count_claims(&desk.server) - claims_before;

        prop_assert!(
            claims_in_period <= MOST_CLAIMS_OF_ONE_LOOP,
            "{}",
            claims_in_period
        );
    }

    #[test]
    fn test_lock_runner_property_parallel_commands_all_get_replies(
        command_count in 2..=MOST_PARALLEL_COMMANDS,
    ) {
        let desk = open_runner_desk()?;

        let outcomes = send_in_parallel(&desk, command_count);

        prop_assert_eq!(outcomes, vec![true; command_count]);
    }

    #[test]
    fn test_lock_runner_property_the_live_host_survives_parallel_commands(
        command_count in 2..=MOST_PARALLEL_COMMANDS,
        number in any::<u128>(),
    ) {
        let desk = open_runner_desk()?;
        let address = wait_for_own_address(&desk.device).map_err(fail)?;

        send_in_parallel(&desk, command_count);
        thread::sleep(QUIET_PERIOD);
        let reply = ask_live_host_patiently(&address, number)
            .map_err(describe)
            .map_err(fail)?;

        prop_assert_eq!(reply, unknown_run_refusal(number));
        let settings = desk.device.run(&json!({ "command": "status" }));
        let in_effect =
            settings.map(|status| status["runner_settings"].clone());
        prop_assert!(in_effect.is_ok_and(|value| value != Value::Null));
    }
}
