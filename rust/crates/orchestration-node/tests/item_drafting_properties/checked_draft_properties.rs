use orchestration_node::item_drafting::{
    CheckedDraft, DraftKind, ItemDraft, ProjectDraft, RuleDraft, SkillDraft,
    WorkDraft, parse_item_answer,
};
use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use serde_json::Value;

use crate::support::draft_answer_samples::well_formed_answer;
use crate::support::drafting_samples::{
    context_strategy, describe_kind, kind_of, kind_strategy,
};
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::test_device::fail;

const SERIALIZE_CASES: u32 = 48;
const KIND_FIELD: &str = "kind";
const DRAFT_FIELD: &str = "draft";
const PROBLEMS_FIELD: &str = "problems";
const PROBLEM_PATTERN: &str = "\\PC{0,40}";
const MOST_PROBLEMS: usize = 5;

fn checked_draft_strategy() -> impl Strategy<Value = CheckedDraft> {
    (
        context_strategy(),
        kind_strategy(),
        secret_text_strategy(),
        proptest::collection::vec(PROBLEM_PATTERN, 0..MOST_PROBLEMS),
    )
        .prop_filter_map(
            "a parsed answer",
            |(context, kind, words, problems)| {
                let answer = well_formed_answer(kind, &context, &words);
                let draft =
                    parse_item_answer(kind, &answer.to_string()).ok()?;
                Some(CheckedDraft { draft, problems })
            },
        )
}

fn encode(checked: &CheckedDraft) -> Result<Value, TestCaseError> {
    serde_json::to_value(checked).map_err(fail)
}

fn decode_fields(
    kind: DraftKind,
    fields: Value,
) -> Result<ItemDraft, TestCaseError> {
    let decoded = match kind {
        DraftKind::Task => ItemDraft::Task(
            serde_json::from_value::<WorkDraft>(fields).map_err(fail)?,
        ),
        DraftKind::Job => ItemDraft::Job(
            serde_json::from_value::<WorkDraft>(fields).map_err(fail)?,
        ),
        DraftKind::Project => ItemDraft::Project(
            serde_json::from_value::<ProjectDraft>(fields).map_err(fail)?,
        ),
        DraftKind::Skill => ItemDraft::Skill(
            serde_json::from_value::<SkillDraft>(fields).map_err(fail)?,
        ),
        DraftKind::Rule => ItemDraft::Rule(
            serde_json::from_value::<RuleDraft>(fields).map_err(fail)?,
        ),
    };
    Ok(decoded)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SERIALIZE_CASES))]

    #[test]
    fn test_checked_draft_serialize_property_holds_draft_and_problems_only(
        checked in checked_draft_strategy(),
    ) {
        let encoded = encode(&checked)?;

        let fields = encoded.as_object().cloned().unwrap_or_default();
        let mut keys: Vec<&String> = fields.keys().collect();
        keys.sort();
        prop_assert_eq!(keys, vec![DRAFT_FIELD, PROBLEMS_FIELD]);
        let problems: Vec<String> =
            serde_json::from_value(fields[PROBLEMS_FIELD].clone())
                .map_err(fail)?;
        prop_assert_eq!(problems, checked.problems);
    }

    #[test]
    fn test_checked_draft_serialize_property_names_the_kind_of_its_draft(
        checked in checked_draft_strategy(),
    ) {
        let encoded = encode(&checked)?;

        let kind_name = encoded[DRAFT_FIELD][KIND_FIELD].as_str();
        let expected = describe_kind(kind_of(&checked.draft));
        prop_assert_eq!(kind_name, Some(expected));
    }

    #[test]
    fn test_checked_draft_serialize_property_draft_fields_read_back(
        checked in checked_draft_strategy(),
    ) {
        let encoded = encode(&checked)?;

        let mut fields = encoded[DRAFT_FIELD].clone();
        if let Some(object) = fields.as_object_mut() {
            object.remove(KIND_FIELD);
        }
        let decoded = decode_fields(kind_of(&checked.draft), fields)?;

        prop_assert_eq!(decoded, checked.draft);
    }
}
