use proptest::prelude::*;
use proptest::sample::{Index, select};
use serde_json::{Value, json};

use crate::handler_desk::{
    INVALID_ARGUMENTS_START, NO_ACCOUNT_PROBLEM, read_problem,
    shared_fresh_device,
};

const SAMPLE_IDENTIFIER: &str = "00000000-0000-0000-0000-0000000000b7";
const SAMPLE_DEVICE_IDENTIFIER: &str = "device-sample";
const SAMPLE_TEXT: &str = "sample";
const STRAY_FIELD_PATTERN: &str = "[a-z_]{1,16}";
const COMMAND_FIELD: &str = "command";

#[derive(Clone, Copy, Debug)]
pub enum DartField {
    Identifier,
    DeviceIdentifier,
    Text,
    TaskArguments,
    TaskStart,
    Schedule,
    AgentKind,
    Availability,
    EmptyList,
    Workflow,
}

#[derive(Clone, Copy, Debug)]
pub struct DartShape {
    pub name: &'static str,
    pub fields: &'static [(&'static str, DartField)],
}

impl DartField {
    fn build_sample(self) -> Value {
        match self {
            Self::Identifier => json!(SAMPLE_IDENTIFIER),
            Self::DeviceIdentifier => json!(SAMPLE_DEVICE_IDENTIFIER),
            Self::Text => json!(SAMPLE_TEXT),
            Self::TaskArguments => build_task_arguments(),
            Self::TaskStart => json!("later"),
            Self::Schedule => json!({ "every": "hour", "minute": 5 }),
            Self::AgentKind => json!("codex"),
            Self::Availability => json!({ "kind": "all_workspaces" }),
            Self::EmptyList => json!([]),
            Self::Workflow => json!({
                "id": SAMPLE_IDENTIFIER,
                "name": "release",
                "availability": { "kind": "all_workspaces" },
                "agents": [],
                "connections": [],
                "signature": null,
            }),
        }
    }
}

fn build_task_arguments() -> Value {
    json!({
        "workspace_id": SAMPLE_IDENTIFIER,
        "project_id": SAMPLE_IDENTIFIER,
        "title": "Ship release 2.4",
        "details": SAMPLE_TEXT,
        "doer": { "kind": "one_agent", "agent": "claude_code" },
        "runs_on": { "kind": "any_free_runner" },
        "agent_place": "local_process",
        "skills": [],
        "uses_automatic_skills": true,
        "approval_policy": null,
    })
}

impl DartShape {
    pub fn build_command(self) -> Value {
        let mut command = json!({});
        command[COMMAND_FIELD] = json!(self.name);
        for (field, value) in self.fields {
            command[*field] = value.build_sample();
        }
        command
    }
}

pub fn stray_field_strategy(
    shape: DartShape,
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

pub fn shape_with_stray_field(
    shapes: &'static [DartShape],
) -> impl Strategy<Value = (DartShape, String)> {
    select(shapes)
        .prop_flat_map(|shape| (Just(shape), stray_field_strategy(shape)))
}

fn run_on_fresh_device(command: &Value) -> Result<String, TestCaseError> {
    let device = shared_fresh_device()?;
    Ok(read_problem(device.run(command)))
}

fn expected_refusal_start(shape: DartShape) -> String {
    format!("{INVALID_ARGUMENTS_START} {}:", shape.name)
}

pub fn check_dart_shape_reaches_the_handler(
    shape: DartShape,
) -> Result<(), TestCaseError> {
    let problem = run_on_fresh_device(&shape.build_command())?;

    prop_assert_eq!(problem, NO_ACCOUNT_PROBLEM);
    Ok(())
}

pub fn check_missing_field_is_refused(
    shape: DartShape,
    chosen: Index,
) -> Result<(), TestCaseError> {
    if shape.fields.is_empty() {
        return check_dart_shape_reaches_the_handler(shape);
    }
    let (dropped_field, _) = shape.fields[chosen.index(shape.fields.len())];
    let mut command = shape.build_command();
    if let Some(fields) = command.as_object_mut() {
        fields.remove(dropped_field);
    }

    let problem = run_on_fresh_device(&command)?;

    let missing_text = format!("missing field `{dropped_field}`");
    prop_assert!(
        problem.starts_with(&expected_refusal_start(shape)),
        "{}",
        problem
    );
    prop_assert!(problem.contains(&missing_text), "{}", problem);
    Ok(())
}

pub fn check_stray_field_is_refused(
    shape: DartShape,
    stray_field: &str,
) -> Result<(), TestCaseError> {
    let mut command = shape.build_command();
    command[stray_field] = json!(SAMPLE_TEXT);

    let problem = run_on_fresh_device(&command)?;

    let unknown_text = format!("unknown field `{stray_field}`");
    prop_assert!(
        problem.starts_with(&expected_refusal_start(shape)),
        "{}",
        problem
    );
    prop_assert!(problem.contains(&unknown_text), "{}", problem);
    Ok(())
}
