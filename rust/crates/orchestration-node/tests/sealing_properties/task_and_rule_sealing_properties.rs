use orchestration_node::content_sealing::{
    open_rule, open_task, seal_rule, seal_task,
};
use proptest::prelude::*;
use proptest::sample::Index;

use crate::sealing_samples::{
    SEALING_CASES, foreign_keyring, hostile_text_strategy,
    is_hex_only_sealed_text, is_unreadable, tamper_sealed_text,
    workspace_number,
};
use crate::support::entity_strategies::{
    sample_keyring, sample_rule, sample_task,
};
use crate::support::test_device::fail;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALING_CASES))]

    #[test]
    fn test_seal_task_property_hides_hostile_details_behind_hex(
        details in hostile_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(1)).map_err(fail)?;
        let task = sample_task(&details);

        let sealed_task = seal_task(&workspace_key, &task).map_err(fail)?;

        prop_assert!(is_hex_only_sealed_text(&sealed_task.details));
        prop_assert_ne!(&sealed_task.details, &details);
    }

    #[test]
    fn test_seal_task_property_keeps_every_other_field(
        details in hostile_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(1)).map_err(fail)?;
        let task = sample_task(&details);

        let sealed_task = seal_task(&workspace_key, &task).map_err(fail)?;

        let mut expected_task = task.clone();
        expected_task.details.clone_from(&sealed_task.details);
        prop_assert_eq!(sealed_task, expected_task);
    }

    #[test]
    fn test_seal_task_property_two_seals_differ_but_open_alike(
        details in hostile_text_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(1)).map_err(fail)?;
        let task = sample_task(&details);

        let first_seal = seal_task(&workspace_key, &task).map_err(fail)?;
        let second_seal = seal_task(&workspace_key, &task).map_err(fail)?;

        prop_assert_ne!(&first_seal.details, &second_seal.details);
        let first_opened = open_task(&keyring, &first_seal).map_err(fail)?;
        let second_opened = open_task(&keyring, &second_seal).map_err(fail)?;
        prop_assert_eq!(&first_opened, &task);
        prop_assert_eq!(&second_opened, &task);
    }

    #[test]
    fn test_open_task_property_round_trips_hostile_details(
        details in hostile_text_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(1)).map_err(fail)?;
        let task = sample_task(&details);

        let sealed_task = seal_task(&workspace_key, &task).map_err(fail)?;
        let opened_task = open_task(&keyring, &sealed_task).map_err(fail)?;

        prop_assert_eq!(opened_task, task);
    }

    #[test]
    fn test_open_task_property_another_workspace_key_cannot_open(
        details in hostile_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(1)).map_err(fail)?;
        let other_keyring = foreign_keyring().map_err(fail)?;
        let task = sample_task(&details);

        let sealed_task = seal_task(&workspace_key, &task).map_err(fail)?;
        let outcome = open_task(&other_keyring, &sealed_task);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_task_property_detects_any_tampered_digit(
        details in hostile_text_strategy(),
        position in any::<Index>(),
        shift in any::<u8>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(1)).map_err(fail)?;
        let mut sealed_task =
            seal_task(&workspace_key, &sample_task(&details)).map_err(fail)?;
        sealed_task.details =
            tamper_sealed_text(&sealed_task.details, position, shift);

        let outcome = open_task(&keyring, &sealed_task);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_seal_rule_property_hides_hostile_details_behind_hex(
        details in hostile_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(2)).map_err(fail)?;

        let sealed_rule =
            seal_rule(&workspace_key, &sample_rule(&details)).map_err(fail)?;

        prop_assert!(is_hex_only_sealed_text(&sealed_rule.details));
        prop_assert_ne!(&sealed_rule.details, &details);
    }

    #[test]
    fn test_seal_rule_property_keeps_every_other_field(
        details in hostile_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(2)).map_err(fail)?;
        let rule = sample_rule(&details);

        let sealed_rule = seal_rule(&workspace_key, &rule).map_err(fail)?;

        let mut expected_rule = rule.clone();
        expected_rule.details.clone_from(&sealed_rule.details);
        prop_assert_eq!(sealed_rule, expected_rule);
    }

    #[test]
    fn test_seal_rule_property_sealing_twice_never_repeats_ciphertext(
        details in hostile_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(2)).map_err(fail)?;
        let rule = sample_rule(&details);

        let first_seal = seal_rule(&workspace_key, &rule).map_err(fail)?;
        let second_seal = seal_rule(&workspace_key, &rule).map_err(fail)?;

        prop_assert_ne!(first_seal.details, second_seal.details);
    }

    #[test]
    fn test_open_rule_property_round_trips_hostile_details(
        details in hostile_text_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(2)).map_err(fail)?;
        let rule = sample_rule(&details);

        let sealed_rule = seal_rule(&workspace_key, &rule).map_err(fail)?;
        let opened_rule = open_rule(&keyring, &sealed_rule).map_err(fail)?;

        prop_assert_eq!(opened_rule, rule);
    }

    #[test]
    fn test_open_rule_property_another_workspace_key_cannot_open(
        details in hostile_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(2)).map_err(fail)?;
        let other_keyring = foreign_keyring().map_err(fail)?;

        let sealed_rule =
            seal_rule(&workspace_key, &sample_rule(&details)).map_err(fail)?;
        let outcome = open_rule(&other_keyring, &sealed_rule);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_rule_property_refuses_plain_unsealed_details(
        details in hostile_text_strategy(),
    ) {
        let (_, keyring) =
            sample_keyring(workspace_number(2)).map_err(fail)?;

        let outcome = open_rule(&keyring, &sample_rule(&details));

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }
}
