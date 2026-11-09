use std::collections::BTreeMap;

use orchestration_core::device::SandboxKind;
use orchestration_hub::sandbox::ContainerEngine;
use orchestration_node::runner_bridge::build_runner_configuration;
use orchestration_node::runner_settings::{
    ContainerEngineChoice, RunnerSettings, SandboxSettings,
};
use orchestration_runner::agent_sandbox::AgentSandbox;
use proptest::prelude::*;

use crate::runner_settings_samples::{
    container_strategy, data_directory, engine_strategy, settings_strategy,
};
use crate::support::test_device::fail;

const ENGINE_FIELD: &str = "engine";

fn build_sandboxes(
    settings: &RunnerSettings,
    offered: &[SandboxSettings],
) -> Result<Vec<AgentSandbox>, TestCaseError> {
    let configuration = build_runner_configuration(
        settings,
        offered,
        &data_directory(),
        &BTreeMap::new(),
    )
    .map_err(fail)?;
    Ok(configuration.sandboxes)
}

fn container_with(
    engine: ContainerEngineChoice,
    image: &str,
) -> SandboxSettings {
    SandboxSettings::Container {
        engine,
        image: image.to_owned(),
        allowed_hosts: Vec::new(),
    }
}

proptest! {
    #[test]
    fn test_unused_container_property_this_computer_carries_no_image(
        settings in settings_strategy(),
        container in container_strategy(),
    ) {
        let offered = [SandboxSettings::LocalProcess, container];

        let sandboxes = build_sandboxes(&settings, &offered)?;

        prop_assert_eq!(sandboxes[0].kind, SandboxKind::LocalProcess);
        prop_assert!(sandboxes[0].container.image.is_empty());
    }

    #[test]
    fn test_unused_container_property_ignores_the_given_container(
        settings in settings_strategy(),
        container in container_strategy(),
    ) {
        let mut local_settings = settings.clone();
        local_settings.sandbox = SandboxSettings::LocalProcess;
        let mut container_settings = settings;
        container_settings.sandbox = container;
        let offered = [SandboxSettings::LocalProcess];

        let from_local = build_sandboxes(&local_settings, &offered)?;
        let from_container = build_sandboxes(&container_settings, &offered)?;

        prop_assert_eq!(from_local, from_container);
    }

    #[test]
    fn test_unused_container_property_every_local_sandbox_is_the_same(
        settings in settings_strategy(),
        container in container_strategy(),
    ) {
        let offered = [
            SandboxSettings::LocalProcess,
            container,
            SandboxSettings::LocalProcess,
        ];

        let sandboxes = build_sandboxes(&settings, &offered)?;

        prop_assert_eq!(&sandboxes[0], &sandboxes[2]);
    }

    #[test]
    fn test_choose_engine_property_maps_each_choice_to_its_engine(
        settings in settings_strategy(),
        engine in engine_strategy(),
        image in "[a-z]{1,8}:[a-z0-9]{1,4}",
    ) {
        let offered = [container_with(engine, &image)];

        let sandboxes = build_sandboxes(&settings, &offered)?;

        let expected = match engine {
            ContainerEngineChoice::Docker => ContainerEngine::Docker,
            ContainerEngineChoice::Podman => ContainerEngine::Podman,
        };
        prop_assert_eq!(sandboxes[0].container.engine, expected);
    }

    #[test]
    fn test_choose_engine_property_different_choices_stay_different(
        settings in settings_strategy(),
        image in "[a-z]{1,8}:[a-z0-9]{1,4}",
    ) {
        let offered = [
            container_with(ContainerEngineChoice::Docker, &image),
            container_with(ContainerEngineChoice::Podman, &image),
        ];

        let sandboxes = build_sandboxes(&settings, &offered)?;

        prop_assert_ne!(
            sandboxes[0].container.engine,
            sandboxes[1].container.engine
        );
    }

    #[test]
    fn test_choose_engine_property_the_stored_name_names_the_engine(
        settings in settings_strategy(),
        engine in engine_strategy(),
        image in "[a-z]{1,8}:[a-z0-9]{1,4}",
    ) {
        let container = container_with(engine, &image);
        let stored = serde_json::to_value(&container).map_err(fail)?;

        let sandboxes = build_sandboxes(&settings, &[container])?;

        let built_name =
            format!("{:?}", sandboxes[0].container.engine).to_lowercase();
        prop_assert_eq!(&stored[ENGINE_FIELD], &serde_json::json!(built_name));
    }
}
