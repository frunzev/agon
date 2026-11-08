use proptest::prelude::*;

use crate::answer_default_cases::{
    agent_place_field, automatic_skills_field,
    check_an_answered_choice_is_kept, check_missing_gives_the_form_default,
    check_the_default_adds_no_problem, doer_field, runner_target_field,
};
use crate::support::drafting_samples::context_strategy;
use crate::support::entity_strategies::secret_text_strategy;

const DEFAULT_CASES: u32 = 32;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(DEFAULT_CASES))]

    #[test]
    fn test_pick_form_doer_property_a_missing_doer_is_claude_code(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        check_missing_gives_the_form_default(&doer_field(), &context, &words)?;
    }

    #[test]
    fn test_pick_form_doer_property_an_answered_doer_is_kept(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        check_an_answered_choice_is_kept(&doer_field(), &context, &words)?;
    }

    #[test]
    fn test_pick_form_doer_property_the_default_passes_the_checks(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        check_the_default_adds_no_problem(&doer_field(), &context, &words)?;
    }

    #[test]
    fn test_pick_form_runner_target_property_missing_is_any_free_runner(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = runner_target_field();
        check_missing_gives_the_form_default(&defaulted, &context, &words)?;
    }

    #[test]
    fn test_pick_form_runner_target_property_an_answered_target_is_kept(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = runner_target_field();
        check_an_answered_choice_is_kept(&defaulted, &context, &words)?;
    }

    #[test]
    fn test_pick_form_runner_target_property_the_default_passes_the_checks(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = runner_target_field();
        check_the_default_adds_no_problem(&defaulted, &context, &words)?;
    }

    #[test]
    fn test_pick_form_agent_place_property_missing_is_a_local_process(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = agent_place_field();
        check_missing_gives_the_form_default(&defaulted, &context, &words)?;
    }

    #[test]
    fn test_pick_form_agent_place_property_an_answered_place_is_kept(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = agent_place_field();
        check_an_answered_choice_is_kept(&defaulted, &context, &words)?;
    }

    #[test]
    fn test_pick_form_agent_place_property_the_default_passes_the_checks(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = agent_place_field();
        check_the_default_adds_no_problem(&defaulted, &context, &words)?;
    }

    #[test]
    fn test_pick_form_automatic_skills_choice_property_missing_is_true(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = automatic_skills_field();
        check_missing_gives_the_form_default(&defaulted, &context, &words)?;
    }

    #[test]
    fn test_pick_form_automatic_skills_choice_property_false_is_kept(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = automatic_skills_field();
        check_an_answered_choice_is_kept(&defaulted, &context, &words)?;
    }

    #[test]
    fn test_pick_form_automatic_skills_choice_property_passes_the_checks(
        context in context_strategy(),
        words in secret_text_strategy(),
    ) {
        let defaulted = automatic_skills_field();
        check_the_default_adds_no_problem(&defaulted, &context, &words)?;
    }
}
