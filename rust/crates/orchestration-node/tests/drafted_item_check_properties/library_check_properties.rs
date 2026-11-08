use orchestration_core::library::{SkillImprovement, SkillUsage};
use orchestration_core::naming::validate_name;
use orchestration_core::rule_titles::validate_rule_title;
use orchestration_core::scope::Scope;
use orchestration_node::item_drafting::{
    ItemDraft, RuleDraft, SkillDraft, check_item_draft,
};
use proptest::prelude::*;

use crate::drafted_item_checks::{
    CHECK_CASES, blank_text_strategy, check_again, check_rule, check_skill,
    count_labelled, is_unicode_blank,
};
use crate::support::drafting_samples::{
    context_strategy, padded, valid_rule_draft, valid_skill_draft,
};
use crate::work_samples::title_strategy;

const NAME_LABEL: &str = "Name";
const SUMMARY_LABEL: &str = "What it does";
const INSTRUCTIONS_LABEL: &str = "Instructions";
const RULE_LABEL: &str = "Rule";
const ANY_NAME_PATTERN: &str = "\\PC{0,48}|[a-z0-9-]{38,43}";
const NAME_FIX: &str = "Ask for changes and give another name.";
const EMPTY_RULE_TITLE: &str = "Rule: it is empty. Ask for changes and say \
                                what agents must follow.";
const DETAILS_PATTERN: &str = "\\PC{0,300}";

fn usage_strategy() -> impl Strategy<Value = SkillUsage> {
    prop_oneof![Just(SkillUsage::Automatic), Just(SkillUsage::WhenChosen)]
}

fn improvement_strategy() -> impl Strategy<Value = SkillImprovement> {
    prop_oneof![
        Just(SkillImprovement::Auto),
        Just(SkillImprovement::AskMe),
        Just(SkillImprovement::Never),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_check_skill_draft_property_problems_follow_the_create_rules(
        context in context_strategy(),
        name in ANY_NAME_PATTERN,
        summary in title_strategy(),
        instructions in title_strategy(),
    ) {
        let skill = SkillDraft {
            name: name.clone(),
            summary: summary.clone(),
            instructions: instructions.clone(),
            ..valid_skill_draft(&context, "notes", "words")
        };

        let (_, problems) = check_skill(&context, &skill)?;

        let trimmed_name = name.trim();
        let is_taken = context
            .skills
            .iter()
            .any(|listed| listed.name == trimmed_name);
        let breaks_rule = validate_name(trimmed_name).is_err();
        let has_name_problem = breaks_rule || is_taken;
        prop_assert_eq!(
            count_labelled(&problems, NAME_LABEL),
            usize::from(has_name_problem)
        );
        prop_assert_eq!(
            count_labelled(&problems, SUMMARY_LABEL),
            usize::from(is_unicode_blank(&summary))
        );
        prop_assert_eq!(
            count_labelled(&problems, INSTRUCTIONS_LABEL),
            usize::from(is_unicode_blank(&instructions))
        );
    }

    #[test]
    fn test_check_skill_draft_property_is_idempotent(
        context in context_strategy(),
        name in ANY_NAME_PATTERN,
        summary in title_strategy(),
    ) {
        let skill = SkillDraft {
            name,
            summary,
            ..valid_skill_draft(&context, "notes", "words")
        };
        let checked = check_item_draft(&context, &ItemDraft::Skill(skill));

        let checked_again = check_again(&context, &checked);

        prop_assert_eq!(checked_again, checked);
    }

    #[test]
    fn test_check_skill_draft_property_keeps_usage_and_improvement(
        context in context_strategy(),
        usage in usage_strategy(),
        improvement in improvement_strategy(),
        is_everywhere in any::<bool>(),
    ) {
        let base = valid_skill_draft(&context, "notes", "words");
        let scope = if is_everywhere {
            Scope::everywhere()
        } else {
            base.scope.clone()
        };
        let skill = SkillDraft {
            usage,
            improvement,
            scope: scope.clone(),
            ..base
        };

        let (checked, problems) = check_skill(&context, &skill)?;

        prop_assert_eq!(checked.usage, usage);
        prop_assert_eq!(checked.improvement, improvement);
        prop_assert_eq!(checked.scope, scope);
        prop_assert!(problems.is_empty(), "{:?}", problems);
    }

    #[test]
    fn test_check_rule_draft_property_title_problem_follows_the_core_rule(
        context in context_strategy(),
        title in title_strategy(),
    ) {
        let rule = RuleDraft {
            title: title.clone(),
            ..valid_rule_draft(&context, "words")
        };

        let (_, problems) = check_rule(&context, &rule)?;

        let expected = if validate_rule_title(&title).is_err() {
            vec![EMPTY_RULE_TITLE.to_owned()]
        } else {
            Vec::new()
        };
        prop_assert_eq!(problems, expected);
    }

    #[test]
    fn test_check_rule_draft_property_is_idempotent(
        context in context_strategy(),
        title in title_strategy(),
        is_everywhere in any::<bool>(),
    ) {
        let base = valid_rule_draft(&context, "words");
        let scope = if is_everywhere {
            Scope::everywhere()
        } else {
            base.scope.clone()
        };
        let rule = RuleDraft { title, scope, ..base };
        let checked = check_item_draft(&context, &ItemDraft::Rule(rule));

        let checked_again = check_again(&context, &checked);

        prop_assert_eq!(checked_again, checked);
    }

    #[test]
    fn test_check_rule_draft_property_details_never_cause_a_problem(
        context in context_strategy(),
        details in prop_oneof![
            blank_text_strategy(),
            DETAILS_PATTERN.prop_map(String::from),
        ],
    ) {
        let rule = RuleDraft {
            details,
            ..valid_rule_draft(&context, "words")
        };

        let (_, problems) = check_rule(&context, &rule)?;

        prop_assert_eq!(count_labelled(&problems, RULE_LABEL), 0);
        prop_assert!(problems.is_empty(), "{:?}", problems);
    }

    #[test]
    fn test_find_skill_name_problem_property_tells_the_name_rule_problem(
        context in context_strategy(),
        name in ANY_NAME_PATTERN,
    ) {
        let mut context = context;
        context.skills.clear();
        let skill = SkillDraft {
            name: name.clone(),
            ..valid_skill_draft(&context, "notes", "words")
        };

        let (_, problems) = check_skill(&context, &skill)?;

        let expected = validate_name(name.trim()).err().map(|problem| {
            format!("Name: {problem}. {NAME_FIX}")
        });
        prop_assert_eq!(problems.into_iter().next(), expected);
    }

    #[test]
    fn test_find_skill_name_problem_property_a_padded_taken_name_is_named(
        context in context_strategy(),
        position in any::<prop::sample::Index>(),
    ) {
        prop_assume!(!context.skills.is_empty());
        let taken = &context.skills[position.index(context.skills.len())];
        let skill = SkillDraft {
            name: padded(&taken.name),
            ..valid_skill_draft(&context, "notes", "words")
        };

        let (checked, problems) = check_skill(&context, &skill)?;

        let expected = format!(
            "Name: a skill named {} already exists. {NAME_FIX}",
            taken.name
        );
        prop_assert_eq!(problems, vec![expected]);
        prop_assert_eq!(&checked.name, &taken.name);
    }

    #[test]
    fn test_find_skill_name_problem_property_a_broken_name_is_never_taken(
        context in context_strategy(),
        position in any::<prop::sample::Index>(),
    ) {
        let mut context = context;
        let broken_name = "Notes Skill".to_owned();
        let listed_position = position.index(context.skills.len().max(1));
        if let Some(listed) = context.skills.get_mut(listed_position) {
            listed.name.clone_from(&broken_name);
        }
        let skill = SkillDraft {
            name: broken_name.clone(),
            ..valid_skill_draft(&context, "notes", "words")
        };

        let (_, problems) = check_skill(&context, &skill)?;

        let rule_problem = validate_name(&broken_name)
            .err()
            .map(|problem| format!("Name: {problem}. {NAME_FIX}"));
        let expected: Vec<String> = rule_problem.into_iter().collect();
        prop_assert_eq!(problems, expected);
    }
}
