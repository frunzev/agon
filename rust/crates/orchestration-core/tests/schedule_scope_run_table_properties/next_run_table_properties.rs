use chrono::{DateTime, TimeDelta, Utc};
use orchestration_core::schedule_rules::next_run_after;
use orchestration_core::task::Schedule;
use proptest::prelude::*;
use proptest::sample::Index;
use serde::Deserialize;

const SHARED_NEXT_RUN_TABLE: &str =
    include_str!("../fixtures/schedule_next_run_cases.json");

#[derive(Debug, Deserialize)]
struct SharedNextRunTable {
    next_runs: Vec<SharedNextRun>,
}

#[derive(Debug, Deserialize)]
struct SharedNextRun {
    schedule: Schedule,
    after: DateTime<Utc>,
    next: DateTime<Utc>,
}

fn read_shared_next_runs() -> Result<Vec<SharedNextRun>, serde_json::Error> {
    let table: SharedNextRunTable =
        serde_json::from_str(SHARED_NEXT_RUN_TABLE)?;
    Ok(table.next_runs)
}

#[test]
fn test_next_run_after_property_matches_the_shared_next_run_table()
-> Result<(), Box<dyn std::error::Error>> {
    let cases = read_shared_next_runs()?;

    assert!(!cases.is_empty());
    for case in cases {
        let next = next_run_after(&case.schedule, case.after)?;

        assert_eq!(next, case.next, "{case:?}");
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_next_run_after_property_shared_answers_are_strictly_later(
        picked in any::<Index>(),
    ) {
        let cases = read_shared_next_runs()?;
        let case = picked.get(&cases);

        prop_assert!(case.next > case.after, "{:?}", case);
    }

    #[test]
    fn test_next_run_after_property_earlier_moments_wait_for_the_answer(
        picked in any::<Index>(),
        earlier_seconds in 1_i64..3_600,
    ) {
        let cases = read_shared_next_runs()?;
        let case = picked.get(&cases);
        let span = (case.next - case.after).num_seconds().max(1);
        let wait_left = TimeDelta::seconds(earlier_seconds % span + 1);
        let earlier = case.next - wait_left;
        let waiting_from = earlier.max(case.after);

        let next = next_run_after(&case.schedule, waiting_from);

        prop_assert_eq!(next, Ok(case.next));
    }
}
