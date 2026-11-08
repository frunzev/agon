use orchestration_node::commands::command_names;
use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use serde_json::json;

use crate::command_shapes::CommandShape;
use crate::handler_desk::{
    NO_ACCOUNT_KIND, NO_ACCOUNT_PROBLEM, NOT_A_RUNNER_PROBLEM,
    read_error_kind, read_reply_problem, shared_fresh_device,
};

const NAME_WORD_SEPARATOR: char = '_';
const UNKNOWN_COMMAND_START: &str = "unknown command: ";

#[derive(Clone, Copy, Debug)]
pub enum AreaRefusal {
    NoAccount,
    NotARunner,
}

pub fn check_dart_names_are_known_once(
    shapes: &[CommandShape],
) -> Result<(), TestCaseError> {
    let known_names = command_names();
    for shape in shapes {
        let mut count = 0;
        for known_name in &known_names {
            if *known_name == shape.name {
                count += 1;
            }
        }
        prop_assert_eq!(count, 1, "{}", shape.name);
    }
    Ok(())
}

fn is_snake_case(name: &str) -> bool {
    let mut words = name.split(NAME_WORD_SEPARATOR);
    words.all(|word| {
        !word.is_empty()
            && word.chars().all(|letter| letter.is_ascii_lowercase())
    })
}

pub fn check_names_are_snake_case(
    shapes: &[CommandShape],
) -> Result<(), TestCaseError> {
    for shape in shapes {
        prop_assert!(is_snake_case(shape.name), "{}", shape.name);
    }
    Ok(())
}

pub fn check_name_routes_to_its_area(
    shape: CommandShape,
    refusal: AreaRefusal,
    suffix: &str,
) -> Result<(), TestCaseError> {
    let device = shared_fresh_device()?;
    let mut altered_command = shape.build_command();
    let altered_name = format!("{}{suffix}", shape.name);
    altered_command["command"] = json!(altered_name);

    let reply = device.send(&shape.build_command());
    let altered_reply = device.send(&altered_command);

    let problem = read_reply_problem(&reply);
    match refusal {
        AreaRefusal::NoAccount => {
            prop_assert_eq!(problem, NO_ACCOUNT_PROBLEM);
            prop_assert_eq!(read_error_kind(&reply), Some(NO_ACCOUNT_KIND));
        }
        AreaRefusal::NotARunner => {
            prop_assert_eq!(problem, NOT_A_RUNNER_PROBLEM);
            prop_assert_eq!(read_error_kind(&reply), None);
        }
    }
    let expected_unknown = format!("{UNKNOWN_COMMAND_START}{altered_name}");
    prop_assert_eq!(read_reply_problem(&altered_reply), expected_unknown);
    Ok(())
}
