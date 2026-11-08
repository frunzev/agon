use proptest::prelude::*;

use crate::drafting_context_steps::{
    DRAFTING_CASES, EMPTY_SECTION_LINE, names_identifier, open_table_or_fail,
    read_section,
};
use crate::handler_desk::{
    create_workspace, name_strategy, read_own_device_id,
};
use crate::support::test_device::fail;

const MOST_HEARTBEATS: usize = 3;
const MOST_LABELS: usize = 3;
const LABEL_PATTERN: &str = "[a-z][a-z0-9]{0,6}";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DRAFTING_CASES))]

    #[test]
    fn test_read_runners_property_without_heartbeats_says_none(
        workspace_name in name_strategy(),
    ) {
        let table = open_table_or_fail()?;
        let workspace_id =
            create_workspace(&table.device, &workspace_name).map_err(fail)?;

        let prompt = table.read_drafting_prompt(&workspace_id).map_err(fail)?;

        let runners = read_section(&prompt, "Runners:");
        prop_assert_eq!(runners, vec![EMPTY_SECTION_LINE]);
    }

    #[test]
    fn test_read_runners_property_shows_a_member_runner_labels(
        labels in prop::collection::vec(LABEL_PATTERN, 0..MOST_LABELS),
    ) {
        let table = open_table_or_fail()?;
        let device_id = read_own_device_id(&table.device).map_err(fail)?;
        table.send_heartbeat(&labels).map_err(fail)?;

        let prompt = table.read_first_prompt().map_err(fail)?;

        let runners = read_section(&prompt, "Runners:");
        prop_assert_eq!(runners.len(), 1);
        let runner_line = runners[0];
        prop_assert!(names_identifier(&runners, &device_id), "{}", prompt);
        prop_assert!(runner_line.contains(", online, "), "{}", runner_line);
        if !labels.is_empty() {
            let label_text = format!("labels: {}", labels.join(", "));
            prop_assert!(runner_line.contains(&label_text), "{}", runner_line);
        }
        prop_assert!(runner_line.ends_with("offers: local_process"));
    }

    #[test]
    fn test_read_runners_property_lists_a_runner_once(
        heartbeat_count in 1..=MOST_HEARTBEATS,
    ) {
        let table = open_table_or_fail()?;
        for _ in 0..heartbeat_count {
            table.send_heartbeat(&[]).map_err(fail)?;
        }

        let prompt = table.read_first_prompt().map_err(fail)?;

        prop_assert_eq!(read_section(&prompt, "Runners:").len(), 1);
    }
}
