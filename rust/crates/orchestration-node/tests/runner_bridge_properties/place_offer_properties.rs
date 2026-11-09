use std::fs;
use std::path::PathBuf;

use orchestration_core::agent_place::AgentPlace;
use orchestration_node::device_files::DeviceFiles;
use orchestration_node::place_offers::{
    PlaceOffer, find_blocking_problem, normalize_offers,
};
use proptest::prelude::*;
use tempfile::TempDir;

use crate::runner_settings_samples::{offers_strategy, place_strategy};
use crate::support::test_device::fail;

const OFFERS_FILE_NAME: &str = "agent-place.json";
const PROBLEM_PATTERN: &str = "\\PC{1,30}";
const MOST_OFFERS: usize = 5;

fn blocked_offers_strategy() -> impl Strategy<Value = Vec<PlaceOffer>> {
    prop::collection::vec((place_strategy(), PROBLEM_PATTERN), 1..MOST_OFFERS)
        .prop_map(|offers| {
            let mut blocked = Vec::new();
            for (place, problem) in offers {
                blocked.push(PlaceOffer {
                    place,
                    problem: Some(problem),
                });
            }
            blocked
        })
}

fn damaged_offers_strategy() -> impl Strategy<Value = String> {
    prop_oneof![
        Just("\"elsewhere\"".to_owned()),
        Just("{}".to_owned()),
        Just("[1]".to_owned()),
        Just("[\"container\", null]".to_owned()),
        "[a-z]{1,12}",
    ]
}

fn offers_path(data_directory: &TempDir) -> PathBuf {
    data_directory.path().join(OFFERS_FILE_NAME)
}

fn open_files() -> Result<(TempDir, DeviceFiles), TestCaseError> {
    let data_directory = TempDir::new().map_err(fail)?;
    let files = DeviceFiles::open(data_directory.path()).map_err(fail)?;
    Ok((data_directory, files))
}

proptest! {
    #[test]
    fn test_normalize_offers_property_is_idempotent(
        offers in offers_strategy(),
    ) {
        let normalized = normalize_offers(&offers);

        prop_assert_eq!(normalize_offers(&normalized), normalized);
    }

    #[test]
    fn test_normalize_offers_property_this_computer_comes_first(
        offers in offers_strategy(),
    ) {
        let normalized = normalize_offers(&offers);

        let mut expected = Vec::new();
        if offers.contains(&AgentPlace::LocalProcess) {
            expected.push(AgentPlace::LocalProcess);
        }
        if offers.contains(&AgentPlace::Container) {
            expected.push(AgentPlace::Container);
        }
        prop_assert_eq!(normalized, expected);
    }

    #[test]
    fn test_normalize_offers_property_the_given_order_never_matters(
        offers in offers_strategy(),
    ) {
        let mut reversed = offers.clone();
        reversed.reverse();

        let from_reversed = normalize_offers(&reversed);
        prop_assert_eq!(from_reversed, normalize_offers(&offers));
    }

    #[test]
    fn test_find_blocking_problem_property_names_the_first_problem(
        offers in blocked_offers_strategy(),
    ) {
        let problem = find_blocking_problem(&offers);

        prop_assert_eq!(problem, offers[0].problem.clone());
    }

    #[test]
    fn test_find_blocking_problem_property_one_working_offer_clears_it(
        offers in blocked_offers_strategy(),
        working_place in place_strategy(),
        position in any::<prop::sample::Index>(),
    ) {
        let mut mixed = offers;
        let working = PlaceOffer { place: working_place, problem: None };
        mixed.insert(position.index(mixed.len() + 1), working);

        prop_assert_eq!(find_blocking_problem(&mixed), None);
    }

    #[test]
    fn test_find_blocking_problem_property_this_computer_speaks_first(
        offers in offers_strategy(),
        local_problem in PROBLEM_PATTERN,
        container_problem in PROBLEM_PATTERN,
    ) {
        let mut checked = Vec::new();
        for place in normalize_offers(&offers) {
            let problem = match place {
                AgentPlace::LocalProcess => local_problem.clone(),
                AgentPlace::Container => container_problem.clone(),
            };
            checked.push(PlaceOffer { place, problem: Some(problem) });
        }

        let problem = find_blocking_problem(&checked);

        let expected = if offers.contains(&AgentPlace::LocalProcess) {
            Some(local_problem)
        } else if offers.contains(&AgentPlace::Container) {
            Some(container_problem)
        } else {
            None
        };
        prop_assert_eq!(problem, expected);
    }

    #[test]
    fn test_into_offers_property_an_older_single_place_is_one_offer(
        place in place_strategy(),
    ) {
        let (data_directory, files) = open_files()?;
        let stored = serde_json::to_string(&place).map_err(fail)?;
        fs::write(offers_path(&data_directory), stored).map_err(fail)?;

        let loaded = files.load_agent_offers().map_err(fail)?;

        prop_assert_eq!(loaded, Some(vec![place]));
    }

    #[test]
    fn test_into_offers_property_saved_offers_read_back_unchanged(
        offers in offers_strategy(),
    ) {
        let (_data_directory, files) = open_files()?;
        let normalized = normalize_offers(&offers);
        files.save_agent_offers(&normalized).map_err(fail)?;

        let loaded = files.load_agent_offers().map_err(fail)?;

        prop_assert_eq!(loaded, Some(normalized));
    }

    #[test]
    fn test_into_offers_property_damaged_offers_are_refused(
        damaged in damaged_offers_strategy(),
    ) {
        let (data_directory, files) = open_files()?;
        fs::write(offers_path(&data_directory), damaged).map_err(fail)?;

        let loaded = files.load_agent_offers();

        prop_assert!(loaded.is_err(), "{:?}", loaded);
    }
}
