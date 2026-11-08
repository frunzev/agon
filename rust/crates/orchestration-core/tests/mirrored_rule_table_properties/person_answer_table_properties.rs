use orchestration_core::step_outcomes::match_choice;
use proptest::prelude::*;
use serde::Deserialize;

const SHARED_ANSWER_CASES: &str =
    include_str!("../fixtures/person_answer_cases.json");
const SURROUNDING_WHITE_SPACE: &str = "[ \t\r\n\u{a0}\u{2028}\u{3000}]{0,3}";

#[derive(Debug, Deserialize)]
struct SharedAnswerCase {
    answer: String,
    choices: Vec<String>,
    choice: Option<String>,
    is_blank: bool,
}

fn read_shared_cases() -> Result<Vec<SharedAnswerCase>, serde_json::Error> {
    serde_json::from_str(SHARED_ANSWER_CASES)
}

#[test]
fn test_match_choice_property_agrees_with_the_shared_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let choice = match_choice(&case.answer, &case.choices);

        assert_eq!(choice, case.choice, "{:?}", case.answer);
    }
    Ok(())
}

#[test]
fn test_match_choice_property_blank_rows_are_blank_after_trimming()
-> Result<(), serde_json::Error> {
    for case in read_shared_cases()? {
        let is_blank = case.answer.trim().is_empty();

        assert_eq!(is_blank, case.is_blank, "{:?}", case.answer);
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_match_choice_property_shared_table_ignores_padding(
        case_position in any::<prop::sample::Index>(),
        leading_space in SURROUNDING_WHITE_SPACE,
        trailing_space in SURROUNDING_WHITE_SPACE,
    ) {
        let cases = read_shared_cases()?;
        let case = &cases[case_position.index(cases.len())];
        let answer = &case.answer;
        let padded = format!("{leading_space}{answer}{trailing_space}");

        let choice = match_choice(&padded, &case.choices);

        prop_assert_eq!(choice, case.choice.clone());
    }
}
