use orchestration_node::commands::command_names;
use orchestration_node::node_configuration::PeerRelayChoice;
use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use serde_json::json;

use crate::command_device::{BareNode, CommandDevice};
use crate::support::test_device::fail;

pub const NAME_CASES: u32 = 8;
const STRAY_FIELD: &str = "stray_field";
const WORD_SEPARATOR: char = '_';

pub fn select_name(
    names: &'static [&'static str],
) -> impl Strategy<Value = &'static str> {
    proptest::sample::select(names.to_vec())
}

pub fn check_listed_once(name: &str) -> Result<(), TestCaseError> {
    let mut listed_count = 0;
    for listed_name in command_names() {
        if listed_name == name {
            listed_count += 1;
        }
    }
    prop_assert_eq!(listed_count, 1, "{}", name);
    Ok(())
}

pub fn check_reaches_its_parser(name: &str) -> Result<(), TestCaseError> {
    let device = BareNode::open(PeerRelayChoice::Disabled).map_err(fail)?;
    let command = json!({ "command": name, STRAY_FIELD: true });

    let refusal = device.run(&command).err().unwrap_or_default();

    let expected_start = format!("invalid arguments for {name}: ");
    let expected_problem = format!("unknown field `{STRAY_FIELD}`");
    prop_assert!(refusal.starts_with(&expected_start), "{}", refusal);
    prop_assert!(refusal.contains(&expected_problem), "{}", refusal);
    Ok(())
}

pub fn check_spelling(name: &str) -> Result<(), TestCaseError> {
    let device = BareNode::open(PeerRelayChoice::Disabled).map_err(fail)?;
    let shouted_name = name.to_uppercase();
    let dashed_name = name.replace(WORD_SEPARATOR, "-");

    let shouted = device.run(&json!({ "command": shouted_name }));
    let dashed = device.run(&json!({ "command": dashed_name }));

    let has_snake_case_words = name.split(WORD_SEPARATOR).all(|word| {
        !word.is_empty()
            && word.chars().all(|letter| letter.is_ascii_lowercase())
    });
    prop_assert!(has_snake_case_words, "{}", name);
    let shouted_refusal = format!("unknown command: {shouted_name}");
    prop_assert_eq!(shouted, Err(shouted_refusal));
    if dashed_name != name {
        prop_assert_eq!(
            dashed,
            Err(format!("unknown command: {dashed_name}"))
        );
    }
    Ok(())
}
