#![cfg(unix)]

use std::collections::BTreeMap;
use std::env;
use std::path::Path;

use orchestration_node::reaper_safe_program::{ProgramOutcome, run_program};
use proptest::prelude::*;
use proptest::test_runner::TestCaseError;

type ProgramVariables = BTreeMap<String, String>;

const SHELL_PROGRAM: &str = "/bin/sh";
const REPORTING_SCRIPT: &str = "for name in \"$@\"; do \
    printf '%s=%s\\n' \"$name\" \"$(printenv \"$name\")\"; done";
const SCRIPT_NAME: &str = "reporter";
const PRINT_VARIABLE_PROGRAM: &str = "printenv";
const INHERITED_VARIABLE: &str = "PATH";
const VARIABLE_NAME_PATTERN: &str = "AGON_PROBE_[A-Z]{1,8}";
const VARIABLE_VALUE_PATTERN: &str = "[a-zA-Z0-9 \u{e9}\u{4e2d}=:/._-]{0,20}";
const MOST_VARIABLES: usize = 4;
const WORKING_FOLDER: &str = "/";

fn variables_strategy() -> impl Strategy<Value = ProgramVariables> {
    prop::collection::btree_map(
        VARIABLE_NAME_PATTERN,
        VARIABLE_VALUE_PATTERN,
        1..=MOST_VARIABLES,
    )
}

fn fail(problem: impl std::fmt::Display) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

fn list_environment(variables: &ProgramVariables) -> Vec<(&str, String)> {
    let mut environment = Vec::new();
    for (name, value) in variables {
        environment.push((name.as_str(), value.clone()));
    }
    environment
}

fn report_variables(
    names: &[String],
    environment: &[(&str, String)],
) -> Result<ProgramOutcome, TestCaseError> {
    let mut arguments = vec![
        "-c".to_owned(),
        REPORTING_SCRIPT.to_owned(),
        SCRIPT_NAME.to_owned(),
    ];
    arguments.extend_from_slice(names);
    let working_folder = Path::new(WORKING_FOLDER);
    run_program(SHELL_PROGRAM, &arguments, environment, working_folder)
        .map_err(fail)
}

fn describe_report(variables: &ProgramVariables) -> String {
    let mut report_lines = Vec::new();
    for (name, value) in variables {
        report_lines.push(format!("{name}={value}\n"));
    }
    report_lines.concat()
}

proptest! {
    #[test]
    fn test_run_program_property_hands_every_variable_to_the_program(
        variables in variables_strategy(),
    ) {
        let names: Vec<String> = variables.keys().cloned().collect();
        let environment = list_environment(&variables);

        let outcome = report_variables(&names, &environment)?;

        prop_assert!(outcome.has_succeeded(), "{:?}", outcome);
        prop_assert_eq!(outcome.output, describe_report(&variables));
    }

    #[test]
    fn test_run_program_property_given_variables_never_outlive_the_run(
        variables in variables_strategy(),
    ) {
        let names: Vec<String> = variables.keys().cloned().collect();
        let environment = list_environment(&variables);
        report_variables(&names, &environment)?;

        let later_outcome = report_variables(&names, &[])?;

        let mut unset_variables = ProgramVariables::new();
        for name in &names {
            unset_variables.insert(name.clone(), String::new());
        }
        let unset_report = describe_report(&unset_variables);
        prop_assert_eq!(later_outcome.output, unset_report);
    }

    #[test]
    fn test_run_program_property_keeps_the_inherited_environment(
        variables in variables_strategy(),
    ) {
        let environment = list_environment(&variables);
        let arguments = vec![INHERITED_VARIABLE.to_owned()];
        let working_folder = Path::new(WORKING_FOLDER);

        let outcome = run_program(
            PRINT_VARIABLE_PROGRAM,
            &arguments,
            &environment,
            working_folder,
        )
        .map_err(fail)?;

        let inherited_value = env::var(INHERITED_VARIABLE).map_err(fail)?;
        prop_assert!(outcome.has_succeeded(), "{:?}", outcome);
        prop_assert_eq!(outcome.output, format!("{inherited_value}\n"));
    }
}
