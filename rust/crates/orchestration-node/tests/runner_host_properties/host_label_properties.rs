use std::collections::BTreeSet;

use orchestration_hub::sandbox::ensure_valid_image;
use orchestration_node::runner_bridge::{
    HostFacts, detect_container_sandbox, detect_runner_settings,
};
use orchestration_node::runner_settings::{
    ContainerEngineChoice, SandboxSettings,
};
use proptest::prelude::*;
use proptest::sample::{select, subsequence};

const XCODE_PROGRAM: &str = "xcodebuild";
const DOCKER_PROGRAM: &str = "docker";
const PODMAN_PROGRAM: &str = "podman";
const ENGINE_PROGRAMS: [&str; 2] = [DOCKER_PROGRAM, PODMAN_PROGRAM];
const PROBED_PROGRAMS: [&str; 3] =
    [XCODE_PROGRAM, DOCKER_PROGRAM, PODMAN_PROGRAM];
const XCODE_LABEL: &str = "xcode";
const DOCUMENTED_SYSTEMS: [(&str, &str); 1] = [("macos", "mac")];
const DOCUMENTED_PROCESSORS: [(&str, &str); 2] =
    [("aarch64", "arm64"), ("x86_64", "x64")];
const TABLE_NAMES: [&str; 3] = ["macos", "aarch64", "x86_64"];
const MOST_PROCESSORS: usize = 512;

fn any_name() -> impl Strategy<Value = String> {
    prop_oneof![
        select(TABLE_NAMES.to_vec()).prop_map(str::to_owned),
        select(vec!["mac", "arm64", "x64", "xcode", "linux"])
            .prop_map(str::to_owned),
        "[a-z0-9_]{1,10}",
        "\\PC{1,8}",
    ]
}

type FactParts = (String, String, usize, BTreeSet<String>);

fn collect_programs(found: Vec<&str>) -> BTreeSet<String> {
    let mut programs = BTreeSet::new();
    for program in found {
        programs.insert(program.to_owned());
    }
    programs
}

fn programs_strategy() -> impl Strategy<Value = BTreeSet<String>> {
    let all_programs = PROBED_PROGRAMS.to_vec();
    subsequence(all_programs, 0..=PROBED_PROGRAMS.len())
        .prop_map(collect_programs)
}

fn build_host_facts(parts: FactParts) -> HostFacts {
    let (operating_system, architecture, processor_count, programs_found) =
        parts;
    HostFacts {
        operating_system,
        architecture,
        processor_count,
        programs_found,
    }
}

fn host_facts_strategy() -> impl Strategy<Value = HostFacts> {
    let processors = 0..MOST_PROCESSORS;
    (any_name(), any_name(), processors, programs_strategy())
        .prop_map(build_host_facts)
}

fn translate_with(name: &str, table: &[(&str, &str)]) -> String {
    for (original, label) in table {
        if *original == name {
            return (*label).to_owned();
        }
    }
    name.to_owned()
}

fn expected_labels(facts: &HostFacts) -> Vec<String> {
    let mut candidates = vec![
        translate_with(&facts.operating_system, &DOCUMENTED_SYSTEMS),
        translate_with(&facts.architecture, &DOCUMENTED_PROCESSORS),
    ];
    if facts.programs_found.contains(XCODE_PROGRAM) {
        candidates.push(XCODE_LABEL.to_owned());
    }
    let mut labels = Vec::new();
    for candidate in candidates {
        if !labels.contains(&candidate) {
            labels.push(candidate);
        }
    }
    labels
}

fn with_program(facts: &HostFacts, program: &str) -> HostFacts {
    let mut programs_found = facts.programs_found.clone();
    programs_found.insert(program.to_owned());
    HostFacts {
        programs_found,
        ..facts.clone()
    }
}

fn is_host_name_character(character: char) -> bool {
    character.is_ascii_lowercase()
        || character.is_ascii_digit()
        || character == '.'
        || character == '-'
}

fn is_plain_host_name(host: &str) -> bool {
    !host.is_empty() && host.chars().all(is_host_name_character)
}

proptest! {
    #[test]
    fn test_describe_labels_property_matches_the_documented_model(
        facts in host_facts_strategy(),
    ) {
        let settings = detect_runner_settings(&facts);

        prop_assert_eq!(settings.labels, expected_labels(&facts));
    }

    #[test]
    fn test_describe_labels_property_never_repeats_a_label(
        name in any_name(),
        programs_found in programs_strategy(),
    ) {
        let facts = HostFacts {
            operating_system: name.clone(),
            architecture: name,
            processor_count: 1,
            programs_found,
        };

        let labels = detect_runner_settings(&facts).labels;

        let unique: BTreeSet<&String> = labels.iter().collect();
        prop_assert_eq!(unique.len(), labels.len(), "{:?}", labels);
        prop_assert!(!labels.is_empty());
    }

    #[test]
    fn test_describe_labels_property_container_engines_add_no_label(
        facts in host_facts_strategy(),
        engine in select(ENGINE_PROGRAMS.to_vec()),
    ) {
        let with_engine = with_program(&facts, engine);

        let labels = detect_runner_settings(&facts).labels;
        let engine_labels = detect_runner_settings(&with_engine).labels;

        prop_assert_eq!(labels, engine_labels);
    }

    #[test]
    fn test_translate_property_documented_names_get_their_labels(
        (system, system_label) in select(DOCUMENTED_SYSTEMS.to_vec()),
        (processor, processor_label) in select(DOCUMENTED_PROCESSORS.to_vec()),
    ) {
        let facts = HostFacts {
            operating_system: system.to_owned(),
            architecture: processor.to_owned(),
            processor_count: 4,
            programs_found: BTreeSet::new(),
        };

        let labels = detect_runner_settings(&facts).labels;

        prop_assert_eq!(labels, vec![system_label, processor_label]);
    }

    #[test]
    fn test_translate_property_unknown_names_pass_through_unchanged(
        system in any_name(),
        processor in any_name(),
    ) {
        prop_assume!(!TABLE_NAMES.contains(&system.as_str()));
        prop_assume!(!TABLE_NAMES.contains(&processor.as_str()));
        prop_assume!(system != processor);
        let facts = HostFacts {
            operating_system: system.clone(),
            architecture: processor.clone(),
            processor_count: 2,
            programs_found: BTreeSet::new(),
        };

        let labels = detect_runner_settings(&facts).labels;

        prop_assert_eq!(labels, vec![system, processor]);
    }

    #[test]
    fn test_translate_property_each_table_names_only_its_own_field(
        processor_name in select(vec!["aarch64", "x86_64"]),
    ) {
        let facts = HostFacts {
            operating_system: processor_name.to_owned(),
            architecture: "macos".to_owned(),
            processor_count: 2,
            programs_found: BTreeSet::new(),
        };

        let labels = detect_runner_settings(&facts).labels;

        prop_assert_eq!(labels, vec![processor_name, "macos"]);
    }

    #[test]
    fn test_detect_container_sandbox_property_only_engines_matter(
        facts in host_facts_strategy(),
        other in host_facts_strategy(),
    ) {
        let mut engines_of_facts = BTreeSet::new();
        for program in ENGINE_PROGRAMS {
            if facts.programs_found.contains(program) {
                engines_of_facts.insert(program.to_owned());
            }
        }
        let same_engines = HostFacts {
            programs_found: engines_of_facts,
            ..other
        };

        let sandbox = detect_container_sandbox(&facts);
        let same_engine_sandbox = detect_container_sandbox(&same_engines);

        prop_assert_eq!(sandbox, same_engine_sandbox);
    }

    #[test]
    fn test_detect_container_sandbox_property_docker_wins_when_present(
        facts in host_facts_strategy(),
    ) {
        let with_docker = with_program(&facts, DOCKER_PROGRAM);

        let sandbox = detect_container_sandbox(&with_docker);

        let SandboxSettings::Container { engine, .. } = sandbox else {
            return Err(TestCaseError::fail("a container is detected"));
        };
        prop_assert_eq!(engine, ContainerEngineChoice::Docker);
    }

    #[test]
    fn test_detect_container_sandbox_property_the_sandbox_accepts_it(
        facts in host_facts_strategy(),
    ) {
        let sandbox = detect_container_sandbox(&facts);

        let SandboxSettings::Container { image, allowed_hosts, .. } = sandbox
        else {
            return Err(TestCaseError::fail("a container is detected"));
        };
        prop_assert!(ensure_valid_image(&image).is_ok(), "{}", image);
        let unique_hosts: BTreeSet<&String> = allowed_hosts.iter().collect();
        prop_assert_eq!(unique_hosts.len(), allowed_hosts.len());
        for host in &allowed_hosts {
            prop_assert!(is_plain_host_name(host), "{}", host);
        }
    }
}
