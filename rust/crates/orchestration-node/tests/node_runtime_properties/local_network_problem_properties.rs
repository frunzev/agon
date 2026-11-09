use orchestration_node::command_reply::render_node_error_reply;
use orchestration_node::describe_local_network_problem;
use orchestration_node::node_error::NodeError;
use proptest::prelude::*;
use serde_json::Value;

const PROBLEM_CASES: u32 = 64;
const SERVICE_FAILURE_PREFIX: &str = "the local network service failed: ";
const PROBLEM_PATTERN: &str = "\\PC{0,60}";

fn render_problem_reply(problem_text: &str) -> Result<Value, TestCaseError> {
    let problem = describe_local_network_problem(&problem_text);
    let reply_text = render_node_error_reply(&problem);
    serde_json::from_str(&reply_text)
        .map_err(|error| TestCaseError::fail(error.to_string()))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROBLEM_CASES))]

    #[test]
    fn test_describe_local_network_problem_property_keeps_the_problem_text(
        problem_text in PROBLEM_PATTERN,
    ) {
        let described = describe_local_network_problem(&problem_text);

        let NodeError::LocalNetwork(kept_text) = described else {
            return Err(TestCaseError::fail("not a local network error"));
        };
        prop_assert_eq!(kept_text, problem_text);
    }

    #[test]
    fn test_describe_local_network_problem_property_names_the_service(
        problem_text in PROBLEM_PATTERN,
    ) {
        let described = describe_local_network_problem(&problem_text);

        let message = described.to_string();
        let expected = format!("{SERVICE_FAILURE_PREFIX}{problem_text}");
        prop_assert_eq!(message, expected);
    }

    #[test]
    fn test_describe_local_network_problem_property_distinct_stay_distinct(
        first_text in PROBLEM_PATTERN,
        second_text in PROBLEM_PATTERN,
    ) {
        let first_reply = render_problem_reply(&first_text)?;
        let second_reply = render_problem_reply(&second_text)?;

        let is_same_text = first_text == second_text;
        prop_assert_eq!(first_reply == second_reply, is_same_text);
        let shown = first_reply["error"].as_str().unwrap_or_default();
        prop_assert!(shown.ends_with(&first_text), "{}", shown);
    }
}
