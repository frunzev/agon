use std::collections::BTreeMap;

use orchestration_core::identifiers::WorkspaceId;
use orchestration_node::content_sealing::WorkspaceKeyring;
use orchestration_node::node_error::NodeError;
use orchestration_security::sealing::{SEALED_TEXT_PREFIX, WorkspaceKey};
use proptest::prelude::*;
use proptest::sample::Index;
use uuid::Uuid;

use crate::support::test_device::describe;

pub const SEALING_CASES: u32 = 24;
const HEX_DIGITS: &str = "0123456789abcdef";
const HEX_DIGIT_COUNT: u8 = 16;
const LONGEST_HOSTILE_TEXT: usize = 200;
const HOSTILE_PATTERN: &str = "[ \t\n\"\\\\]{0,4}sealed-v1:[0-9a-f]{0,12}\"?";
const UNICODE_PATTERN: &str =
    "[\u{202E}\u{200B}\u{FEFF}é漢😀\r\u{7F}a-z ]{0,12}";

#[derive(Debug)]
pub struct SampleKeys {
    pub workspace_ids: Vec<WorkspaceId>,
    pub keys: Vec<WorkspaceKey>,
}

pub fn hostile_text_strategy() -> impl Strategy<Value = String> {
    let arbitrary_characters =
        proptest::collection::vec(any::<char>(), 0..LONGEST_HOSTILE_TEXT)
            .prop_map(String::from_iter);
    prop_oneof![
        Just(String::new()),
        Just("plan".to_owned()),
        HOSTILE_PATTERN,
        UNICODE_PATTERN,
        arbitrary_characters,
    ]
}

pub fn hostile_texts_strategy() -> impl Strategy<Value = Vec<String>> {
    proptest::collection::vec(hostile_text_strategy(), 1..4)
}

pub fn workspace_number(number: u128) -> WorkspaceId {
    WorkspaceId(Uuid::from_u128(number))
}

pub fn copy_workspace_key(
    workspace_key: &WorkspaceKey,
) -> Result<WorkspaceKey, String> {
    let key_bytes = workspace_key.to_bytes();
    WorkspaceKey::from_bytes(key_bytes.as_ref()).map_err(describe)
}

pub fn generate_sample_keys(key_count: usize) -> Result<SampleKeys, String> {
    let mut workspace_ids = Vec::new();
    let mut keys = Vec::new();
    for position in 0..key_count {
        let number = u128::try_from(position).map_err(describe)?;
        workspace_ids.push(workspace_number(number + 1));
        keys.push(WorkspaceKey::generate().map_err(describe)?);
    }
    Ok(SampleKeys {
        workspace_ids,
        keys,
    })
}

pub fn build_keyring(
    sample_keys: &SampleKeys,
    chosen_positions: &[usize],
) -> Result<WorkspaceKeyring, String> {
    let mut keys = BTreeMap::new();
    for position in chosen_positions {
        let workspace_id = sample_keys.workspace_ids[*position];
        let key_copy = copy_workspace_key(&sample_keys.keys[*position])?;
        keys.insert(workspace_id, key_copy);
    }
    Ok(WorkspaceKeyring::from_keys(keys))
}

pub fn foreign_keyring() -> Result<WorkspaceKeyring, String> {
    let sample_keys = generate_sample_keys(1)?;
    build_keyring(&sample_keys, &[0])
}

pub fn is_hex_only_sealed_text(sealed_text: &str) -> bool {
    let Some(encoded) = sealed_text.strip_prefix(SEALED_TEXT_PREFIX) else {
        return false;
    };
    let is_lowercase_hex = encoded
        .chars()
        .all(|character| HEX_DIGITS.contains(character));
    !encoded.is_empty() && is_lowercase_hex
}

pub fn tamper_sealed_text(
    sealed_text: &str,
    position: Index,
    shift: u8,
) -> String {
    let prefix_length = SEALED_TEXT_PREFIX.len();
    let encoded = &sealed_text[prefix_length..];
    let digit_position = prefix_length + position.index(encoded.len());
    let mut tampered_characters: Vec<char> = sealed_text.chars().collect();
    let original_digit = tampered_characters[digit_position];
    let original_value = HEX_DIGITS.find(original_digit).unwrap_or_default();
    let step = usize::from(1 + shift % (HEX_DIGIT_COUNT - 1));
    let tampered_value = (original_value + step) % HEX_DIGITS.len();
    let tampered_digit = HEX_DIGITS.as_bytes()[tampered_value];
    tampered_characters[digit_position] = char::from(tampered_digit);
    String::from_iter(tampered_characters)
}

pub fn is_unreadable<Opened>(outcome: &Result<Opened, NodeError>) -> bool {
    matches!(outcome, Err(NodeError::UnreadableSealedText))
}
