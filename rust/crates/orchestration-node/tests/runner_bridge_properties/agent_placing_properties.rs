use std::collections::BTreeMap;

use orchestration_core::agent_place::find_sandbox_place;
use orchestration_node::runner_bridge::{
    build_runner_configuration, find_settings_place, offer_sandboxes,
};
use orchestration_node::runner_settings::SandboxSettings;
use proptest::prelude::*;

use crate::runner_settings_samples::{
    container_strategy, data_directory, sandbox_strategy, settings_strategy,
};
use crate::support::test_device::fail;

proptest! {
    #[test]
    fn test_find_settings_place_property_agrees_with_the_built_sandbox(
        settings in settings_strategy(),
        sandbox in sandbox_strategy(),
    ) {
        let configuration = build_runner_configuration(
            &settings,
            std::slice::from_ref(&sandbox),
            &data_directory(),
            &BTreeMap::new(),
        )
        .map_err(fail)?;

        let built_place = find_sandbox_place(configuration.sandboxes[0].kind);
        prop_assert_eq!(built_place, Some(find_settings_place(&sandbox)));
    }

    #[test]
    fn test_find_settings_place_property_offering_it_keeps_the_sandbox(
        settings in settings_strategy(),
        detected_container in container_strategy(),
    ) {
        let place = find_settings_place(&settings.sandbox);

        let sandboxes =
            offer_sandboxes(&settings, &[place], &detected_container);

        prop_assert_eq!(sandboxes, vec![settings.sandbox.clone()]);
    }

    #[test]
    fn test_find_settings_place_property_survives_a_json_round_trip(
        sandbox in sandbox_strategy(),
    ) {
        let stored = serde_json::to_string(&sandbox).map_err(fail)?;
        let read_back: SandboxSettings =
            serde_json::from_str(&stored).map_err(fail)?;

        prop_assert_eq!(
            find_settings_place(&read_back),
            find_settings_place(&sandbox)
        );
    }
}
