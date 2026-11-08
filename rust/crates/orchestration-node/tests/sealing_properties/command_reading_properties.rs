use orchestration_node::commands::command_names;
use proptest::prelude::*;
use proptest::sample::select;
use serde_json::{Value, json};

use crate::handler_desk::{read_reply_problem, shared_fresh_device};
use crate::support::test_device::{fail, is_defined_reply};

const READING_CASES: u32 = 48;
const INVALID_COMMAND_START: &str =
    "a command must be a JSON object with a command name:";
const MISSING_NAME_PROBLEM: &str = "the command field is missing or not text";
const INVALID_ARGUMENTS_START: &str = "invalid arguments for";
const WORKSPACE_COMMANDS: [&str; 5] = [
    "list_projects",
    "list_workflows",
    "list_tasks",
    "list_skills",
    "list_rules",
];

fn missing_name_problem() -> String {
    format!("{INVALID_COMMAND_START} {MISSING_NAME_PROBLEM}")
}

fn non_text_value_strategy() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(Value::Null),
        any::<bool>().prop_map(Value::Bool),
        any::<i64>().prop_map(|number| json!(number)),
        any::<String>().prop_map(|text| json!([text])),
        any::<String>().prop_map(|text| json!({ "name": text })),
    ]
}

fn wrong_type_value_strategy() -> impl Strategy<Value = Value> {
    prop_oneof![
        Just(Value::Null),
        any::<bool>().prop_map(Value::Bool),
        any::<i64>().prop_map(|number| json!(number)),
        "[a-z ]{0,12}".prop_map(Value::String),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(READING_CASES))]

    #[test]
    fn test_read_command_name_property_a_missing_name_is_refused(
        field_name in "[a-z_]{1,12}",
        field_value in any::<String>(),
    ) {
        prop_assume!(field_name != "command");
        let device = shared_fresh_device()?;

        let reply = device.send(&json!({ field_name: field_value }));

        prop_assert_eq!(read_reply_problem(&reply), missing_name_problem());
    }

    #[test]
    fn test_read_command_name_property_a_non_text_name_is_refused(
        name_value in non_text_value_strategy(),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&json!({ "command": name_value }));

        prop_assert_eq!(read_reply_problem(&reply), missing_name_problem());
    }

    #[test]
    fn test_read_command_name_property_only_the_exact_field_name_counts(
        name in select(command_names()),
        spelling in prop_oneof![
            Just("Command"),
            Just("COMMAND"),
            Just(" command"),
            Just("commands"),
        ],
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&json!({ spelling: name }));

        prop_assert_eq!(read_reply_problem(&reply), missing_name_problem());
    }

    #[test]
    fn test_parse_command_property_a_wrong_argument_type_names_the_command(
        name in select(WORKSPACE_COMMANDS.to_vec()),
        wrong_value in wrong_type_value_strategy(),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&json!({
            "command": name,
            "workspace_id": wrong_value,
        }));

        let expected_start = format!("{INVALID_ARGUMENTS_START} {name}:");
        let problem = read_reply_problem(&reply);
        prop_assert!(problem.starts_with(&expected_start), "{}", problem);
    }

    #[test]
    fn test_parse_command_property_a_missing_argument_names_the_field(
        name in select(WORKSPACE_COMMANDS.to_vec()),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&json!({ "command": name }));

        let problem = read_reply_problem(&reply);
        let expected_start = format!("{INVALID_ARGUMENTS_START} {name}:");
        prop_assert!(problem.starts_with(&expected_start), "{}", problem);
        prop_assert!(problem.contains("workspace_id"), "{}", problem);
    }

    #[test]
    fn test_parse_command_property_the_command_field_is_not_a_stray_field(
        name in select(command_names()),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&json!({ "command": name }));

        let problem = read_reply_problem(&reply);
        prop_assert!(!problem.contains("unknown field"), "{}", problem);
    }

    #[test]
    fn test_run_command_property_text_that_is_not_json_is_refused(
        broken_text in "[^\\[{\"0-9tfn \t\n\r-][^\n]{0,40}",
    ) {
        let device = shared_fresh_device()?;

        let reply_text = device.runtime.handle_command(&broken_text);

        let reply: Value = serde_json::from_str(&reply_text).map_err(fail)?;
        prop_assert!(is_defined_reply(&reply), "{}", reply);
        let problem = read_reply_problem(&reply);
        let is_invalid_command = problem.starts_with(INVALID_COMMAND_START);
        prop_assert!(is_invalid_command, "{}", problem);
    }

    #[test]
    fn test_run_command_property_json_that_is_not_an_object_is_refused(
        value in prop_oneof![
            any::<i64>().prop_map(|number| json!(number)),
            any::<String>().prop_map(Value::String),
            any::<String>().prop_map(|text| json!([{ "command": text }])),
        ],
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&value);

        prop_assert_eq!(read_reply_problem(&reply), missing_name_problem());
    }
}
