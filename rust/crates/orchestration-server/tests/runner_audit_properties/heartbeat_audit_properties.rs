use orchestration_api::updates::AuditView;
use orchestration_core::device::DeviceRole;
use proptest::collection::vec;
use proptest::prelude::*;

use crate::fixtures::{
    create_account, heartbeat_with, identity_from_seed, pair_device,
    send_heartbeat,
};
use crate::test_client::{TestServer, block_on};

const AUDIT_CASES: u32 = 12;
const RUNNER_SEED: u8 = 41;
const RUNNER_NAME: &str = "gpu-box";
const AUDIT_PATH: &str = "/audit";
const MOST_SLOTS: u32 = 5;
const MOST_REPORTS: usize = 6;

type SlotReport = (u32, u32);

fn slot_report_strategy() -> impl Strategy<Value = SlotReport> {
    (0..MOST_SLOTS)
        .prop_flat_map(|slots_total| (Just(slots_total), 0..=slots_total))
}

fn describe_expected_report(report: SlotReport) -> String {
    let (slots_total, slots_busy) = report;
    let slot_noun = if slots_total == 1 { "slot" } else { "slots" };
    let counts = format!("{slots_busy} of {slots_total} {slot_noun}");
    format!("{RUNNER_NAME} reported {counts} busy")
}

fn report_and_read_heartbeat_events(reports: &[SlotReport]) -> Vec<String> {
    let test = TestServer::start();
    let audit: AuditView = block_on(async {
        let account = create_account(&test).await;
        let runner = identity_from_seed(RUNNER_SEED);
        let role = DeviceRole::Runner;
        pair_device(&test, &account, &runner, RUNNER_NAME, role).await;
        for (slots_total, slots_busy) in reports {
            let heartbeat = heartbeat_with(&[], *slots_total, *slots_busy);
            send_heartbeat(&test, &runner, &heartbeat).await;
        }
        test.get(&account.owner, AUDIT_PATH).await.json()
    });
    let report_prefix = format!("{RUNNER_NAME} reported ");
    let mut heartbeat_events = Vec::new();
    for entry in audit.entries {
        if entry.event.starts_with(&report_prefix) {
            heartbeat_events.push(entry.event);
        }
    }
    heartbeat_events
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(AUDIT_CASES))]

    #[test]
    fn test_record_heartbeat_property_one_slot_is_named_in_the_singular(
        slots_busy in 0_u32..=1,
    ) {
        let report = (1, slots_busy);

        let events = report_and_read_heartbeat_events(&[report]);

        let expected =
            format!("{RUNNER_NAME} reported {slots_busy} of 1 slot busy");
        prop_assert_eq!(events, vec![expected]);
    }

    #[test]
    fn test_record_heartbeat_property_other_totals_are_named_in_the_plural(
        report in slot_report_strategy()
            .prop_filter("not one slot", |report| report.0 != 1),
    ) {
        let events = report_and_read_heartbeat_events(&[report]);

        prop_assert_eq!(events.len(), 1);
        prop_assert!(events[0].ends_with(" slots busy"), "{}", events[0]);
        prop_assert_eq!(&events[0], &describe_expected_report(report));
    }

    #[test]
    fn test_record_heartbeat_property_each_changed_report_is_named_once(
        reports in vec(slot_report_strategy(), 1..MOST_REPORTS),
    ) {
        let events = report_and_read_heartbeat_events(&reports);

        let mut expected_events = Vec::new();
        let mut previous_report = None;
        for report in &reports {
            if previous_report != Some(*report) {
                expected_events.push(describe_expected_report(*report));
            }
            previous_report = Some(*report);
        }
        prop_assert_eq!(events, expected_events);
    }
}
