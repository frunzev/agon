use orchestration_node::live_link_messages::{
    ClientMessage, RunnerMessage, decode_link_message, encode_link_message,
};
use orchestration_node::node_error::NodeError;
use proptest::prelude::*;
use serde_json::json;

use crate::link_message_samples::{
    LINK_CASES, client_message_strategy, hostile_text_strategy,
    runner_message_strategy,
};
use crate::support::test_device::fail;

const KNOWN_KINDS: [&str; 7] = [
    "watch", "chat", "browse", "accepted", "refused", "events", "answered",
];
const LARGE_CASES: u32 = 4;
const MOST_HOSTILE_BYTES: usize = 256;
const LEAST_NESTING: usize = 200;
const MOST_NESTING: usize = 20_000;
const LEAST_LARGE_TEXT: usize = 100_000;
const MOST_LARGE_TEXT: usize = 2_000_000;
const NESTED_CHAT_START: &str = "{\"kind\":\"chat\",\"text\":";
const OPENING_BRACKET: &str = "[";
const LARGE_TEXT_SYMBOL: &str = "é";

fn is_malformed<Message>(decoded: &Result<Message, NodeError>) -> bool {
    matches!(decoded, Err(NodeError::MalformedLinkMessage(_)))
}

fn trailing_garbage_strategy() -> impl Strategy<Value = String> {
    "[^ \t\r\n]{1,8}"
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LINK_CASES))]

    #[test]
    fn test_decode_link_message_property_any_bytes_decode_or_are_malformed(
        frame in prop::collection::vec(any::<u8>(), 0..MOST_HOSTILE_BYTES),
    ) {
        let as_client = decode_link_message::<ClientMessage>(&frame);
        let as_runner = decode_link_message::<RunnerMessage>(&frame);

        prop_assert!(as_client.is_ok() || is_malformed(&as_client));
        prop_assert!(as_runner.is_ok() || is_malformed(&as_runner));
    }

    #[test]
    fn test_decode_link_message_property_a_cut_frame_is_malformed(
        message in client_message_strategy(),
        cut in any::<prop::sample::Index>(),
    ) {
        let frame = encode_link_message(&message).map_err(fail)?;
        let kept_length = cut.index(frame.len());

        let decoded =
            decode_link_message::<ClientMessage>(&frame[..kept_length]);

        prop_assert!(is_malformed(&decoded), "{:?}", decoded);
    }

    #[test]
    fn test_decode_link_message_property_trailing_bytes_are_malformed(
        message in runner_message_strategy(),
        garbage in trailing_garbage_strategy(),
    ) {
        let mut frame = encode_link_message(&message).map_err(fail)?;
        frame.extend_from_slice(garbage.as_bytes());

        let decoded = decode_link_message::<RunnerMessage>(&frame);

        prop_assert!(is_malformed(&decoded), "{:?}", decoded);
    }

    #[test]
    fn test_decode_link_message_property_an_unknown_kind_is_malformed(
        kind in hostile_text_strategy(),
        text in hostile_text_strategy(),
    ) {
        prop_assume!(!KNOWN_KINDS.contains(&kind.as_str()));
        let frame = json!({ "kind": kind, "text": text }).to_string();

        let as_client = decode_link_message::<ClientMessage>(frame.as_bytes());
        let as_runner = decode_link_message::<RunnerMessage>(frame.as_bytes());

        prop_assert!(is_malformed(&as_client), "{:?}", as_client);
        prop_assert!(is_malformed(&as_runner), "{:?}", as_runner);
    }

    #[test]
    fn test_decode_link_message_property_the_other_side_kind_is_malformed(
        client_message in client_message_strategy(),
        runner_message in runner_message_strategy(),
    ) {
        let client_frame = encode_link_message(&client_message).map_err(fail)?;
        let runner_frame = encode_link_message(&runner_message).map_err(fail)?;

        let client_as_runner =
            decode_link_message::<RunnerMessage>(&client_frame);
        let runner_as_client =
            decode_link_message::<ClientMessage>(&runner_frame);

        prop_assert!(is_malformed(&client_as_runner));
        prop_assert!(is_malformed(&runner_as_client));
    }

    #[test]
    fn test_decode_link_message_property_a_repeated_kind_is_malformed(
        text in hostile_text_strategy(),
    ) {
        let text_json = json!(text).to_string();
        let frame = format!(
            "{{\"kind\":\"chat\",\"kind\":\"watch\",\"text\":{text_json}}}"
        );

        let decoded = decode_link_message::<ClientMessage>(frame.as_bytes());

        prop_assert!(is_malformed(&decoded), "{:?}", decoded);
    }

    #[test]
    fn test_decode_link_message_property_deep_nesting_is_malformed(
        depth in LEAST_NESTING..MOST_NESTING,
    ) {
        let nesting = OPENING_BRACKET.repeat(depth);
        let frame = format!("{NESTED_CHAT_START}{nesting}");

        let decoded = decode_link_message::<ClientMessage>(frame.as_bytes());

        prop_assert!(is_malformed(&decoded));
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LARGE_CASES))]

    #[test]
    fn test_decode_link_message_property_a_large_chat_round_trips(
        length in LEAST_LARGE_TEXT..MOST_LARGE_TEXT,
    ) {
        let message = ClientMessage::Chat {
            text: LARGE_TEXT_SYMBOL.repeat(length),
        };
        let frame = encode_link_message(&message).map_err(fail)?;

        let decoded: ClientMessage =
            decode_link_message(&frame).map_err(fail)?;

        prop_assert_eq!(decoded, message);
    }
}
