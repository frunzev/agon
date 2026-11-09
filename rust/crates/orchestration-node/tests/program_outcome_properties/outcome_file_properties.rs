use std::fs;
use std::path::Path;
use std::thread;

use proptest::prelude::*;
use tempfile::TempDir;

use crate::program_runs::{
    fail, hold_program_runs, list_outcome_folders, run_script,
};

const PROGRAM_CASES: u32 = 12;
const ARGUMENT_LISTING_SCRIPT: &str = "printf '%s\\0' \"$@\"";
const FOLDER_SCRIPT: &str = "pwd -P";
const PRINTING_SCRIPT: &str = "printf '%s' \"$1\"";
const RAW_BYTES_SCRIPT: &str = "printf '\\377\\376'; printf '\\377' >&2; \
    exit \"$1\"";
const MISSING_FOLDER_NAME: &str = "never-made";
const MOST_ARGUMENTS: usize = 5;
const MOST_PARALLEL_RUNS: usize = 4;
const ARGUMENT_PATTERN: &str = "[^\\x00]{0,20}";
const ARGUMENT_SEPARATOR: char = '\0';
const REPLACEMENT_CHARACTER: char = '\u{fffd}';
const LINE_END: char = '\n';

fn arguments_strategy() -> impl Strategy<Value = Vec<String>> {
    prop::collection::vec(ARGUMENT_PATTERN, 0..MOST_ARGUMENTS)
}

fn read_listed_arguments(output: &str) -> Vec<String> {
    let mut arguments = Vec::new();
    let Some(listing) = output.strip_suffix(ARGUMENT_SEPARATOR) else {
        return arguments;
    };
    for argument in listing.split(ARGUMENT_SEPARATOR) {
        arguments.push(argument.to_owned());
    }
    arguments
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROGRAM_CASES))]

    #[test]
    fn test_run_program_property_unreadable_output_keeps_the_outcome(
        exit_code in 0_i32..=255,
    ) {
        let _held = hold_program_runs();

        let outcome = run_script(
            RAW_BYTES_SCRIPT,
            &[exit_code.to_string()],
            Path::new("/"),
        )
        .map_err(fail)?;

        prop_assert_eq!(outcome.exit_code, exit_code);
        prop_assert!(outcome.output.contains(REPLACEMENT_CHARACTER));
        prop_assert!(outcome.errors.contains(REPLACEMENT_CHARACTER));
    }

    #[test]
    fn test_run_with_outcome_files_property_arguments_arrive_unchanged(
        arguments in arguments_strategy(),
    ) {
        let _held = hold_program_runs();

        let outcome =
            run_script(ARGUMENT_LISTING_SCRIPT, &arguments, Path::new("/"))
                .map_err(fail)?;

        let expected = if arguments.is_empty() {
            vec![String::new()]
        } else {
            arguments
        };
        let listed = read_listed_arguments(&outcome.output);
        prop_assert_eq!(listed, expected);
    }

    #[test]
    fn test_run_with_outcome_files_property_runs_in_the_working_folder(
        folder_name in "[a-z][a-z0-9 ._-]{0,16}",
    ) {
        let _held = hold_program_runs();
        let parent = TempDir::new().map_err(fail)?;
        let working_folder = parent.path().join(folder_name);
        fs::create_dir(&working_folder).map_err(fail)?;

        let outcome = run_script(FOLDER_SCRIPT, &[], &working_folder)
            .map_err(fail)?;

        let expected = working_folder.canonicalize().map_err(fail)?;
        let shown_folder = outcome.output.strip_suffix(LINE_END);
        let expected_folder = expected.to_string_lossy();
        prop_assert_eq!(shown_folder, Some(expected_folder.as_ref()));
    }

    #[test]
    fn test_run_with_outcome_files_property_a_missing_folder_fails(
        output in "[a-z]{1,12}",
    ) {
        let _held = hold_program_runs();
        let parent = TempDir::new().map_err(fail)?;
        let missing_folder = parent.path().join(MISSING_FOLDER_NAME);

        let outcome = run_script(PRINTING_SCRIPT, &[output], &missing_folder);

        prop_assert!(outcome.is_err(), "{:?}", outcome);
    }

    #[test]
    fn test_create_outcome_files_property_leaves_no_folder_behind(
        output in "[a-z]{0,12}",
    ) {
        let _held = hold_program_runs();
        let before = list_outcome_folders()?;

        let outcome = run_script(PRINTING_SCRIPT, &[output], Path::new("/"));

        prop_assert!(outcome.is_ok(), "{:?}", outcome);
        prop_assert_eq!(list_outcome_folders()?, before);
    }

    #[test]
    fn test_create_outcome_files_property_a_failed_start_cleans_up(
        output in "[a-z]{0,12}",
    ) {
        let _held = hold_program_runs();
        let parent = TempDir::new().map_err(fail)?;
        let missing_folder = parent.path().join(MISSING_FOLDER_NAME);
        let before = list_outcome_folders()?;

        let outcome = run_script(PRINTING_SCRIPT, &[output], &missing_folder);

        prop_assert!(outcome.is_err(), "{:?}", outcome);
        prop_assert_eq!(list_outcome_folders()?, before);
    }

    #[test]
    fn test_create_outcome_files_property_parallel_runs_stay_apart(
        outputs in prop::collection::vec("[a-z]{1,12}", 2..MOST_PARALLEL_RUNS),
    ) {
        let _held = hold_program_runs();

        let mut runs = Vec::new();
        for output in &outputs {
            let argument = output.clone();
            runs.push(thread::spawn(move || {
                run_script(PRINTING_SCRIPT, &[argument], Path::new("/"))
            }));
        }
        let mut seen = Vec::new();
        for run in runs {
            let outcome = run.join().map_err(|_| fail("a run panicked"))?;
            seen.push(outcome.map_err(fail)?.output);
        }

        prop_assert_eq!(seen, outputs);
    }
}
