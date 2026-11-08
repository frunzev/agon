use orchestration_core::naming::validate_name;
use orchestration_node::item_drafting::{
    CheckedDraft, DraftingContext, ItemDraft, RuleDraft, SkillDraft,
    WorkDraft, check_item_draft, parse_item_answer,
};
use proptest::prelude::*;
use serde_json::Value;

use crate::support::draft_answer_samples::well_formed_answer;
use crate::support::drafting_samples::{
    context_strategy, kind_strategy, padded, valid_rule_draft,
    valid_skill_draft, valid_work_draft,
};
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::test_device::fail;

const CHECK_CASES: u32 = 32;
const NAME_LABEL: &str = "Name: ";
const EMPTY_TITLE_START: &str = "What should be done: it is empty.";
const EMPTY_RULE_START: &str = "Rule: it is empty.";
const ANY_NAME_PATTERN: &str = "\\PC{0,45}";
const HUGE_TEXT_PATTERN: &str = "\\PC{2000,4000}";
const BLANK_PATTERN: &str = "[\u{9}-\u{D}\u{20}\u{85}\u{A0}\u{1680}\
                             \u{2000}-\u{200A}\u{2028}\u{2029}\u{202F}\
                             \u{205F}\u{3000}]{0,6}";
const INVISIBLE_PATTERN: &str = "[\u{200B}\u{FEFF}\u{180E}\u{2060}]{1,4}";
const FREE_TEXT_FIELDS: [&str; 5] =
    ["title", "details", "name", "summary", "instructions"];

fn has_problem_starting(problems: &[String], start: &str) -> bool {
    problems.iter().any(|problem| problem.starts_with(start))
}

fn check_task_titled(context: &DraftingContext, title: &str) -> CheckedDraft {
    let task = ItemDraft::Task(valid_work_draft(context, title, "details"));
    check_item_draft(context, &task)
}

fn check_rule_titled(context: &DraftingContext, title: &str) -> CheckedDraft {
    let rule = RuleDraft {
        title: title.to_owned(),
        ..valid_rule_draft(context, "words")
    };
    check_item_draft(context, &ItemDraft::Rule(rule))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_check_item_draft_property_names_follow_validate_name(
        context in context_strategy(),
        name in ANY_NAME_PATTERN,
    ) {
        let skill = valid_skill_draft(&context, &name, "words");
        let trimmed_name = name.trim();

        let checked = check_item_draft(&context, &ItemDraft::Skill(skill));

        let has_name_problem =
            has_problem_starting(&checked.problems, NAME_LABEL);
        let is_valid = validate_name(trimmed_name).is_ok();
        prop_assert_eq!(has_name_problem, !is_valid, "{:?}", name);
        let ItemDraft::Skill(SkillDraft { name: kept, .. }) = &checked.draft
        else {
            return Err(TestCaseError::fail("no skill draft"));
        };
        prop_assert_eq!(kept.as_str(), trimmed_name);
    }

    #[test]
    fn test_check_item_draft_property_white_space_titles_count_as_empty(
        context in context_strategy(),
        blank in BLANK_PATTERN,
        invisible in INVISIBLE_PATTERN,
    ) {
        let invisible_title = format!("{blank}{invisible}{blank}");

        let blank_task = check_task_titled(&context, &blank);
        let blank_rule = check_rule_titled(&context, &blank);
        let shown_task = check_task_titled(&context, &invisible_title);
        let shown_rule = check_rule_titled(&context, &invisible_title);

        let task_problems = &blank_task.problems;
        let rule_problems = &blank_rule.problems;
        prop_assert!(has_problem_starting(task_problems, EMPTY_TITLE_START));
        prop_assert!(has_problem_starting(rule_problems, EMPTY_RULE_START));
        prop_assert!(shown_task.problems.is_empty(), "{:?}", shown_task);
        prop_assert!(shown_rule.problems.is_empty(), "{:?}", shown_rule);
        let ItemDraft::Task(WorkDraft { title, .. }) = &shown_task.draft else {
            return Err(TestCaseError::fail("no task draft"));
        };
        prop_assert_eq!(title, &invisible);
    }

    #[test]
    fn test_check_item_draft_property_checking_twice_changes_nothing(
        context in context_strategy(),
        kind in kind_strategy(),
        words in secret_text_strategy(),
    ) {
        let mut answer = well_formed_answer(kind, &context, &words);
        if let Some(fields) = answer.as_object_mut() {
            for (field_name, field_value) in fields.iter_mut() {
                if !FREE_TEXT_FIELDS.contains(&field_name.as_str()) {
                    continue;
                }
                if let Value::String(text) = field_value {
                    *text = padded(text);
                }
            }
        }
        let drafted =
            parse_item_answer(kind, &answer.to_string()).map_err(fail)?;

        let first = check_item_draft(&context, &drafted);
        let second = check_item_draft(&context, &first.draft);

        prop_assert_eq!(&second, &first);
        let third = check_item_draft(&context, &second.draft);
        prop_assert_eq!(third, second);
    }

    #[test]
    fn test_check_item_draft_property_keeps_huge_unicode_texts_whole(
        context in context_strategy(),
        huge_text in HUGE_TEXT_PATTERN,
    ) {
        let work = valid_work_draft(&context, &huge_text, &huge_text);
        let rule = RuleDraft {
            details: huge_text.clone(),
            ..valid_rule_draft(&context, "words")
        };
        let skill = SkillDraft {
            instructions: huge_text.clone(),
            ..valid_skill_draft(&context, "notes", "words")
        };

        let checked_work = check_item_draft(&context, &ItemDraft::Job(work));
        let checked_rule = check_item_draft(&context, &ItemDraft::Rule(rule));
        let checked_skill =
            check_item_draft(&context, &ItemDraft::Skill(skill));

        let expected = huge_text.trim();
        let ItemDraft::Job(work) = &checked_work.draft else {
            return Err(TestCaseError::fail("no job draft"));
        };
        prop_assert_eq!(work.title.as_str(), expected);
        prop_assert_eq!(work.details.as_str(), expected);
        let ItemDraft::Rule(rule) = &checked_rule.draft else {
            return Err(TestCaseError::fail("no rule draft"));
        };
        prop_assert_eq!(rule.details.as_str(), expected);
        let ItemDraft::Skill(skill) = &checked_skill.draft else {
            return Err(TestCaseError::fail("no skill draft"));
        };
        prop_assert_eq!(skill.instructions.as_str(), expected);
    }
}
