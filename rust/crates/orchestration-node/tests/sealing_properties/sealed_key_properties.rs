use orchestration_api::accounts::SealedWorkspaceKey;
use orchestration_node::content_sealing::{
    WorkspaceKeyring, seal_workspace_key,
};
use orchestration_node::node_error::NodeError;
use orchestration_security::error::SecurityError;
use orchestration_security::identity::DeviceIdentity;
use orchestration_security::sealing::{open_sealed, seal_for, seal_text};
use proptest::prelude::*;
use proptest::sample::Index;

use crate::sealing_samples::{
    SEALING_CASES, SampleKeys, generate_sample_keys, hostile_text_strategy,
    workspace_number,
};
use crate::support::test_device::{describe, fail};

const MOST_SAMPLE_KEYS: usize = 4;
const SEALING_KEY_LENGTH: usize = 32;

fn seal_every_key(
    identity: &DeviceIdentity,
    sample_keys: &SampleKeys,
) -> Result<Vec<SealedWorkspaceKey>, String> {
    let sealing_key = identity.public_identity().sealing_public_key;
    let mut sealed_keys = Vec::new();
    for (workspace_id, key) in
        sample_keys.workspace_ids.iter().zip(&sample_keys.keys)
    {
        sealed_keys.push(SealedWorkspaceKey {
            workspace_id: *workspace_id,
            sealed_key: seal_workspace_key(&sealing_key, key)
                .map_err(describe)?,
        });
    }
    Ok(sealed_keys)
}

fn is_security_refusal(outcome: &Result<WorkspaceKeyring, NodeError>) -> bool {
    matches!(outcome, Err(NodeError::Security(_)))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALING_CASES))]

    #[test]
    fn test_open_sealed_keys_property_opens_every_workspace_key(
        key_count in 1..MOST_SAMPLE_KEYS,
        text in hostile_text_strategy(),
    ) {
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let sample_keys = generate_sample_keys(key_count).map_err(fail)?;
        let sealed_keys =
            seal_every_key(&identity, &sample_keys).map_err(fail)?;

        let keyring =
            WorkspaceKeyring::open_sealed_keys(&identity, &sealed_keys)
                .map_err(fail)?;

        for (workspace_id, key) in
            sample_keys.workspace_ids.iter().zip(&sample_keys.keys)
        {
            let opened_key = keyring.key_for(*workspace_id).map_err(fail)?;
            prop_assert_eq!(opened_key.to_bytes(), key.to_bytes());
            let sealed_text = seal_text(key, &text).map_err(fail)?;
            let opened_text = keyring.open_text(&sealed_text).map_err(fail)?;
            prop_assert_eq!(&opened_text, &text);
        }
    }

    #[test]
    fn test_open_sealed_keys_property_another_device_cannot_open_them(
        key_count in 1..MOST_SAMPLE_KEYS,
    ) {
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let other_identity = DeviceIdentity::generate().map_err(fail)?;
        let sample_keys = generate_sample_keys(key_count).map_err(fail)?;
        let sealed_keys =
            seal_every_key(&identity, &sample_keys).map_err(fail)?;

        let outcome =
            WorkspaceKeyring::open_sealed_keys(&other_identity, &sealed_keys);

        prop_assert!(is_security_refusal(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_sealed_keys_property_detects_a_tampered_byte(
        position in any::<Index>(),
        flipped_bits in 1_u8..=u8::MAX,
    ) {
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let sample_keys = generate_sample_keys(1).map_err(fail)?;
        let mut sealed_keys =
            seal_every_key(&identity, &sample_keys).map_err(fail)?;
        let sealed_key = &mut sealed_keys[0].sealed_key;
        let byte_position = position.index(sealed_key.len());
        sealed_key[byte_position] ^= flipped_bits;

        let outcome =
            WorkspaceKeyring::open_sealed_keys(&identity, &sealed_keys);

        prop_assert!(is_security_refusal(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_sealed_keys_property_refuses_a_key_of_the_wrong_length(
        key_length in 0_usize..=64,
    ) {
        prop_assume!(key_length != SEALING_KEY_LENGTH);
        let identity = DeviceIdentity::generate().map_err(fail)?;
        let sealing_key = identity.public_identity().sealing_public_key;
        let wrong_key = vec![7_u8; key_length];
        let sealed_key = seal_for(&sealing_key, &wrong_key).map_err(fail)?;
        let sealed_keys = [SealedWorkspaceKey {
            workspace_id: workspace_number(11),
            sealed_key,
        }];

        let outcome =
            WorkspaceKeyring::open_sealed_keys(&identity, &sealed_keys);

        let is_invalid_key = matches!(
            outcome,
            Err(NodeError::Security(SecurityError::InvalidKey))
        );
        prop_assert!(is_invalid_key, "{:?}", outcome);
    }

    #[test]
    fn test_seal_workspace_key_property_only_the_recipient_opens_it(
        key_count in 1..MOST_SAMPLE_KEYS,
    ) {
        let recipient = DeviceIdentity::generate().map_err(fail)?;
        let stranger = DeviceIdentity::generate().map_err(fail)?;
        let sample_keys = generate_sample_keys(key_count).map_err(fail)?;
        let sealing_key = recipient.public_identity().sealing_public_key;

        for key in &sample_keys.keys {
            let sealed = seal_workspace_key(&sealing_key, key).map_err(fail)?;
            let opened = open_sealed(&recipient, &sealed).map_err(fail)?;
            let key_bytes = key.to_bytes();
            prop_assert_eq!(opened.as_slice(), key_bytes.as_slice());
            prop_assert!(open_sealed(&stranger, &sealed).is_err());
        }
    }

    #[test]
    fn test_seal_workspace_key_property_sealing_twice_never_repeats(
        key_count in 1..MOST_SAMPLE_KEYS,
    ) {
        let recipient = DeviceIdentity::generate().map_err(fail)?;
        let sample_keys = generate_sample_keys(key_count).map_err(fail)?;
        let sealing_key = recipient.public_identity().sealing_public_key;

        for key in &sample_keys.keys {
            let first = seal_workspace_key(&sealing_key, key).map_err(fail)?;
            let second = seal_workspace_key(&sealing_key, key).map_err(fail)?;
            prop_assert_ne!(&first, &second);
            let key_bytes = key.to_bytes();
            let reveals_key = first
                .windows(SEALING_KEY_LENGTH)
                .any(|window| window == key_bytes.as_slice());
            prop_assert!(!reveals_key);
        }
    }

    #[test]
    fn test_seal_workspace_key_property_refuses_a_malformed_recipient(
        recipient_length in 0_usize..=64,
    ) {
        prop_assume!(recipient_length != SEALING_KEY_LENGTH);
        let sample_keys = generate_sample_keys(1).map_err(fail)?;
        let malformed_recipient = vec![9_u8; recipient_length];

        let outcome =
            seal_workspace_key(&malformed_recipient, &sample_keys.keys[0]);

        let is_invalid_key = matches!(
            outcome,
            Err(NodeError::Security(SecurityError::InvalidKey))
        );
        prop_assert!(is_invalid_key, "{:?}", outcome);
    }
}
