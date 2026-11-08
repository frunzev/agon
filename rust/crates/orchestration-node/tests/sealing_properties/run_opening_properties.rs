use orchestration_node::content_sealing::open_run;
use proptest::prelude::*;
use proptest::sample::Index;

use crate::run_sealing_samples::{plain_run_with_steps, seal_whole_run};
use crate::sealing_samples::{
    SEALING_CASES, foreign_keyring, hostile_texts_strategy, is_unreadable,
    tamper_sealed_text, workspace_number,
};
use crate::support::entity_strategies::sample_keyring;
use crate::support::test_device::fail;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALING_CASES))]

    #[test]
    fn test_open_run_property_round_trips_a_whole_hostile_run(
        texts in hostile_texts_strategy(),
        results in hostile_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(8)).map_err(fail)?;
        let run = plain_run_with_steps(&texts, &results);

        let sealed_run = seal_whole_run(&workspace_key, &run).map_err(fail)?;
        let opened_run = open_run(&keyring, &sealed_run).map_err(fail)?;

        prop_assert_eq!(opened_run, run);
    }

    #[test]
    fn test_open_run_property_another_workspace_key_cannot_open(
        texts in hostile_texts_strategy(),
        results in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(8)).map_err(fail)?;
        let other_keyring = foreign_keyring().map_err(fail)?;
        let run = plain_run_with_steps(&texts, &results);

        let sealed_run = seal_whole_run(&workspace_key, &run).map_err(fail)?;
        let outcome = open_run(&other_keyring, &sealed_run);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_run_property_detects_a_tampered_chat_message(
        texts in hostile_texts_strategy(),
        message in any::<Index>(),
        position in any::<Index>(),
        shift in any::<u8>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(8)).map_err(fail)?;
        let run = plain_run_with_steps(&texts, &[]);
        let mut sealed_run =
            seal_whole_run(&workspace_key, &run).map_err(fail)?;
        let message_position = message.index(sealed_run.chat.len());
        let tampered_message = &mut sealed_run.chat[message_position];
        tampered_message.text =
            tamper_sealed_text(&tampered_message.text, position, shift);

        let outcome = open_run(&keyring, &sealed_run);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_step_result_property_detects_a_tampered_earlier_round(
        results in hostile_texts_strategy(),
        step in any::<Index>(),
        position in any::<Index>(),
        shift in any::<u8>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(8)).map_err(fail)?;
        let run = plain_run_with_steps(&[], &results);
        let mut sealed_run =
            seal_whole_run(&workspace_key, &run).map_err(fail)?;
        let step_position = step.index(results.len());
        let round = &mut sealed_run.steps[step_position].earlier_rounds[0];
        let sealed_result = round.result.clone().unwrap_or_default();
        round.result =
            Some(tamper_sealed_text(&sealed_result, position, shift));

        let outcome = open_run(&keyring, &sealed_run);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_step_result_property_keeps_every_step_field(
        results in hostile_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(8)).map_err(fail)?;
        let run = plain_run_with_steps(&[], &results);

        let sealed_run = seal_whole_run(&workspace_key, &run).map_err(fail)?;
        let opened_run = open_run(&keyring, &sealed_run).map_err(fail)?;

        prop_assert_eq!(opened_run.steps.len(), run.steps.len());
        for (opened_step, step) in opened_run.steps.iter().zip(&run.steps) {
            prop_assert_eq!(&opened_step.name, &step.name);
            prop_assert_eq!(opened_step.status, step.status);
            prop_assert_eq!(
                opened_step.earlier_rounds.len(),
                step.earlier_rounds.len()
            );
        }
    }

    #[test]
    fn test_open_step_result_property_refuses_an_unsealed_step_result(
        results in hostile_texts_strategy(),
        step in any::<Index>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(8)).map_err(fail)?;
        let run = plain_run_with_steps(&[], &results);
        let mut sealed_run =
            seal_whole_run(&workspace_key, &run).map_err(fail)?;
        let step_position = step.index(results.len());
        sealed_run.steps[step_position]
            .result
            .clone_from(&run.steps[step_position].result);

        let outcome = open_run(&keyring, &sealed_run);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_optional_text_property_missing_results_stay_missing(
        results in hostile_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(8)).map_err(fail)?;
        let run = plain_run_with_steps(&[], &results);

        let sealed_run = seal_whole_run(&workspace_key, &run).map_err(fail)?;
        let opened_run = open_run(&keyring, &sealed_run).map_err(fail)?;

        let waiting_step = opened_run.steps.last().map(|step| &step.result);
        prop_assert_eq!(waiting_step, Some(&None));
        for opened_step in &opened_run.steps[..results.len()] {
            prop_assert_eq!(&opened_step.earlier_rounds[1].result, &None);
        }
    }

    #[test]
    fn test_open_optional_text_property_present_results_open_exactly(
        results in hostile_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(8)).map_err(fail)?;
        let run = plain_run_with_steps(&[], &results);

        let sealed_run = seal_whole_run(&workspace_key, &run).map_err(fail)?;
        let opened_run = open_run(&keyring, &sealed_run).map_err(fail)?;

        for (opened_step, result) in opened_run.steps.iter().zip(&results) {
            prop_assert_eq!(opened_step.result.as_ref(), Some(result));
            let round_result = opened_step.earlier_rounds[0].result.as_ref();
            prop_assert_eq!(round_result, Some(result));
        }
    }

    #[test]
    fn test_open_optional_text_property_a_tampered_result_is_refused(
        results in hostile_texts_strategy(),
        step in any::<Index>(),
        position in any::<Index>(),
        shift in any::<u8>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(8)).map_err(fail)?;
        let run = plain_run_with_steps(&[], &results);
        let mut sealed_run =
            seal_whole_run(&workspace_key, &run).map_err(fail)?;
        let tampered_step = &mut sealed_run.steps[step.index(results.len())];
        let sealed_result = tampered_step.result.clone().unwrap_or_default();
        tampered_step.result =
            Some(tamper_sealed_text(&sealed_result, position, shift));

        let outcome = open_run(&keyring, &sealed_run);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }
}
