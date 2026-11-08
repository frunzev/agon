use orchestration_node::commands::command_names;
use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};

use crate::handler_desk::{read_reply_problem, shared_fresh_device};
use crate::support::test_device::is_defined_reply;

const ROUTING_CASES: u32 = 48;
const UNKNOWN_COMMAND_START: &str = "unknown command: ";
const UNKNOWN_VARIANT_TEXT: &str = "unknown variant";
const INVALID_ARGUMENTS_START: &str = "invalid arguments for";
const STRAY_FIELD_PATTERN: &str = "zz_[a-z_]{1,12}";

fn command_name_strategy() -> impl Strategy<Value = &'static str> {
    select(command_names())
}

fn is_snake_case(name: &str) -> bool {
    let starts_with_letter = name
        .chars()
        .next()
        .is_some_and(|first| first.is_ascii_lowercase());
    let has_only_snake_characters = name.chars().all(|character| {
        character.is_ascii_lowercase()
            || character.is_ascii_digit()
            || character == '_'
    });
    let has_empty_word = name.contains("__") || name.ends_with('_');
    starts_with_letter && has_only_snake_characters && !has_empty_word
}

fn misspell(name: &str, spelling: usize) -> String {
    match spelling {
        0 => name.to_uppercase(),
        1 => format!(" {name}"),
        2 => format!("{name} "),
        3 => format!("{name}s"),
        4 => name[..name.len() - 1].to_owned(),
        _ => name.replace('_', "-"),
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ROUTING_CASES))]

    #[test]
    fn test_command_names_property_every_name_is_listed_once(
        name in command_name_strategy(),
    ) {
        let names = command_names();
        let listings = names.iter().filter(|listed| **listed == name).count();
        prop_assert_eq!(listings, 1, "{}", name);
    }

    #[test]
    fn test_command_names_property_every_name_is_snake_case(
        name in command_name_strategy(),
    ) {
        prop_assert!(is_snake_case(name), "{}", name);
    }

    #[test]
    fn test_command_names_property_every_name_reaches_a_parser_knowing_it(
        name in command_name_strategy(),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&json!({ "command": name }));

        let problem = read_reply_problem(&reply);
        prop_assert!(is_defined_reply(&reply), "{}", reply);
        let is_unknown = problem.starts_with(UNKNOWN_COMMAND_START);
        prop_assert!(!is_unknown, "{}", problem);
        prop_assert!(!problem.contains(UNKNOWN_VARIANT_TEXT), "{}", problem);
    }

    #[test]
    fn test_dispatch_command_property_refuses_a_stray_field_on_every_command(
        name in command_name_strategy(),
        stray_field in STRAY_FIELD_PATTERN,
    ) {
        let device = shared_fresh_device()?;

        let command = json!({ "command": name, stray_field.clone(): 1 });
        let reply = device.send(&command);

        let expected_start = format!("{INVALID_ARGUMENTS_START} {name}:");
        let problem = read_reply_problem(&reply);
        prop_assert!(problem.starts_with(&expected_start), "{}", problem);
        prop_assert!(problem.contains(&stray_field), "{}", problem);
    }

    #[test]
    fn test_find_command_area_property_every_listed_name_is_found(
        name in command_name_strategy(),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&json!({ "command": name }));

        let expected_unknown = format!("{UNKNOWN_COMMAND_START}{name}");
        prop_assert_ne!(read_reply_problem(&reply), expected_unknown);
    }

    #[test]
    fn test_find_command_area_property_near_misses_are_unknown(
        name in command_name_strategy(),
        spelling in 0_usize..6,
    ) {
        let misspelled = misspell(name, spelling);
        prop_assume!(!command_names().contains(&misspelled.as_str()));
        let device = shared_fresh_device()?;

        let reply = device.send(&json!({ "command": misspelled }));

        let expected_problem = format!("{UNKNOWN_COMMAND_START}{misspelled}");
        prop_assert_eq!(read_reply_problem(&reply), expected_problem);
    }

    #[test]
    fn test_find_command_area_property_unknown_names_are_echoed_exactly(
        name in any::<String>(),
    ) {
        prop_assume!(!command_names().contains(&name.as_str()));
        let device = shared_fresh_device()?;

        let reply = device.send(&json!({ "command": name }));

        let expected_problem = format!("{UNKNOWN_COMMAND_START}{name}");
        prop_assert_eq!(read_reply_problem(&reply), expected_problem);
        prop_assert_eq!(reply.get("ok"), None::<&Value>);
    }
}
