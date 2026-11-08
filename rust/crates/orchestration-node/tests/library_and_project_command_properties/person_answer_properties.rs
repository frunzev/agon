use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::json;

use crate::person_step_desk::{
    ASK_STEP_NAME, answer_step, find_open_step, list_open_steps,
    start_question_run, wait_for_open_step,
};
use crate::support::folder_checks::prepared_or_panic;
use crate::support::test_device::fail;

const ANSWER_CASES: u32 = 3;
const MOST_RUNS: usize = 3;
const QUESTION_PATTERN: &str = "[A-Z][a-z]{1,8}( [a-z]{1,8}){0,4}\\?";
const BLANK_PATTERN: &str = "[ \t\n]{0,4}";
const APPROVAL_WORDS: [&str; 2] = ["approve", "approved"];
const UNMATCHED_START: &str = "the answer names none of the choices: ";
const FIRST_CHOICE: &str = "shipped";
const SECOND_CHOICE: &str = "again";

fn two_choices() -> Vec<String> {
    vec![FIRST_CHOICE.to_owned(), SECOND_CHOICE.to_owned()]
}

fn spelling_strategy() -> impl Strategy<Value = String> {
    (any::<bool>(), "[ ]{0,2}", "[ ]{0,2}").prop_map(
        |(is_shouted, before, after)| {
            let spelled = if is_shouted {
                FIRST_CHOICE.to_uppercase()
            } else {
                FIRST_CHOICE.to_owned()
            };
            format!("{before}{spelled}{after}")
        },
    )
}

#[test]
fn test_list_open_person_steps_property_questions_are_opened() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(ANSWER_CASES));

    let outcome = runner.run(&QUESTION_PATTERN, |question| {
        let run_id = start_question_run(&prepared, &question, &two_choices())
            .map_err(fail)?;
        let open_step =
            wait_for_open_step(&prepared, &run_id).map_err(fail)?;

        prop_assert_eq!(&open_step["question"], &json!(question));
        prop_assert_eq!(&open_step["step_name"], &json!(ASK_STEP_NAME));
        prop_assert_eq!(&open_step["choices"], &json!(two_choices()));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_list_open_person_steps_property_each_run_lists_one_question() {
    let mut runner = TestRunner::new(Config::with_cases(ANSWER_CASES));
    let questions = vec(QUESTION_PATTERN, 1..=MOST_RUNS);

    let outcome = runner.run(&questions, |questions| {
        let prepared = prepared_or_panic();
        let mut run_ids = Vec::new();
        for question in &questions {
            let run_id =
                start_question_run(&prepared, question, &[]).map_err(fail)?;
            wait_for_open_step(&prepared, &run_id).map_err(fail)?;
            run_ids.push(run_id);
        }
        let steps = list_open_steps(&prepared).map_err(fail)?;

        prop_assert_eq!(steps.len(), run_ids.len());
        for (index, run_id) in run_ids.iter().enumerate() {
            let open_step = find_open_step(&steps, run_id);
            let question = open_step.map(|step| step["question"].clone());
            prop_assert_eq!(question, Some(json!(questions[index])));
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_list_open_person_steps_property_an_answered_step_closes() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(ANSWER_CASES));

    let outcome = runner.run(&QUESTION_PATTERN, |question| {
        let run_id = start_question_run(&prepared, &question, &two_choices())
            .map_err(fail)?;
        wait_for_open_step(&prepared, &run_id).map_err(fail)?;
        answer_step(&prepared, &run_id, ASK_STEP_NAME, FIRST_CHOICE)
            .map_err(fail)?;
        let steps = list_open_steps(&prepared).map_err(fail)?;

        prop_assert!(find_open_step(&steps, &run_id).is_none(), "{:?}", steps);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_answer_person_step_property_a_blank_answer_keeps_the_step_open() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(ANSWER_CASES));

    let outcome = runner.run(&BLANK_PATTERN, |blank| {
        let run_id = start_question_run(&prepared, "Ship?", &two_choices())
            .map_err(fail)?;
        wait_for_open_step(&prepared, &run_id).map_err(fail)?;
        let refused = answer_step(&prepared, &run_id, ASK_STEP_NAME, &blank);
        let steps = list_open_steps(&prepared).map_err(fail)?;

        let expected = "the answer cannot be empty".to_owned();
        prop_assert_eq!(refused, Err(expected));
        prop_assert!(find_open_step(&steps, &run_id).is_some());
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_answer_person_step_property_an_unknown_step_is_not_found() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(ANSWER_CASES));

    let outcome = runner.run(&"[a-z]{3,10}", |step_name| {
        prop_assume!(step_name != ASK_STEP_NAME);
        let run_id = start_question_run(&prepared, "Ship?", &two_choices())
            .map_err(fail)?;
        wait_for_open_step(&prepared, &run_id).map_err(fail)?;
        let refused =
            answer_step(&prepared, &run_id, &step_name, FIRST_CHOICE);

        let expected = format!("open person step {step_name} was not found");
        prop_assert_eq!(refused, Err(expected));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_answer_person_step_property_any_spelling_of_a_choice_is_taken() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(ANSWER_CASES));

    let outcome = runner.run(&spelling_strategy(), |spelled_answer| {
        let run_id = start_question_run(&prepared, "Ship?", &two_choices())
            .map_err(fail)?;
        wait_for_open_step(&prepared, &run_id).map_err(fail)?;
        let answered =
            answer_step(&prepared, &run_id, ASK_STEP_NAME, &spelled_answer)
                .map_err(fail)?;

        prop_assert_eq!(&answered["id"], &json!(run_id));
        let again =
            answer_step(&prepared, &run_id, ASK_STEP_NAME, &spelled_answer);
        prop_assert!(again.is_err(), "{:?}", again);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_choose_answer_property_an_unmatched_answer_lists_the_choices() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(ANSWER_CASES));

    let outcome = runner.run(&"[a-z]{3,10}", |answer| {
        prop_assume!(answer != FIRST_CHOICE && answer != SECOND_CHOICE);
        prop_assume!(!APPROVAL_WORDS.contains(&answer.as_str()));
        let run_id = start_question_run(&prepared, "Ship?", &two_choices())
            .map_err(fail)?;
        wait_for_open_step(&prepared, &run_id).map_err(fail)?;
        let refused = answer_step(&prepared, &run_id, ASK_STEP_NAME, &answer);
        let steps = list_open_steps(&prepared).map_err(fail)?;

        let expected =
            format!("{UNMATCHED_START}{FIRST_CHOICE}, {SECOND_CHOICE}");
        prop_assert_eq!(refused, Err(expected));
        prop_assert!(find_open_step(&steps, &run_id).is_some());
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_choose_answer_property_without_choices_any_words_are_taken() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(ANSWER_CASES));

    let outcome = runner.run(&"[A-Za-z][a-z ]{0,30}", |answer| {
        let run_id =
            start_question_run(&prepared, "Ship?", &[]).map_err(fail)?;
        let open_step =
            wait_for_open_step(&prepared, &run_id).map_err(fail)?;
        let answered = answer_step(&prepared, &run_id, ASK_STEP_NAME, &answer);

        prop_assert_eq!(&open_step["choices"], &json!([]));
        prop_assert!(answered.is_ok(), "{:?}", answered);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_choose_answer_property_the_second_choice_is_not_mistaken() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(ANSWER_CASES));

    let outcome = runner.run(&any::<bool>(), |is_shouted| {
        let run_id = start_question_run(&prepared, "Ship?", &two_choices())
            .map_err(fail)?;
        wait_for_open_step(&prepared, &run_id).map_err(fail)?;
        let answer = if is_shouted {
            SECOND_CHOICE.to_uppercase()
        } else {
            SECOND_CHOICE.to_owned()
        };
        let answered = answer_step(&prepared, &run_id, ASK_STEP_NAME, &answer)
            .map_err(fail)?;

        let steps = answered["steps"].as_array().cloned().unwrap_or_default();
        let ask_step = steps
            .iter()
            .find(|step| step["name"] == json!(ASK_STEP_NAME))
            .cloned()
            .unwrap_or_default();
        let shown = ask_step.to_string();
        prop_assert!(shown.contains(SECOND_CHOICE), "{}", shown);
        prop_assert!(!shown.contains(FIRST_CHOICE), "{}", shown);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
