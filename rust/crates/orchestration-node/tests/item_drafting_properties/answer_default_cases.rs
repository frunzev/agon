use orchestration_node::item_drafting::{
    DraftKind, DraftingContext, ItemDraft, check_item_draft, parse_item_answer,
};
use proptest::prop_assert;
use proptest::prop_assert_eq;
use proptest::test_runner::TestCaseError;
use serde_json::{Value, json};

use crate::support::draft_answer_samples::well_formed_answer;
use crate::support::test_device::fail;

#[derive(Debug)]
pub struct DefaultedField {
    kind: DraftKind,
    field: &'static str,
    form_default: Value,
    other_choice: Value,
}

pub fn doer_field() -> DefaultedField {
    DefaultedField {
        kind: DraftKind::Task,
        field: "doer",
        form_default: json!({"kind": "one_agent", "agent": "claude_code"}),
        other_choice: json!({"kind": "one_agent", "agent": "gemini_cli"}),
    }
}

pub fn runner_target_field() -> DefaultedField {
    DefaultedField {
        kind: DraftKind::Job,
        field: "runs_on",
        form_default: json!({"kind": "any_free_runner"}),
        other_choice: json!({"kind": "runner_with_labels", "labels": ["x"]}),
    }
}

pub fn agent_place_field() -> DefaultedField {
    DefaultedField {
        kind: DraftKind::Task,
        field: "agent_place",
        form_default: json!("local_process"),
        other_choice: json!("container"),
    }
}

pub fn automatic_skills_field() -> DefaultedField {
    DefaultedField {
        kind: DraftKind::Job,
        field: "uses_automatic_skills",
        form_default: json!(true),
        other_choice: json!(false),
    }
}

pub fn skill_improvement_field() -> DefaultedField {
    DefaultedField {
        kind: DraftKind::Skill,
        field: "improvement",
        form_default: json!("auto"),
        other_choice: json!("ask_me"),
    }
}

pub fn agent_access_field() -> DefaultedField {
    DefaultedField {
        kind: DraftKind::Project,
        field: "agent_access",
        form_default: json!("push_after_approval"),
        other_choice: json!("read_only"),
    }
}

fn answer_with(
    defaulted: &DefaultedField,
    context: &DraftingContext,
    words: &str,
    choice: Option<&Value>,
) -> Value {
    let mut answer = well_formed_answer(defaulted.kind, context, words);
    if let Some(fields) = answer.as_object_mut() {
        fields.remove(defaulted.field);
        if let Some(chosen) = choice {
            fields.insert(defaulted.field.to_owned(), chosen.clone());
        }
    }
    answer
}

fn parse_answer(
    kind: DraftKind,
    answer: &Value,
) -> Result<ItemDraft, TestCaseError> {
    parse_item_answer(kind, &answer.to_string()).map_err(fail)
}

fn read_parsed_field(
    defaulted: &DefaultedField,
    context: &DraftingContext,
    words: &str,
    choice: Option<&Value>,
) -> Result<Value, TestCaseError> {
    let answer = answer_with(defaulted, context, words, choice);
    let parsed = parse_answer(defaulted.kind, &answer)?;
    let encoded = serde_json::to_value(&parsed).map_err(fail)?;
    Ok(encoded.get(defaulted.field).cloned().unwrap_or(Value::Null))
}

pub fn check_missing_gives_the_form_default(
    defaulted: &DefaultedField,
    context: &DraftingContext,
    words: &str,
) -> Result<(), TestCaseError> {
    let parsed = read_parsed_field(defaulted, context, words, None)?;
    prop_assert_eq!(parsed, defaulted.form_default.clone());
    Ok(())
}

pub fn check_an_answered_choice_is_kept(
    defaulted: &DefaultedField,
    context: &DraftingContext,
    words: &str,
) -> Result<(), TestCaseError> {
    let choice = Some(&defaulted.other_choice);
    let parsed = read_parsed_field(defaulted, context, words, choice)?;
    prop_assert_eq!(parsed, defaulted.other_choice.clone());
    Ok(())
}

pub fn check_the_default_adds_no_problem(
    defaulted: &DefaultedField,
    context: &DraftingContext,
    words: &str,
) -> Result<(), TestCaseError> {
    let missing = answer_with(defaulted, context, words, None);
    let explicit = Some(&defaulted.form_default);
    let answered = answer_with(defaulted, context, words, explicit);

    let missing_draft = parse_answer(defaulted.kind, &missing)?;
    let answered_draft = parse_answer(defaulted.kind, &answered)?;

    prop_assert_eq!(&missing_draft, &answered_draft);
    let missing_check = check_item_draft(context, &missing_draft);
    prop_assert!(
        missing_check.problems.is_empty(),
        "{:?}",
        missing_check.problems
    );
    Ok(())
}
