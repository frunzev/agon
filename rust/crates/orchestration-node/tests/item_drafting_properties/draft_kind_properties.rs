use std::collections::BTreeSet;

use orchestration_node::item_drafting::{
    DraftKind, DraftingContext, parse_item_answer,
};
use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use serde_json::Value;

use crate::prompt_instructions::{ALL_KINDS, render_plain_prompt};
use crate::support::drafting_samples::{context_strategy, kind_strategy};
use crate::support::entity_strategies::secret_text_strategy;

const KIND_CASES: u32 = 48;
const FIRST_LINE_START: &str = "Draft a new ";
const FIRST_LINE_END: &str = ".";
const SENTENCE_END: char = '.';
const NO_JSON_ANSWER: &str = "I could not draft it";
const KIND_NAMES: [&str; 5] = ["task", "job", "project", "skill", "rule"];
const ANY_WORD_PATTERN: &str = "\\PC{0,10}";
const SNAKE_SEPARATOR: char = '_';

fn read_kind_name(
    context: &DraftingContext,
    kind: DraftKind,
) -> Result<String, TestCaseError> {
    let prompt = render_plain_prompt(context, kind, "Any request")?;
    let first_line = prompt.lines().next().unwrap_or_default();
    let name = first_line
        .strip_prefix(FIRST_LINE_START)
        .and_then(|rest| rest.strip_suffix(FIRST_LINE_END))
        .unwrap_or_default();
    Ok(name.to_owned())
}

fn read_explanation(
    context: &DraftingContext,
    kind: DraftKind,
    request: &str,
) -> Result<String, TestCaseError> {
    let prompt = render_plain_prompt(context, kind, request)?;
    let second_line = prompt.lines().nth(1).unwrap_or_default();
    Ok(second_line.to_owned())
}

fn parse_kind(name: &str) -> Option<DraftKind> {
    serde_json::from_value(Value::String(name.to_owned())).ok()
}

fn is_snake_case(name: &str) -> bool {
    let mut has_only_snake_characters = true;
    for character in name.chars() {
        if !character.is_ascii_lowercase() && character != SNAKE_SEPARATOR {
            has_only_snake_characters = false;
        }
    }
    !name.is_empty() && has_only_snake_characters
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(KIND_CASES))]

    #[test]
    fn test_draft_kind_deserialize_property_every_wire_name_reads_back(
        context in context_strategy(),
        kind in kind_strategy(),
    ) {
        let name = read_kind_name(&context, kind)?;

        prop_assert_eq!(parse_kind(&name), Some(kind));
    }

    #[test]
    fn test_draft_kind_deserialize_property_changed_names_are_refused(
        index in 0..KIND_NAMES.len(),
        padding in "[ \t\n]{1,3}",
    ) {
        let name = KIND_NAMES[index];
        let variants = [
            name.to_uppercase(),
            format!("{padding}{name}"),
            format!("{name}{padding}"),
            format!("{name}s"),
        ];

        for variant in variants {
            prop_assert_eq!(parse_kind(&variant), None, "{}", variant);
        }
    }

    #[test]
    fn test_draft_kind_deserialize_property_only_the_five_names_parse(
        word in ANY_WORD_PATTERN,
    ) {
        let parsed = parse_kind(&word);

        prop_assert_eq!(parsed.is_some(), KIND_NAMES.contains(&word.as_str()));
    }

    #[test]
    fn test_draft_kind_name_property_names_are_unique_snake_case(
        context in context_strategy(),
    ) {
        let mut names = BTreeSet::new();
        for kind in ALL_KINDS {
            let name = read_kind_name(&context, kind)?;
            prop_assert!(is_snake_case(&name), "{}", name);
            names.insert(name);
        }

        prop_assert_eq!(names.len(), ALL_KINDS.len());
    }

    #[test]
    fn test_draft_kind_name_property_matches_the_refusal_wording(
        context in context_strategy(),
        kind in kind_strategy(),
    ) {
        let name = read_kind_name(&context, kind)?;

        let refusal = parse_item_answer(kind, NO_JSON_ANSWER)
            .err()
            .map(|error| error.to_string())
            .unwrap_or_default();

        let expected_start =
            format!("the drafting agent did not answer with a {name}: ");
        prop_assert!(refusal.starts_with(&expected_start), "{}", refusal);
    }

    #[test]
    fn test_draft_kind_name_property_is_the_same_for_every_context(
        first_context in context_strategy(),
        second_context in context_strategy(),
        kind in kind_strategy(),
    ) {
        let first_name = read_kind_name(&first_context, kind)?;
        let second_name = read_kind_name(&second_context, kind)?;

        prop_assert_eq!(first_name, second_name);
    }

    #[test]
    fn test_draft_kind_explanation_property_opens_with_its_kind_name(
        context in context_strategy(),
        kind in kind_strategy(),
        request in secret_text_strategy(),
    ) {
        let name = read_kind_name(&context, kind)?;

        let explanation = read_explanation(&context, kind, &request)?;

        let expected_start = format!("A {name} ");
        prop_assert!(explanation.starts_with(&expected_start));
        prop_assert!(explanation.ends_with(SENTENCE_END), "{}", explanation);
    }

    #[test]
    fn test_draft_kind_explanation_property_differs_for_every_kind(
        context in context_strategy(),
        request in secret_text_strategy(),
    ) {
        let mut explanations = BTreeSet::new();
        for kind in ALL_KINDS {
            explanations.insert(read_explanation(&context, kind, &request)?);
        }

        prop_assert_eq!(explanations.len(), ALL_KINDS.len());
    }

    #[test]
    fn test_draft_kind_explanation_property_ignores_context_and_request(
        first_context in context_strategy(),
        second_context in context_strategy(),
        kind in kind_strategy(),
        first_request in secret_text_strategy(),
        second_request in secret_text_strategy(),
    ) {
        let first = read_explanation(&first_context, kind, &first_request)?;
        let second =
            read_explanation(&second_context, kind, &second_request)?;

        prop_assert_eq!(&first, &second);
        prop_assert!(!first.contains(&first_request));
    }
}
