use proptest::prelude::*;
use serde_json::{Value, json};

use crate::repository_source_desk::{SourceDesk, open_source_desk};
use crate::support::git_origin::LOCAL_REPOSITORY_ADDRESS;
use crate::support::test_device::fail;

const OWN_COPY_CASES: u32 = 1;
const OTHER_ADDRESS_PATTERN: &str = "local\\.test/[a-z]{1,6}/[a-z]{1,6}";
const SEED_FILE: &str = "README.md";
const SEED_TEXT: &str = "hello";
const MAIN_BRANCH: &str = "main";
const HOSTILE_PATHS: [&str; 7] = [
    "../README.md",
    "/etc/passwd",
    "docs/../../README.md",
    ".git/config",
    "..",
    "README.md/../../../etc/passwd",
    "\u{0}README.md",
];

fn ask_own_copy(
    desk: &SourceDesk,
    command: &str,
    place: (&str, &str),
) -> Result<Value, String> {
    let (place_field, place_value) = place;
    let mut question = json!({
        "command": command,
        "project_id": desk.project_id,
        "repository_address": LOCAL_REPOSITORY_ADDRESS,
        "runner_id": desk.read_device_id()?,
        "branch": MAIN_BRANCH,
    });
    question[place_field] = json!(place_value);
    desk.prepared.device.run(&question)
}

fn is_held_here(desk: &SourceDesk) -> Result<bool, String> {
    let source =
        desk.list_branches(&desk.project_id, LOCAL_REPOSITORY_ADDRESS, None)?;
    let device_id = desk.read_device_id()?;
    let is_available = source["kind"] == "available";
    Ok(is_available && source["runner"]["device_id"] == json!(device_id))
}

fn open_desk() -> Result<SourceDesk, TestCaseError> {
    open_source_desk().map_err(fail)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(OWN_COPY_CASES))]

    #[test]
    fn test_holds_own_copy_property_only_the_exact_address_counts(
        other_addresses in prop::collection::vec(OTHER_ADDRESS_PATTERN, 0..3),
        caches_the_project in any::<bool>(),
    ) {
        let desk = open_desk()?;
        for address in &other_addresses {
            desk.cache_a_copy(address).map_err(fail)?;
        }
        if caches_the_project {
            desk.cache_a_copy(LOCAL_REPOSITORY_ADDRESS).map_err(fail)?;
        }

        let is_held = is_held_here(&desk).map_err(fail)?;

        prop_assert_eq!(is_held, caches_the_project);
    }

    #[test]
    fn test_holds_own_copy_property_a_forgotten_copy_is_not_held(
        repeat_count in 1_usize..3,
    ) {
        let desk = open_desk()?;

        for _ in 0..repeat_count {
            desk.cache_a_copy(LOCAL_REPOSITORY_ADDRESS).map_err(fail)?;
            prop_assert!(is_held_here(&desk).map_err(fail)?);
            desk.forget_the_copy(LOCAL_REPOSITORY_ADDRESS).map_err(fail)?;
            prop_assert!(!is_held_here(&desk).map_err(fail)?);
        }
    }

    #[test]
    fn test_holds_own_copy_property_answers_alike_on_every_read(
        read_count in 2_usize..4,
    ) {
        let desk = open_desk()?;
        desk.cache_a_copy(LOCAL_REPOSITORY_ADDRESS).map_err(fail)?;
        let address = LOCAL_REPOSITORY_ADDRESS;

        let first = desk.list_branches(&desk.project_id, address, None);
        for _ in 1..read_count {
            let again = desk.list_branches(&desk.project_id, address, None);
            prop_assert_eq!(&again, &first);
        }
        let branches = first.map_err(fail)?;
        prop_assert_eq!(&branches["branches"], &json!([MAIN_BRANCH]));
    }

    #[test]
    fn test_read_own_copy_property_reads_the_committed_text(
        read_count in 1_usize..3,
    ) {
        let desk = open_desk()?;
        desk.cache_a_copy(LOCAL_REPOSITORY_ADDRESS).map_err(fail)?;

        for _ in 0..read_count {
            let file = ask_own_copy(
                &desk,
                "read_repository_file",
                ("path", SEED_FILE),
            )
            .map_err(fail)?;
            prop_assert_eq!(&file["path"], &json!(SEED_FILE));
            prop_assert_eq!(&file["preview"]["text"], &json!(SEED_TEXT));
        }
    }

    #[test]
    fn test_read_own_copy_property_hostile_paths_stay_inside(
        hostile_path in prop::sample::select(HOSTILE_PATHS.to_vec()),
        command in prop::sample::select(vec![
            ("read_repository_file", "path"),
            ("list_repository_files", "folder"),
        ]),
    ) {
        let desk = open_desk()?;
        desk.cache_a_copy(LOCAL_REPOSITORY_ADDRESS).map_err(fail)?;
        let (command_name, place_field) = command;

        let answer =
            ask_own_copy(&desk, command_name, (place_field, hostile_path));

        prop_assert!(answer.is_err(), "{:?}", answer);
    }

    #[test]
    fn test_read_own_copy_property_a_listing_names_only_inner_entries(
        read_count in 1_usize..3,
    ) {
        let desk = open_desk()?;
        desk.cache_a_copy(LOCAL_REPOSITORY_ADDRESS).map_err(fail)?;

        for _ in 0..read_count {
            let listing = ask_own_copy(
                &desk,
                "list_repository_files",
                ("folder", ""),
            )
            .map_err(fail)?;
            let entries = listing["entries"].as_array().cloned();
            let mut names = Vec::new();
            for entry in entries.unwrap_or_default() {
                let name = entry["name"].as_str().unwrap_or_default();
                names.push(name.to_owned());
            }
            prop_assert_eq!(names, vec![SEED_FILE.to_owned()]);
        }
    }
}
