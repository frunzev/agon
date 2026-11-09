use std::thread;
use std::time::{Duration, Instant};

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::damaged_device_records::{
    damaged_account_strategy, start_with_damaged_device_record,
};
use crate::peer_publishing::{read_announcement, wait_for_announcement};
use crate::peer_side_steps::{
    PROBLEM_LIMIT, count_publishing, create_account_on,
    read_listed_own_address, start_with_account, wait_for_problem, wait_ticks,
};
use crate::support::test_device::{TestDevice, fail};
use crate::support::test_server::TestServer;
use crate::support::waiting::wait_for;

const PEER_CASES: u32 = 1;
const MOST_TICKS: u32 = 3;
const PARALLEL_READERS: usize = 4;
const LOOK_PAUSE: Duration = Duration::from_millis(50);

fn stop_server_and_restart(
    server: &TestServer,
    device: TestDevice,
) -> Result<TestDevice, String> {
    server.stop()?;
    device.stop_and_start_again()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PEER_CASES))]

    #[test]
    fn test_is_published_property_an_unchanged_address_goes_out_once(
        tick_count in 1..=MOST_TICKS,
    ) {
        let (server, device) = start_with_account().map_err(fail)?;
        wait_for_announcement(&device).map_err(fail)?;

        wait_ticks(tick_count);

        prop_assert_eq!(count_publishing(&server), 1);
    }

    #[test]
    fn test_is_published_property_a_new_identity_publishes_again(
        _seed in any::<u8>(),
    ) {
        let (first_server, device) = start_with_account().map_err(fail)?;
        wait_for_announcement(&device).map_err(fail)?;
        device
            .run(&json!({ "command": "forget_this_device" }))
            .map_err(fail)?;
        let second_server = TestServer::start().map_err(fail)?;
        let first_count = count_publishing(&first_server);

        create_account_on(&device, &second_server).map_err(fail)?;
        let listed = wait_for(
            PROBLEM_LIMIT,
            "the new server to learn the address",
            || {
                let listed = read_listed_own_address(&device)?;
                Ok((!listed.is_null()).then_some(listed))
            },
        );

        prop_assert!(listed.is_ok(), "{:?}", listed);
        prop_assert_eq!(count_publishing(&second_server), 1);
        prop_assert_eq!(count_publishing(&first_server), first_count);
    }

    #[test]
    fn test_is_published_property_a_restart_publishes_again(
        restart_count in 1_usize..3,
    ) {
        let (server, mut device) = start_with_account().map_err(fail)?;
        wait_for_announcement(&device).map_err(fail)?;

        let mut counts = vec![count_publishing(&server)];
        for _ in 0..restart_count {
            device = device.stop_and_start_again().map_err(fail)?;
            wait_for_announcement(&device).map_err(fail)?;
            counts.push(count_publishing(&server));
        }

        for pair in counts.windows(2) {
            prop_assert!(pair[1] > pair[0], "{:?}", counts);
        }
    }

    #[test]
    fn test_peer_side_record_published_property_clears_a_problem(
        _seed in any::<u8>(),
    ) {
        let (server, device) = start_with_account().map_err(fail)?;
        let device = stop_server_and_restart(&server, device).map_err(fail)?;
        wait_for_problem(&device).map_err(fail)?;

        server.start_again().map_err(fail)?;
        wait_for_announcement(&device).map_err(fail)?;
        let recovered = read_announcement(&device).map_err(fail)?;

        prop_assert_eq!(&recovered["problem"], &Value::Null);
    }

    #[test]
    fn test_peer_side_record_published_property_follows_a_restart(
        _seed in any::<u8>(),
    ) {
        let (_server, device) = start_with_account().map_err(fail)?;
        wait_for_announcement(&device).map_err(fail)?;
        let device = device.stop_and_start_again().map_err(fail)?;

        let announced = wait_for_announcement(&device).map_err(fail)?;
        let listed = read_listed_own_address(&device).map_err(fail)?;

        prop_assert_eq!(listed, json!(announced));
    }

    #[test]
    fn test_peer_side_record_published_property_names_the_listed_address(
        tick_count in 0..MOST_TICKS,
    ) {
        let (_server, device) = start_with_account().map_err(fail)?;
        let announced = wait_for_announcement(&device).map_err(fail)?;
        wait_ticks(tick_count);

        let listed = read_listed_own_address(&device).map_err(fail)?;

        prop_assert_eq!(listed, json!(announced));
    }

    #[test]
    fn test_peer_side_record_problem_property_a_lost_server_is_named(
        _seed in any::<u8>(),
    ) {
        let (server, device) = start_with_account().map_err(fail)?;
        let device = stop_server_and_restart(&server, device).map_err(fail)?;

        let problem = wait_for_problem(&device).map_err(fail)?;
        let announcement = read_announcement(&device).map_err(fail)?;

        prop_assert!(!problem.trim().is_empty());
        prop_assert_eq!(&announcement["published_address"], &Value::Null);
    }

    #[test]
    fn test_peer_side_record_problem_property_a_damaged_account_is_named(
        damaged in damaged_account_strategy(),
    ) {
        let device =
            start_with_damaged_device_record(&damaged).map_err(fail)?;

        let problem = wait_for_problem(&device).map_err(fail)?;

        prop_assert!(!problem.trim().is_empty());
    }

    #[test]
    fn test_peer_side_record_problem_property_no_account_is_no_problem(
        tick_count in 1..=MOST_TICKS,
    ) {
        let device = TestDevice::start().map_err(fail)?;

        wait_ticks(tick_count);
        let announcement = read_announcement(&device).map_err(fail)?;

        prop_assert_eq!(&announcement["problem"], &Value::Null);
    }

    #[test]
    fn test_lock_announcement_property_parallel_reads_agree(
        _seed in any::<u8>(),
    ) {
        let (_server, device) = start_with_account().map_err(fail)?;
        wait_for_announcement(&device).map_err(fail)?;

        let announcements = thread::scope(|scope| {
            let mut readers = Vec::new();
            for _ in 0..PARALLEL_READERS {
                readers.push(scope.spawn(|| read_announcement(&device)));
            }
            let mut announcements = Vec::new();
            for reader in readers {
                let read = reader.join();
                announcements
                    .push(read.unwrap_or_else(|_| Err("panicked".into())));
            }
            announcements
        });

        let first = announcements[0].clone().map_err(fail)?;
        for announcement in announcements {
            prop_assert_eq!(announcement.map_err(fail)?, first.clone());
        }
    }

    #[test]
    fn test_lock_announcement_property_published_means_no_problem(
        _seed in any::<u8>(),
    ) {
        let (_server, device) = start_with_account().map_err(fail)?;

        let deadline = Instant::now() + PROBLEM_LIMIT;
        let mut looks = Vec::new();
        while Instant::now() < deadline {
            let announcement = read_announcement(&device).map_err(fail)?;
            let is_published = !announcement["published_address"].is_null();
            looks.push(announcement);
            if is_published {
                break;
            }
            thread::sleep(LOOK_PAUSE);
        }

        for look in &looks {
            if !look["published_address"].is_null() {
                prop_assert_eq!(&look["problem"], &Value::Null);
            }
        }
        let last = looks.last().cloned().unwrap_or_default();
        prop_assert!(!last["published_address"].is_null(), "{}", last);
    }

    #[test]
    fn test_lock_announcement_property_reading_never_changes_it(
        read_count in 2_usize..6,
    ) {
        let (_server, device) = start_with_account().map_err(fail)?;
        wait_for_announcement(&device).map_err(fail)?;

        let mut announcements = Vec::new();
        for _ in 0..read_count {
            announcements.push(read_announcement(&device).map_err(fail)?);
        }

        for announcement in &announcements {
            prop_assert_eq!(announcement, &announcements[0]);
        }
    }
}
