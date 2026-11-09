use std::collections::BTreeSet;
use std::env;
use std::ops::RangeInclusive;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use std::thread;

use orchestration_node::runner_bridge::read_host_facts;
use proptest::prelude::*;

const SEARCH_PATH_VARIABLE: &str = "PATH";
const PROBED_PROGRAMS: [&str; 3] = ["xcodebuild", "docker", "podman"];
const ANY_EXECUTE_BITS: u32 = 0o111;
const READ_COUNT_RANGE: RangeInclusive<usize> = 2..=4;
const FACT_CASES: u32 = 4;

fn is_executable_file(path: &Path) -> bool {
    let Ok(metadata) = path.metadata() else {
        return false;
    };
    metadata.is_file() && metadata.permissions().mode() & ANY_EXECUTE_BITS != 0
}

fn find_programs_on_search_path() -> BTreeSet<String> {
    let mut found = BTreeSet::new();
    let Some(search_path) = env::var_os(SEARCH_PATH_VARIABLE) else {
        return found;
    };
    for folder in env::split_paths(&search_path) {
        for program in PROBED_PROGRAMS {
            if is_executable_file(&folder.join(program)) {
                found.insert(program.to_owned());
            }
        }
    }
    found
}

fn count_usable_processors() -> usize {
    thread::available_parallelism().map_or(1, std::num::NonZero::get)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FACT_CASES))]

    #[test]
    fn test_read_host_facts_property_names_this_build_target(
        read_count in READ_COUNT_RANGE,
    ) {
        for _ in 0..read_count {
            let facts = read_host_facts();

            prop_assert_eq!(facts.operating_system, env::consts::OS);
            prop_assert_eq!(facts.architecture, env::consts::ARCH);
        }
    }

    #[test]
    fn test_read_host_facts_property_counts_usable_processors(
        read_count in READ_COUNT_RANGE,
    ) {
        for _ in 0..read_count {
            let facts = read_host_facts();

            prop_assert!(facts.processor_count >= 1);
            prop_assert_eq!(facts.processor_count, count_usable_processors());
        }
    }

    #[test]
    fn test_read_host_facts_property_finds_exactly_the_path_programs(
        read_count in READ_COUNT_RANGE,
    ) {
        let expected = find_programs_on_search_path();

        for _ in 0..read_count {
            let facts = read_host_facts();

            prop_assert_eq!(&facts.programs_found, &expected);
        }
    }
}
