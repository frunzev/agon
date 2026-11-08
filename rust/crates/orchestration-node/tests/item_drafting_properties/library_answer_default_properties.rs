use proptest::prelude::*;

use crate::answer_default_cases::{
    agent_access_field, check_an_answered_choice_is_kept,
    check_missing_gives_the_form_default, check_the_default_adds_no_problem,
    skill_improvement_field,
};
use crate::support::drafting_samples::context_strategy;
use crate::support::entity_strategies::secret_text_strategy;

const DEFAULT_CASES: u32 = 32;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DEFAULT_CASES))]

    #[test]
    fn test_pick_form_skill_improvement_property_missing_is_auto(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = skill_improvement_field();
        check_missing_gives_the_form_default(&defaulted, &context, &words)?;
    }

    #[test]
    fn test_pick_form_skill_improvement_property_an_answer_is_kept(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = skill_improvement_field();
        check_an_answered_choice_is_kept(&defaulted, &context, &words)?;
    }

    #[test]
    fn test_pick_form_skill_improvement_property_passes_the_checks(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = skill_improvement_field();
        check_the_default_adds_no_problem(&defaulted, &context, &words)?;
    }

    #[test]
    fn test_pick_form_agent_access_property_missing_pushes_after_approval(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = agent_access_field();
        check_missing_gives_the_form_default(&defaulted, &context, &words)?;
    }

    #[test]
    fn test_pick_form_agent_access_property_read_only_is_kept(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = agent_access_field();
        check_an_answered_choice_is_kept(&defaulted, &context, &words)?;
    }

    #[test]
    fn test_pick_form_agent_access_property_the_default_passes_the_checks(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = agent_access_field();
        check_the_default_adds_no_problem(&defaulted, &context, &words)?;
    }
}
