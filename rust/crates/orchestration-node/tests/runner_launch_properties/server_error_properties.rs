use orchestration_node::node_error::NodeError;
use orchestration_runner::runner_server::ServerError;
use proptest::prelude::*;
use proptest::strategy::LazyJust;

const KINDS: [&str; 3] = ["claimed run", "approval", "runner"];

fn node_error_strategy() -> impl Strategy<Value = NodeError> {
    prop_oneof![
        (prop::sample::select(KINDS.to_vec()), "\\PC{0,30}").prop_map(
            |(kind, identifier)| NodeError::NotFound { kind, identifier }
        ),
        "\\PC{0,30}".prop_map(NodeError::ServerUnreachable),
        (any::<u16>(), "\\PC{0,30}").prop_map(|(status, message)| {
            NodeError::ServerRejected { status, message }
        }),
        "\\PC{0,30}".prop_map(NodeError::UntrustedDecision),
        LazyJust::new(|| NodeError::NoAccount),
        LazyJust::new(|| NodeError::UntrustedPeer),
    ]
}

proptest! {
    #[test]
    fn test_server_error_from_property_keeps_the_whole_reason(
        problem in node_error_strategy(),
    ) {
        let expected = problem.to_string();

        let converted = ServerError::from(problem);

        prop_assert_eq!(converted.reason, expected);
    }

    #[test]
    fn test_server_error_from_property_never_gives_an_empty_reason(
        problem in node_error_strategy(),
    ) {
        let converted = ServerError::from(problem);

        prop_assert!(!converted.reason.trim().is_empty());
    }

    #[test]
    fn test_server_error_from_property_names_the_missing_claim(
        identifier in "[0-9a-f-]{1,36}",
    ) {
        let problem = NodeError::NotFound {
            kind: KINDS[0],
            identifier: identifier.clone(),
        };

        let converted = ServerError::from(problem);

        let expected = format!("claimed run {identifier} was not found");
        prop_assert_eq!(converted.reason, expected);
    }
}
