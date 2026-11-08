use orchestration_node::content_sealing::WorkspaceKeyring;
use orchestration_node::node_error::NodeError;
use orchestration_security::sealing::seal_text;
use proptest::prelude::*;
use proptest::sample::Index;

use crate::sealing_samples::{
    SEALING_CASES, SampleKeys, build_keyring, generate_sample_keys,
    hostile_text_strategy, is_unreadable, tamper_sealed_text,
    workspace_number,
};
use crate::support::test_device::fail;

const MOST_SAMPLE_KEYS: usize = 4;

fn every_position(sample_keys: &SampleKeys) -> Vec<usize> {
    (0..sample_keys.keys.len()).collect()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALING_CASES))]

    #[test]
    fn test_from_keys_property_keeps_the_key_of_every_workspace(
        key_count in 1..MOST_SAMPLE_KEYS,
        text in hostile_text_strategy(),
    ) {
        let sample_keys = generate_sample_keys(key_count).map_err(fail)?;
        let positions = every_position(&sample_keys);
        let keyring = build_keyring(&sample_keys, &positions).map_err(fail)?;

        for (workspace_id, key) in
            sample_keys.workspace_ids.iter().zip(&sample_keys.keys)
        {
            let kept_key = keyring.key_for(*workspace_id).map_err(fail)?;
            prop_assert_eq!(kept_key.to_bytes(), key.to_bytes());
            let sealed_text = seal_text(key, &text).map_err(fail)?;
            let opened_text = keyring.open_text(&sealed_text).map_err(fail)?;
            prop_assert_eq!(&opened_text, &text);
        }
    }

    #[test]
    fn test_from_keys_property_an_empty_keyring_opens_nothing(
        text in hostile_text_strategy(),
    ) {
        let sample_keys = generate_sample_keys(1).map_err(fail)?;
        let sealed_text =
            seal_text(&sample_keys.keys[0], &text).map_err(fail)?;

        let outcome = WorkspaceKeyring::default().open_text(&sealed_text);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_from_keys_property_leaves_out_workspaces_not_given(
        key_count in 2..MOST_SAMPLE_KEYS,
        left_out in any::<Index>(),
    ) {
        let sample_keys = generate_sample_keys(key_count).map_err(fail)?;
        let left_out_position = left_out.index(key_count);
        let mut kept_positions = every_position(&sample_keys);
        kept_positions.retain(|position| *position != left_out_position);

        let keyring = build_keyring(&sample_keys, &kept_positions)
            .map_err(fail)?;

        let left_out_id = sample_keys.workspace_ids[left_out_position];
        let outcome = keyring.key_for(left_out_id);
        let is_missing = matches!(
            outcome,
            Err(NodeError::MissingWorkspaceKey(missing_id))
                if missing_id == left_out_id.0
        );
        prop_assert!(is_missing, "{:?}", outcome);
    }

    #[test]
    fn test_key_for_property_returns_the_key_its_own_texts_open_with(
        key_count in 1..MOST_SAMPLE_KEYS,
        chosen in any::<Index>(),
        text in hostile_text_strategy(),
    ) {
        let sample_keys = generate_sample_keys(key_count).map_err(fail)?;
        let positions = every_position(&sample_keys);
        let keyring = build_keyring(&sample_keys, &positions).map_err(fail)?;
        let workspace_id = sample_keys.workspace_ids[chosen.index(key_count)];

        let workspace_key = keyring.key_for(workspace_id).map_err(fail)?;
        let sealed_text = seal_text(workspace_key, &text).map_err(fail)?;

        prop_assert_eq!(keyring.open_text(&sealed_text).map_err(fail)?, text);
    }

    #[test]
    fn test_key_for_property_unknown_workspace_names_that_workspace(
        number in 100_u128..u128::MAX,
    ) {
        let sample_keys = generate_sample_keys(2).map_err(fail)?;
        let keyring = build_keyring(&sample_keys, &[0, 1]).map_err(fail)?;
        let unknown_id = workspace_number(number);

        let outcome = keyring.key_for(unknown_id);

        let problem = outcome.map(|_| ()).map_err(|error| error.to_string());
        let expected_problem = Err(NodeError::MissingWorkspaceKey(unknown_id.0)
            .to_string());
        prop_assert_eq!(problem, expected_problem);
    }

    #[test]
    fn test_workspace_keyring_open_text_property_more_keys_still_open(
        key_count in 2..MOST_SAMPLE_KEYS,
        text in hostile_text_strategy(),
    ) {
        let sample_keys = generate_sample_keys(key_count).map_err(fail)?;
        let sealed_text =
            seal_text(&sample_keys.keys[0], &text).map_err(fail)?;
        let small_keyring = build_keyring(&sample_keys, &[0]).map_err(fail)?;
        let mut reversed_positions = every_position(&sample_keys);
        reversed_positions.reverse();
        let large_keyring = build_keyring(&sample_keys, &reversed_positions)
            .map_err(fail)?;

        let small_opened =
            small_keyring.open_text(&sealed_text).map_err(fail)?;
        let large_opened =
            large_keyring.open_text(&sealed_text).map_err(fail)?;

        prop_assert_eq!(&small_opened, &text);
        prop_assert_eq!(&large_opened, &text);
    }

    #[test]
    fn test_workspace_keyring_open_text_property_other_keys_cannot_open(
        key_count in 2..MOST_SAMPLE_KEYS,
        sealing_position in any::<Index>(),
        text in hostile_text_strategy(),
    ) {
        let sample_keys = generate_sample_keys(key_count).map_err(fail)?;
        let sealing = sealing_position.index(key_count);
        let sealed_text =
            seal_text(&sample_keys.keys[sealing], &text).map_err(fail)?;
        let mut other_positions = every_position(&sample_keys);
        other_positions.retain(|position| *position != sealing);
        let keyring = build_keyring(&sample_keys, &other_positions)
            .map_err(fail)?;

        let outcome = keyring.open_text(&sealed_text);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_workspace_keyring_open_text_property_detects_tampering(
        text in hostile_text_strategy(),
        position in any::<Index>(),
        shift in any::<u8>(),
        cut in any::<Index>(),
    ) {
        let sample_keys = generate_sample_keys(2).map_err(fail)?;
        let keyring = build_keyring(&sample_keys, &[0, 1]).map_err(fail)?;
        let sealed_text =
            seal_text(&sample_keys.keys[1], &text).map_err(fail)?;
        let tampered_text = tamper_sealed_text(&sealed_text, position, shift);
        let cut_text = &sealed_text[..cut.index(sealed_text.len())];
        let extended_text = format!("{sealed_text}00");

        for broken_text in [tampered_text.as_str(), cut_text, &extended_text] {
            let outcome = keyring.open_text(broken_text);
            prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
        }
    }

    #[test]
    fn test_workspace_keyring_open_text_property_arbitrary_text_is_refused(
        arbitrary_text in any::<String>(),
    ) {
        let sample_keys = generate_sample_keys(2).map_err(fail)?;
        let keyring = build_keyring(&sample_keys, &[0, 1]).map_err(fail)?;

        let outcome = keyring.open_text(&arbitrary_text);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }
}
