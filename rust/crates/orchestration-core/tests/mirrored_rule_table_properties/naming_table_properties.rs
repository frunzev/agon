use orchestration_core::naming::{
    MAXIMUM_NAME_LENGTH, NameProblem, convert_to_project_name, validate_name,
};
use proptest::prelude::*;
use serde::Deserialize;

const SHARED_NAMING_CASES: &str =
    include_str!("../fixtures/naming_cases.json");
const EMPTY_PROBLEM: &str = "empty";
const INVALID_CHARACTER_PROBLEM: &str = "invalid_character";
const TOO_LONG_PROBLEM: &str = "too_long";

#[derive(Debug, Deserialize)]
struct SharedNamingCase {
    name: String,
    problem: Option<String>,
    project_name: String,
}

fn read_shared_cases() -> Result<Vec<SharedNamingCase>, serde_json::Error> {
    serde_json::from_str(SHARED_NAMING_CASES)
}

fn name_problem_kind(name: &str) -> Option<&'static str> {
    match validate_name(name) {
        Ok(()) => None,
        Err(NameProblem::Empty) => Some(EMPTY_PROBLEM),
        Err(NameProblem::InvalidCharacter { .. }) => {
            Some(INVALID_CHARACTER_PROBLEM)
        }
        Err(NameProblem::TooLong { .. }) => Some(TOO_LONG_PROBLEM),
    }
}

#[test]
fn test_validate_name_property_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let problem = name_problem_kind(&case.name);

        assert_eq!(problem, case.problem.as_deref(), "{:?}", case.name);
    }
    Ok(())
}

#[test]
fn test_convert_to_project_name_property_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let project_name = convert_to_project_name(&case.name);

        assert_eq!(project_name, case.project_name, "{:?}", case.name);
    }
    Ok(())
}

#[test]
fn test_convert_to_project_name_property_shared_answers_are_valid_names()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let problem = name_problem_kind(&case.project_name);
        let converted_again = convert_to_project_name(&case.project_name);

        assert_eq!(problem, None, "{:?}", case.project_name);
        assert_eq!(converted_again, case.project_name);
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_validate_name_property_character_problem_beats_length(
        name in "[a-z0-9-]{41,60}",
        position in any::<prop::sample::Index>(),
    ) {
        let cut = position.index(name.len());
        let spoiled = format!("{}A{}", &name[..cut], &name[cut..]);

        let problem = name_problem_kind(&spoiled);

        prop_assert!(spoiled.len() > MAXIMUM_NAME_LENGTH);
        prop_assert_eq!(problem, Some(INVALID_CHARACTER_PROBLEM));
    }
}
