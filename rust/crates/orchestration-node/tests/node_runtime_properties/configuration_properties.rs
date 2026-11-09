use orchestration_node::node_configuration::{
    DEFAULT_APP_SERVER_PORT, DEFAULT_TAKEOVER_SECONDS, NodeConfiguration,
    PeerRelayChoice,
};
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::configuration_samples::{
    INVALID_CONFIGURATION_START, KNOWN_FIELDS, REQUIRED_FIELDS,
    configuration_strategy, parse_fields, write_configuration,
};

const PARSE_CASES: u32 = 96;
const STRAY_NAME_PATTERN: &str = "[a-zA-Z_ ]{1,16}";
const PORT_FIELD: &str = "app_server_port";
const TAKEOVER_FIELD: &str = "server_takeover_seconds";
const RELAY_FIELD: &str = "peer_relay";
const LARGEST_PORT: i64 = 65_535;

fn is_refusal(parsed: &Result<NodeConfiguration, String>) -> bool {
    parsed
        .as_ref()
        .is_err_and(|problem| problem.starts_with(INVALID_CONFIGURATION_START))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PARSE_CASES))]

    #[test]
    fn test_from_json_property_round_trips_a_written_configuration(
        configuration in configuration_strategy(),
    ) {
        let fields = write_configuration(&configuration);

        let parsed = parse_fields(fields);

        prop_assert_eq!(parsed, Ok(configuration));
    }

    #[test]
    fn test_from_json_property_refuses_a_stray_field(
        configuration in configuration_strategy(),
        stray_name in STRAY_NAME_PATTERN
            .prop_filter("not a known field", |name| {
                !KNOWN_FIELDS.contains(&name.as_str())
            }),
        stray_value in any::<i32>(),
    ) {
        let mut fields = write_configuration(&configuration);
        fields.insert(stray_name, json!(stray_value));

        let parsed = parse_fields(fields);

        prop_assert!(is_refusal(&parsed), "{:?}", parsed);
    }

    #[test]
    fn test_from_json_property_refuses_a_missing_required_field(
        configuration in configuration_strategy(),
        missing_field in prop::sample::select(REQUIRED_FIELDS.to_vec()),
    ) {
        let mut fields = write_configuration(&configuration);
        fields.remove(missing_field);

        let parsed = parse_fields(fields);

        prop_assert!(is_refusal(&parsed), "{:?}", parsed);
        let problem = parsed.err().unwrap_or_default();
        prop_assert!(problem.contains(missing_field), "{}", problem);
    }

    #[test]
    fn test_from_json_property_refuses_text_that_is_no_object(
        configuration_text in "\\PC{0,40}",
    ) {
        let parsed: Result<Value, _> =
            serde_json::from_str(&configuration_text);
        prop_assume!(!parsed.is_ok_and(|value| value.is_object()));

        let configured = NodeConfiguration::from_json(&configuration_text)
            .map_err(|problem| problem.to_string());

        prop_assert!(is_refusal(&configured), "{:?}", configured);
    }

    #[test]
    fn test_from_json_property_refuses_a_port_outside_the_range(
        configuration in configuration_strategy(),
        excess in 1_i64..1_000_000,
        is_negative in any::<bool>(),
    ) {
        let outside_port = if is_negative {
            -excess
        } else {
            LARGEST_PORT + excess
        };
        let mut fields = write_configuration(&configuration);
        fields.insert(PORT_FIELD.to_owned(), json!(outside_port));

        let parsed = parse_fields(fields);

        prop_assert!(is_refusal(&parsed), "{:?}", parsed);
    }

    #[test]
    fn test_from_json_property_refuses_an_unknown_relay_name(
        configuration in configuration_strategy(),
        relay_name in "[a-z]{1,12}"
            .prop_filter("not a relay name", |name| {
                name != "default" && name != "disabled"
            }),
    ) {
        let mut fields = write_configuration(&configuration);
        fields.insert(RELAY_FIELD.to_owned(), json!(relay_name));

        let parsed = parse_fields(fields);

        prop_assert!(is_refusal(&parsed), "{:?}", parsed);
    }

    #[test]
    fn test_choose_default_app_server_port_property_fills_a_missing_port(
        configuration in configuration_strategy(),
    ) {
        let mut fields = write_configuration(&configuration);
        fields.remove(PORT_FIELD);

        let parsed = parse_fields(fields);

        let expected = NodeConfiguration {
            app_server_port: DEFAULT_APP_SERVER_PORT,
            ..configuration
        };
        prop_assert_eq!(parsed, Ok(expected));
    }

    #[test]
    fn test_choose_default_app_server_port_property_keeps_a_given_port(
        configuration in configuration_strategy(),
    ) {
        let fields = write_configuration(&configuration);

        let parsed = parse_fields(fields).map_err(TestCaseError::fail)?;

        let kept_port = parsed.app_server_port;
        prop_assert_eq!(kept_port, configuration.app_server_port);
    }

    #[test]
    fn test_choose_default_app_server_port_property_equals_naming_it(
        configuration in configuration_strategy(),
    ) {
        let mut omitted_fields = write_configuration(&configuration);
        omitted_fields.remove(PORT_FIELD);
        let mut named_fields = omitted_fields.clone();
        named_fields
            .insert(PORT_FIELD.to_owned(), json!(DEFAULT_APP_SERVER_PORT));

        let omitted = parse_fields(omitted_fields);
        let named = parse_fields(named_fields);

        prop_assert_eq!(omitted, named);
        prop_assert!(DEFAULT_APP_SERVER_PORT > 0);
    }

    #[test]
    fn test_choose_default_takeover_seconds_property_fills_missing_seconds(
        configuration in configuration_strategy(),
    ) {
        let mut fields = write_configuration(&configuration);
        fields.remove(TAKEOVER_FIELD);

        let parsed = parse_fields(fields);

        let expected = NodeConfiguration {
            server_takeover_seconds: DEFAULT_TAKEOVER_SECONDS,
            ..configuration
        };
        prop_assert_eq!(parsed, Ok(expected));
    }

    #[test]
    fn test_choose_default_takeover_seconds_property_keeps_given_seconds(
        configuration in configuration_strategy(),
    ) {
        let fields = write_configuration(&configuration);

        let parsed = parse_fields(fields).map_err(TestCaseError::fail)?;

        prop_assert_eq!(
            parsed.server_takeover_seconds,
            configuration.server_takeover_seconds
        );
    }

    #[test]
    fn test_choose_default_takeover_seconds_property_equals_naming_it(
        configuration in configuration_strategy(),
        is_relay_omitted in any::<bool>(),
    ) {
        let mut omitted_fields = write_configuration(&configuration);
        omitted_fields.remove(TAKEOVER_FIELD);
        if is_relay_omitted {
            omitted_fields.remove(RELAY_FIELD);
        }
        let mut named_fields = omitted_fields.clone();
        named_fields.insert(
            TAKEOVER_FIELD.to_owned(),
            json!(DEFAULT_TAKEOVER_SECONDS),
        );

        let omitted = parse_fields(omitted_fields);
        let named = parse_fields(named_fields);

        prop_assert_eq!(&omitted, &named);
        let relay = omitted.map(|parsed| parsed.peer_relay);
        if is_relay_omitted {
            prop_assert_eq!(relay, Ok(PeerRelayChoice::Default));
        }
    }
}
