use std::fs;

use orchestration_core::agent_place::AgentPlace;
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::Index;
use serde_json::{Value, json};

use crate::device_folder::{
    AGENT_PLACE_FILE_NAME, RECORD_FILE_NAMES, create_device_folder,
    list_file_names, open_device_files,
};
use crate::support::test_device::fail;

const CASE_COUNT: u32 = 24;
const MOST_OFFERS: usize = 5;
const LONGEST_CONTENT: usize = 64;
const PLACE_NAMES: [&str; 2] = ["local_process", "container"];

fn place_strategy() -> impl Strategy<Value = AgentPlace> {
    prop_oneof![Just(AgentPlace::LocalProcess), Just(AgentPlace::Container)]
}

fn offers_strategy() -> impl Strategy<Value = Vec<AgentPlace>> {
    vec(place_strategy(), 0..MOST_OFFERS)
}

fn unknown_offers_strategy() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(Value::Null),
        Just(json!({})),
        any::<i64>().prop_map(|number| json!(number)),
        "[a-z_]{1,16}"
            .prop_filter("an unknown place", |name| {
                !PLACE_NAMES.contains(&name.as_str())
            })
            .prop_map(|name| json!([name])),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CASE_COUNT))]

    #[test]
    fn test_save_agent_offers_property_keeps_order_and_repeats(
        offers in offers_strategy(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;

        files.save_agent_offers(&offers).map_err(fail)?;
        let reopened = open_device_files(&folder)?;

        let loaded = reopened.load_agent_offers().map_err(fail)?;
        prop_assert_eq!(loaded, Some(offers));
    }

    #[test]
    fn test_save_agent_offers_property_writes_a_list_of_place_names(
        offers in offers_strategy(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;

        files.save_agent_offers(&offers).map_err(fail)?;

        let names = list_file_names(&folder.data_path)?;
        prop_assert_eq!(names, vec![AGENT_PLACE_FILE_NAME.to_owned()]);
        let stored_path = folder.data_path.join(AGENT_PLACE_FILE_NAME);
        let stored_bytes = fs::read(stored_path).map_err(fail)?;
        let stored: Vec<String> =
            serde_json::from_slice(&stored_bytes).map_err(fail)?;
        prop_assert_eq!(stored.len(), offers.len());
        for stored_name in &stored {
            prop_assert!(PLACE_NAMES.contains(&stored_name.as_str()));
        }
    }

    #[test]
    fn test_save_agent_offers_property_no_offers_differs_from_nothing_saved(
        offers_before in offers_strategy(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        let nothing_saved = files.load_agent_offers().map_err(fail)?;
        files.save_agent_offers(&offers_before).map_err(fail)?;

        files.save_agent_offers(&[]).map_err(fail)?;

        prop_assert_eq!(nothing_saved, None);
        let loaded = files.load_agent_offers().map_err(fail)?;
        prop_assert_eq!(loaded, Some(Vec::new()));
    }

    #[test]
    fn test_load_agent_offers_property_other_files_load_nothing(
        unrelated_name in prop::sample::select(RECORD_FILE_NAMES.to_vec()),
        unrelated_content in vec(any::<u8>(), 0..LONGEST_CONTENT),
    ) {
        prop_assume!(unrelated_name != AGENT_PLACE_FILE_NAME);
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        fs::write(folder.data_path.join(unrelated_name), unrelated_content)
            .map_err(fail)?;

        prop_assert_eq!(files.load_agent_offers().map_err(fail)?, None);
    }

    #[test]
    fn test_load_agent_offers_property_a_half_written_file_is_refused(
        offers in vec(place_strategy(), 1..MOST_OFFERS),
        cut in any::<Index>(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        let whole_bytes = serde_json::to_vec_pretty(&offers).map_err(fail)?;
        let half_bytes = &whole_bytes[..cut.index(whole_bytes.len())];
        fs::write(folder.data_path.join(AGENT_PLACE_FILE_NAME), half_bytes)
            .map_err(fail)?;

        let loaded = files.load_agent_offers();

        prop_assert!(loaded.is_err(), "{:?}", loaded);
    }

    #[test]
    fn test_load_agent_offers_property_an_unknown_place_is_refused(
        unknown_offers in unknown_offers_strategy(),
    ) {
        let folder = create_device_folder()?;
        let files = open_device_files(&folder)?;
        let stored_bytes = serde_json::to_vec(&unknown_offers).map_err(fail)?;
        fs::write(folder.data_path.join(AGENT_PLACE_FILE_NAME), stored_bytes)
            .map_err(fail)?;

        let loaded = files.load_agent_offers();

        prop_assert!(loaded.is_err(), "{:?}", loaded);
    }
}
