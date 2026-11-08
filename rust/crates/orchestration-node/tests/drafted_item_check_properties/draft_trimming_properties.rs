use orchestration_node::item_drafting::{
    ItemDraft, RuleDraft, SkillDraft, WorkDraft, check_item_draft,
};
use proptest::prelude::*;

use crate::drafted_item_checks::{
    CHECK_CASES, blank_text_strategy, check_again, check_rule, check_skill,
    check_work, kept_text_strategy, work_wrapper_strategy,
};
use crate::support::drafting_samples::{
    context_strategy, valid_rule_draft, valid_skill_draft, valid_work_draft,
};
use crate::work_samples::title_strategy;

const SKILL_NAME: &str = "notes";

fn padded_text_strategy() -> impl Strategy<Value = (String, String)> {
    (
        blank_text_strategy(),
        kept_text_strategy(),
        blank_text_strategy(),
    )
        .prop_map(|(leading, kept, trailing)| {
            (format!("{leading}{kept}{trailing}"), kept)
        })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_work_draft_trimmed_property_strips_only_unicode_white_space(
        context in context_strategy(),
        wrap in work_wrapper_strategy(),
        (padded_title, title) in padded_text_strategy(),
        (padded_details, details) in padded_text_strategy(),
    ) {
        let work = valid_work_draft(&context, &padded_title, &padded_details);

        let (checked, _) = check_work(&context, &work, wrap)?;

        prop_assert_eq!(checked.title, title);
        prop_assert_eq!(checked.details, details);
    }

    #[test]
    fn test_work_draft_trimmed_property_is_idempotent(
        context in context_strategy(),
        wrap in work_wrapper_strategy(),
        title in title_strategy(),
    ) {
        let work = valid_work_draft(&context, &title, &title);
        let checked = check_item_draft(&context, &wrap(work));

        let checked_again = check_again(&context, &checked);

        prop_assert_eq!(checked_again.draft, checked.draft);
    }

    #[test]
    fn test_work_draft_trimmed_property_keeps_every_other_field(
        context in context_strategy(),
        wrap in work_wrapper_strategy(),
        (padded_title, title) in padded_text_strategy(),
    ) {
        let work = valid_work_draft(&context, &padded_title, "");

        let (checked, _) = check_work(&context, &work, wrap)?;

        let expected = WorkDraft { title, ..work };
        prop_assert_eq!(checked, expected);
    }

    #[test]
    fn test_skill_draft_trimmed_property_strips_only_unicode_white_space(
        context in context_strategy(),
        (padded_summary, summary) in padded_text_strategy(),
        (padded_instructions, instructions) in padded_text_strategy(),
        edges in (blank_text_strategy(), blank_text_strategy()),
    ) {
        let (leading, trailing) = edges;
        let skill = SkillDraft {
            name: format!("{leading}{SKILL_NAME}{trailing}"),
            summary: padded_summary,
            instructions: padded_instructions,
            ..valid_skill_draft(&context, SKILL_NAME, "words")
        };

        let (checked, _) = check_skill(&context, &skill)?;

        prop_assert_eq!(checked.name, SKILL_NAME);
        prop_assert_eq!(checked.summary, summary);
        prop_assert_eq!(checked.instructions, instructions);
    }

    #[test]
    fn test_skill_draft_trimmed_property_is_idempotent(
        context in context_strategy(),
        name in prop_oneof![blank_text_strategy(), kept_text_strategy()],
        (summary, _) in padded_text_strategy(),
    ) {
        let skill = SkillDraft {
            name,
            summary,
            ..valid_skill_draft(&context, SKILL_NAME, "words")
        };
        let checked = check_item_draft(&context, &ItemDraft::Skill(skill));

        let checked_again = check_again(&context, &checked);

        prop_assert_eq!(checked_again, checked);
    }

    #[test]
    fn test_skill_draft_trimmed_property_keeps_every_other_field(
        context in context_strategy(),
        (padded_summary, summary) in padded_text_strategy(),
    ) {
        let skill = SkillDraft {
            summary: padded_summary,
            ..valid_skill_draft(&context, SKILL_NAME, "words")
        };

        let (checked, _) = check_skill(&context, &skill)?;

        let expected = SkillDraft { summary, ..skill };
        prop_assert_eq!(checked, expected);
    }

    #[test]
    fn test_rule_draft_trimmed_property_strips_only_unicode_white_space(
        context in context_strategy(),
        (padded_title, title) in padded_text_strategy(),
        (padded_details, details) in padded_text_strategy(),
    ) {
        let rule = RuleDraft {
            title: padded_title,
            details: padded_details,
            ..valid_rule_draft(&context, "words")
        };

        let (checked, problems) = check_rule(&context, &rule)?;

        prop_assert_eq!(checked.title, title);
        prop_assert_eq!(checked.details, details);
        prop_assert!(problems.is_empty(), "{:?}", problems);
    }

    #[test]
    fn test_rule_draft_trimmed_property_is_idempotent(
        context in context_strategy(),
        title in title_strategy(),
        details in title_strategy(),
    ) {
        let rule = RuleDraft {
            title,
            details,
            ..valid_rule_draft(&context, "words")
        };
        let checked = check_item_draft(&context, &ItemDraft::Rule(rule));

        let checked_again = check_again(&context, &checked);

        prop_assert_eq!(checked_again, checked);
    }

    #[test]
    fn test_rule_draft_trimmed_property_keeps_the_scope(
        context in context_strategy(),
        (padded_title, title) in padded_text_strategy(),
    ) {
        let rule = RuleDraft {
            title: padded_title,
            ..valid_rule_draft(&context, "words")
        };

        let (checked, _) = check_rule(&context, &rule)?;

        let expected = RuleDraft { title, ..rule };
        prop_assert_eq!(checked, expected);
    }
}
