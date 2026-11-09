use std::collections::BTreeMap;
use std::path::Path;

use orchestration_core::device::SandboxKind;
use orchestration_hub::clone_source::CloneSource;
use orchestration_node::node_error::NodeError;
use orchestration_node::runner_bridge::build_runner_configuration;
use orchestration_node::runner_settings::{RunnerSettings, SandboxSettings};
use orchestration_runner::runner_configuration::RunnerConfiguration;
use proptest::prelude::*;
use proptest::sample::subsequence;

use crate::runner_settings_samples::{
    ProcessEnvironment, data_directory, environment_strategy,
    sandbox_strategy, settings_strategy,
};
use crate::support::test_device::fail;

const INVALID_SETTINGS_START: &str = "invalid runner settings";
const MOST_SANDBOXES: usize = 4;

fn build(
    settings: &RunnerSettings,
    offered: &[SandboxSettings],
    process_environment: &ProcessEnvironment,
) -> Result<RunnerConfiguration, NodeError> {
    build_runner_configuration(
        settings,
        offered,
        &data_directory(),
        process_environment,
    )
}

fn offered_strategy() -> impl Strategy<Value = Vec<SandboxSettings>> {
    prop::collection::vec(sandbox_strategy(), 1..MOST_SANDBOXES)
}

fn environment_with_names_strategy()
-> impl Strategy<Value = (ProcessEnvironment, Vec<String>)> {
    environment_strategy().prop_flat_map(|environment| {
        let names: Vec<String> = environment.keys().cloned().collect();
        let name_count = names.len();
        (Just(environment), subsequence(names, 0..=name_count))
    })
}

fn invalid_template_strategy() -> impl Strategy<Value = String> {
    prop_oneof![
        "https://[a-z/]{1,12}\\.git",
        "https://\\{address\\}/\\{address\\}",
        "https://[a-z]{1,6} \\{address\\}",
        "file://[a-z]{1,6}\t\\{address\\}",
    ]
}

fn is_inside(folder: &Path, root: &Path) -> bool {
    folder.starts_with(root) && folder != root
}

proptest! {
    #[test]
    fn test_describe_clone_source_property_no_template_is_standard(
        settings in settings_strategy(),
        offered in offered_strategy(),
    ) {
        let mut plain = settings;
        plain.clone_url_template = None;

        let configuration = build(&plain, &offered, &BTreeMap::new())
            .map_err(fail)?;

        prop_assert_eq!(configuration.clone_source, CloneSource::standard());
    }

    #[test]
    fn test_describe_clone_source_property_a_template_is_kept(
        settings in settings_strategy(),
        offered in offered_strategy(),
        template in "(file|https)://[a-z/.-]{1,16}\\{address\\}[a-z/.]{0,8}",
    ) {
        let mut templated = settings;
        templated.clone_url_template = Some(template.clone());

        let configuration = build(&templated, &offered, &BTreeMap::new())
            .map_err(fail)?;

        let expected = CloneSource::from_template(&template).map_err(fail)?;
        prop_assert_eq!(configuration.clone_source, expected);
    }

    #[test]
    fn test_describe_clone_source_property_a_broken_template_stops(
        settings in settings_strategy(),
        offered in offered_strategy(),
        template in invalid_template_strategy(),
    ) {
        let mut templated = settings;
        templated.clone_url_template = Some(template);

        let built = build(&templated, &offered, &BTreeMap::new());

        let Err(NodeError::Startup(problem)) = built else {
            return Err(fail(format!("{built:?}")));
        };
        let is_settings_problem = problem.starts_with(INVALID_SETTINGS_START);
        prop_assert!(is_settings_problem, "{}", problem);
    }

    #[test]
    fn test_pick_passed_environment_property_passes_only_named_variables(
        settings in settings_strategy(),
        offered in offered_strategy(),
        (environment, names) in environment_with_names_strategy(),
    ) {
        let mut passing = settings;
        passing.passed_environment = names.clone();

        let configuration = build(&passing, &offered, &environment)
            .map_err(fail)?;

        let mut expected = BTreeMap::new();
        for name in &names {
            expected.insert(name.clone(), environment[name].clone());
        }
        for sandbox in &configuration.sandboxes {
            prop_assert_eq!(&sandbox.environment, &expected);
        }
    }

    #[test]
    fn test_pick_passed_environment_property_a_missing_name_is_named(
        settings in settings_strategy(),
        offered in offered_strategy(),
        environment in environment_strategy(),
        missing_name in "MISSING_[A-Z]{1,10}",
    ) {
        let mut passing = settings;
        passing.passed_environment = vec![missing_name.clone()];

        let built = build(&passing, &offered, &environment);

        let Err(NodeError::Startup(problem)) = built else {
            return Err(fail(format!("{built:?}")));
        };
        prop_assert!(problem.contains(&missing_name), "{}", problem);
        prop_assert!(problem.starts_with(INVALID_SETTINGS_START));
    }

    #[test]
    fn test_pick_passed_environment_property_repeated_names_pass_once(
        settings in settings_strategy(),
        offered in offered_strategy(),
        (environment, names) in environment_with_names_strategy(),
    ) {
        let mut once = settings.clone();
        once.passed_environment = names.clone();
        let mut twice = settings;
        twice.passed_environment = [names.clone(), names].concat();

        let passed_once = build(&once, &offered, &environment)
            .map_err(fail)?;
        let passed_twice = build(&twice, &offered, &environment)
            .map_err(fail)?;

        prop_assert_eq!(passed_once, passed_twice);
    }

    #[test]
    fn test_describe_sandbox_property_one_sandbox_per_offer_in_order(
        settings in settings_strategy(),
        offered in offered_strategy(),
    ) {
        let configuration = build(&settings, &offered, &BTreeMap::new())
            .map_err(fail)?;

        let mut expected_kinds = Vec::new();
        for sandbox in &offered {
            expected_kinds.push(match sandbox {
                SandboxSettings::LocalProcess => SandboxKind::LocalProcess,
                SandboxSettings::Container { .. } => SandboxKind::Container,
            });
        }
        let mut built_kinds = Vec::new();
        for sandbox in &configuration.sandboxes {
            built_kinds.push(sandbox.kind);
        }
        prop_assert_eq!(built_kinds, expected_kinds);
    }

    #[test]
    fn test_describe_sandbox_property_a_container_keeps_image_and_hosts(
        settings in settings_strategy(),
        offered in offered_strategy(),
    ) {
        let configuration = build(&settings, &offered, &BTreeMap::new())
            .map_err(fail)?;

        for (sandbox, built) in offered.iter().zip(&configuration.sandboxes) {
            if let SandboxSettings::Container { image, allowed_hosts, .. } =
                sandbox
            {
                prop_assert_eq!(&built.container.image, image);
                prop_assert_eq!(&built.allowed_hosts, allowed_hosts);
            }
        }
    }

    #[test]
    fn test_describe_sandbox_property_this_computer_allows_no_hosts(
        settings in settings_strategy(),
        offered in offered_strategy(),
    ) {
        let configuration = build(&settings, &offered, &BTreeMap::new())
            .map_err(fail)?;

        for built in &configuration.sandboxes {
            if built.kind == SandboxKind::LocalProcess {
                prop_assert!(built.allowed_hosts.is_empty());
            }
        }
    }

    #[test]
    fn test_build_runner_configuration_property_folders_stay_in_data(
        settings in settings_strategy(),
        offered in offered_strategy(),
    ) {
        let configuration = build(&settings, &offered, &BTreeMap::new())
            .map_err(fail)?;

        let roots = &configuration.worktree_roots;
        let data_folder = data_directory();
        prop_assert!(is_inside(&roots.cache_root, &data_folder));
        prop_assert!(is_inside(&roots.worktrees_root, &data_folder));
        prop_assert_ne!(&roots.cache_root, &roots.worktrees_root);
    }

    #[test]
    fn test_build_runner_configuration_property_keeps_labels_and_slots(
        settings in settings_strategy(),
        offered in offered_strategy(),
    ) {
        let configuration = build(&settings, &offered, &BTreeMap::new())
            .map_err(fail)?;

        prop_assert_eq!(&configuration.labels, &settings.labels);
        prop_assert_eq!(configuration.slot_capacity, settings.slot_capacity);
    }
}
