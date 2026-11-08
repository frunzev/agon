use orchestration_node::content_sealing::{
    open_chat_message, open_log_line, seal_chat_message, seal_log_line,
};
use proptest::prelude::*;
use proptest::sample::Index;

use crate::sealing_samples::{
    SEALING_CASES, foreign_keyring, hostile_text_strategy,
    is_hex_only_sealed_text, is_unreadable, tamper_sealed_text,
    workspace_number,
};
use crate::support::entity_strategies::{
    sample_chat_message, sample_keyring, sample_log_line,
};
use crate::support::test_device::fail;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALING_CASES))]

    #[test]
    fn test_seal_chat_message_property_hides_hostile_text_behind_hex(
        text in hostile_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(6)).map_err(fail)?;
        let message = sample_chat_message(&text);

        let sealed =
            seal_chat_message(&workspace_key, &message).map_err(fail)?;

        prop_assert!(is_hex_only_sealed_text(&sealed.text));
        let mut expected_message = message.clone();
        expected_message.text.clone_from(&sealed.text);
        prop_assert_eq!(sealed, expected_message);
    }

    #[test]
    fn test_seal_chat_message_property_sealing_twice_never_repeats(
        text in hostile_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(6)).map_err(fail)?;
        let message = sample_chat_message(&text);

        let first = seal_chat_message(&workspace_key, &message).map_err(fail)?;
        let second =
            seal_chat_message(&workspace_key, &message).map_err(fail)?;

        prop_assert_ne!(first.text, second.text);
    }

    #[test]
    fn test_open_chat_message_property_round_trips_hostile_text(
        text in hostile_text_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(6)).map_err(fail)?;
        let message = sample_chat_message(&text);

        let sealed =
            seal_chat_message(&workspace_key, &message).map_err(fail)?;
        let opened = open_chat_message(&keyring, &sealed).map_err(fail)?;

        prop_assert_eq!(opened, message);
    }

    #[test]
    fn test_open_chat_message_property_detects_any_tampered_digit(
        text in hostile_text_strategy(),
        position in any::<Index>(),
        shift in any::<u8>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(6)).map_err(fail)?;
        let mut sealed =
            seal_chat_message(&workspace_key, &sample_chat_message(&text))
                .map_err(fail)?;
        sealed.text = tamper_sealed_text(&sealed.text, position, shift);

        let outcome = open_chat_message(&keyring, &sealed);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_chat_message_property_another_workspace_cannot_open(
        text in hostile_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(6)).map_err(fail)?;
        let other_keyring = foreign_keyring().map_err(fail)?;
        let sealed =
            seal_chat_message(&workspace_key, &sample_chat_message(&text))
                .map_err(fail)?;

        let outcome = open_chat_message(&other_keyring, &sealed);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_seal_log_line_property_hides_hostile_text_behind_hex(
        text in hostile_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(7)).map_err(fail)?;
        let line = sample_log_line(&text);

        let sealed = seal_log_line(&workspace_key, &line).map_err(fail)?;

        prop_assert!(is_hex_only_sealed_text(&sealed.text));
        let mut expected_line = line.clone();
        expected_line.text.clone_from(&sealed.text);
        prop_assert_eq!(sealed, expected_line);
    }

    #[test]
    fn test_seal_log_line_property_sealing_twice_never_repeats(
        text in hostile_text_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(7)).map_err(fail)?;
        let line = sample_log_line(&text);

        let first = seal_log_line(&workspace_key, &line).map_err(fail)?;
        let second = seal_log_line(&workspace_key, &line).map_err(fail)?;

        prop_assert_ne!(first.text, second.text);
    }

    #[test]
    fn test_open_log_line_property_round_trips_hostile_text(
        text in hostile_text_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(7)).map_err(fail)?;
        let line = sample_log_line(&text);

        let sealed = seal_log_line(&workspace_key, &line).map_err(fail)?;
        let opened = open_log_line(&keyring, &sealed).map_err(fail)?;

        prop_assert_eq!(opened, line);
    }

    #[test]
    fn test_open_log_line_property_detects_any_tampered_digit(
        text in hostile_text_strategy(),
        position in any::<Index>(),
        shift in any::<u8>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(7)).map_err(fail)?;
        let mut sealed = seal_log_line(&workspace_key, &sample_log_line(&text))
            .map_err(fail)?;
        sealed.text = tamper_sealed_text(&sealed.text, position, shift);

        let outcome = open_log_line(&keyring, &sealed);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_log_line_property_refuses_plain_unsealed_text(
        text in hostile_text_strategy(),
    ) {
        let (_, keyring) = sample_keyring(workspace_number(7)).map_err(fail)?;

        let outcome = open_log_line(&keyring, &sample_log_line(&text));

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }
}
