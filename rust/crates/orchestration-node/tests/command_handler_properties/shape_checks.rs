use proptest::prelude::*;
use proptest::sample::{Index, select};
use proptest::test_runner::TestCaseError;
use serde_json::Value;

use crate::command_shapes::CommandShape;
use crate::handler_desk::{
    INVALID_ARGUMENTS_START, read_problem, shared_fresh_device,
};

const STRAY_FIELD_PATTERN: &str = "[a-z_]{1,16}";
const COMMAND_FIELD: &str = "command";
const UNKNOWN_COMMAND_START: &str = "unknown command";

pub fn shape_strategy(
    shapes: &'static [CommandShape],
) -> impl Strategy<Value = CommandShape> {
    select(shapes)
}

pub fn stray_field_strategy(
    shape: CommandShape,
) -> impl Strategy<Value = String> {
    STRAY_FIELD_PATTERN.prop_filter(
        "a field the command lacks",
        move |field| {
            let is_known =
                shape.fields.iter().any(|(known, _)| known == field);
            field != COMMAND_FIELD && !is_known
        },
    )
}

fn expected_refusal_start(shape: CommandShape) -> String {
    format!("{INVALID_ARGUMENTS_START} {}:", shape.name)
}

fn run_on_fresh_device(command: &Value) -> Result<String, TestCaseError> {
    let device = shared_fresh_device()?;
    Ok(read_problem(device.run(command)))
}

pub fn dart_command_strategy(
    shapes: &'static [CommandShape],
) -> impl Strategy<Value = Value> {
    let with_absent_options = CommandShape::build_command_with_absent_options;
    prop_oneof![
        select(shapes).prop_map(CommandShape::build_command),
        select(shapes).prop_map(with_absent_options),
    ]
}

pub fn check_dart_command_is_accepted(
    command: &Value,
) -> Result<(), TestCaseError> {
    let problem = run_on_fresh_device(command)?;

    prop_assert!(!problem.starts_with(INVALID_ARGUMENTS_START), "{}", problem);
    prop_assert!(!problem.starts_with(UNKNOWN_COMMAND_START), "{}", problem);
    Ok(())
}

pub fn check_missing_field_is_refused(
    shape: CommandShape,
    chosen: Index,
) -> Result<(), TestCaseError> {
    let required_fields = shape.list_required_fields();
    if required_fields.is_empty() {
        return Ok(());
    }
    let dropped_field = required_fields[chosen.index(required_fields.len())];
    let mut command = shape.build_command();
    if let Some(fields) = command.as_object_mut() {
        fields.remove(dropped_field);
    }

    let problem = run_on_fresh_device(&command)?;

    let missing_text = format!("missing field `{dropped_field}`");
    let expected_start = expected_refusal_start(shape);
    prop_assert!(problem.starts_with(&expected_start), "{}", problem);
    prop_assert!(problem.contains(&missing_text), "{}", problem);
    Ok(())
}

pub fn check_stray_field_is_refused(
    shape: CommandShape,
    stray_field: &str,
    stray_value: Value,
) -> Result<(), TestCaseError> {
    let mut command = shape.build_command();
    command[stray_field] = stray_value;

    let problem = run_on_fresh_device(&command)?;

    let unknown_text = format!("unknown field `{stray_field}`");
    let expected_start = expected_refusal_start(shape);
    prop_assert!(problem.starts_with(&expected_start), "{}", problem);
    prop_assert!(problem.contains(&unknown_text), "{}", problem);
    Ok(())
}

pub fn check_mistyped_field_is_refused(
    shape: CommandShape,
    chosen: Index,
) -> Result<(), TestCaseError> {
    if shape.fields.is_empty() {
        return Ok(());
    }
    let (field, value) = shape.fields[chosen.index(shape.fields.len())];
    let mut command = shape.build_command();
    command[field] = value.build_mistyped();

    let problem = run_on_fresh_device(&command)?;

    let expected_start = expected_refusal_start(shape);
    prop_assert!(problem.starts_with(&expected_start), "{}", problem);
    Ok(())
}
