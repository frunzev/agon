use std::path::Path;
use std::time::{Duration, Instant};

use orchestration_node::reaper_safe_program::ProgramOutcome;
use proptest::prelude::*;

use crate::program_runs::{
    fail, hold_program_runs, run_beside_a_foreign_reaper, run_script,
};

const PROGRAM_CASES: u32 = 12;
const EXIT_SCRIPT: &str = "exit \"$1\"";
const REPORTING_SCRIPT: &str =
    "printf '%s' \"$1\"; printf '%s' \"$2\" >&2; exit \"$3\"";
const SIGNAL_SCRIPT: &str = "kill -s \"$1\" $$";
const SIGNAL_EXIT_BASE: i32 = 128;
const QUICK_END_LIMIT: Duration = Duration::from_secs(10);
const TEXT_PATTERN: &str = "[a-zA-Z0-9 ._-]{0,40}";

fn signal_strategy() -> impl Strategy<Value = (&'static str, i32)> {
    prop::sample::select(vec![("HUP", 1), ("KILL", 9), ("TERM", 15)])
}

fn exit_code_strategy() -> impl Strategy<Value = i32> {
    0_i32..=255
}

fn outcome_strategy() -> impl Strategy<Value = ProgramOutcome> {
    (any::<i32>(), TEXT_PATTERN, TEXT_PATTERN).prop_map(
        |(exit_code, output, errors)| ProgramOutcome {
            exit_code,
            output,
            errors,
        },
    )
}

fn report(output: &str, errors: &str, exit_code: i32) -> Vec<String> {
    vec![output.to_owned(), errors.to_owned(), exit_code.to_string()]
}

proptest! {
    #[test]
    fn test_has_succeeded_property_only_exit_code_zero_succeeds(
        outcome in outcome_strategy(),
    ) {
        prop_assert_eq!(outcome.has_succeeded(), outcome.exit_code == 0);
    }

    #[test]
    fn test_has_succeeded_property_output_and_errors_never_decide(
        outcome in outcome_strategy(),
        other_output in TEXT_PATTERN,
        other_errors in TEXT_PATTERN,
    ) {
        let changed = ProgramOutcome {
            output: other_output,
            errors: other_errors,
            ..outcome.clone()
        };

        prop_assert_eq!(changed.has_succeeded(), outcome.has_succeeded());
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROGRAM_CASES))]

    #[test]
    fn test_has_succeeded_property_agrees_with_the_program_status(
        exit_code in exit_code_strategy(),
    ) {
        let _held = hold_program_runs();

        let outcome = run_script(
            EXIT_SCRIPT,
            &[exit_code.to_string()],
            Path::new("/"),
        )
        .map_err(fail)?;

        prop_assert_eq!(outcome.has_succeeded(), exit_code == 0);
    }

    #[test]
    fn test_wait_for_exit_code_property_reports_every_exit_code(
        exit_code in exit_code_strategy(),
    ) {
        let _held = hold_program_runs();

        let outcome = run_script(
            EXIT_SCRIPT,
            &[exit_code.to_string()],
            Path::new("/"),
        )
        .map_err(fail)?;

        prop_assert_eq!(outcome.exit_code, exit_code);
    }

    #[test]
    fn test_wait_for_exit_code_property_a_signal_ends_with_its_number(
        (signal_name, signal_number) in signal_strategy(),
    ) {
        let _held = hold_program_runs();

        let outcome = run_script(
            SIGNAL_SCRIPT,
            &[signal_name.to_owned()],
            Path::new("/"),
        )
        .map_err(fail)?;

        prop_assert_eq!(outcome.exit_code, SIGNAL_EXIT_BASE + signal_number);
        prop_assert!(!outcome.has_succeeded());
    }

    #[test]
    fn test_wait_for_exit_code_property_answers_soon_after_the_end(
        exit_code in exit_code_strategy(),
    ) {
        let _held = hold_program_runs();
        let started = Instant::now();

        let outcome = run_script(
            EXIT_SCRIPT,
            &[exit_code.to_string()],
            Path::new("/"),
        );

        prop_assert!(outcome.is_ok(), "{:?}", outcome);
        prop_assert!(started.elapsed() < QUICK_END_LIMIT);
    }

    #[test]
    fn test_is_child_already_reaped_property_keeps_the_exit_code(
        exit_code in exit_code_strategy(),
    ) {
        let _held = hold_program_runs();

        let outcome = run_beside_a_foreign_reaper(
            REPORTING_SCRIPT,
            &report("", "", exit_code),
        )?;

        prop_assert_eq!(outcome.exit_code, exit_code);
        prop_assert_eq!(outcome.has_succeeded(), exit_code == 0);
    }

    #[test]
    fn test_is_child_already_reaped_property_keeps_output_and_errors(
        output in TEXT_PATTERN,
        errors in TEXT_PATTERN,
    ) {
        let _held = hold_program_runs();

        let outcome = run_beside_a_foreign_reaper(
            REPORTING_SCRIPT,
            &report(&output, &errors, 0),
        )?;

        prop_assert_eq!(outcome.output, output);
        prop_assert_eq!(outcome.errors, errors);
    }

    #[test]
    fn test_is_child_already_reaped_property_a_signal_still_fails(
        (signal_name, signal_number) in signal_strategy(),
    ) {
        let _held = hold_program_runs();

        let outcome = run_beside_a_foreign_reaper(
            SIGNAL_SCRIPT,
            &[signal_name.to_owned()],
        )?;

        prop_assert_eq!(outcome.exit_code, SIGNAL_EXIT_BASE + signal_number);
        prop_assert!(!outcome.has_succeeded());
    }
}
