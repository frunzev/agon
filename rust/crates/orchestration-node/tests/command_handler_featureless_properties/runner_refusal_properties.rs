use proptest::prelude::*;
use serde_json::{Value, json};

use crate::featureless_node::{
    ERROR_KIND_FIELD, FEATURELESS_CASES, FeaturelessNode,
    NOT_A_RUNNER_PROBLEM, start_served_node,
};
use crate::test_device::fail;

const AGENT_LOGIN_COMMANDS: [&str; 7] = [
    "agent_login_status",
    "start_agent_login",
    "read_agent_login",
    "type_agent_login",
    "stop_agent_login",
    "save_agent_api_key",
    "forget_agent_credential",
];
const CREDENTIAL_FILE_NAME: &str = "agent-credential.key";
const SECRET_PATTERN: &str = "[A-Za-z0-9_-]{1,24}";

fn build_login_command(name: &str, secret: &str) -> Value {
    let mut command = json!({ "command": name });
    match name {
        "start_agent_login" => command["place"] = json!("local_process"),
        "type_agent_login" => command["keys"] = json!(secret),
        "save_agent_api_key" => command["api_key"] = json!(secret),
        _ => {}
    }
    command
}

fn login_command_strategy() -> impl Strategy<Value = &'static str> {
    prop::sample::select(AGENT_LOGIN_COMMANDS.to_vec())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FEATURELESS_CASES))]

    #[test]
    fn test_handle_agent_login_command_property_refuses_without_a_runner(
        name in login_command_strategy(),
        secret in SECRET_PATTERN,
    ) {
        let node = FeaturelessNode::start().map_err(fail)?;

        let reply = node.send(&build_login_command(name, &secret));

        prop_assert_eq!(&reply["error"], &json!(NOT_A_RUNNER_PROBLEM));
        prop_assert!(reply.get(ERROR_KIND_FIELD).is_none(), "{}", reply);
    }

    #[test]
    fn test_handle_agent_login_command_property_an_account_changes_nothing(
        name in login_command_strategy(),
        secret in SECRET_PATTERN,
    ) {
        let served = start_served_node().map_err(fail)?;

        let refused = served.node.run(&build_login_command(name, &secret));

        prop_assert_eq!(refused, Err(NOT_A_RUNNER_PROBLEM.to_owned()));
    }

    #[test]
    fn test_handle_agent_login_command_property_keeps_no_credential(
        secrets in prop::collection::vec(SECRET_PATTERN, 1..4),
    ) {
        let node = FeaturelessNode::start().map_err(fail)?;

        for secret in &secrets {
            let command = build_login_command(AGENT_LOGIN_COMMANDS[5], secret);
            prop_assert_eq!(
                node.run(&command),
                Err(NOT_A_RUNNER_PROBLEM.to_owned())
            );
        }

        let credential_path =
            node.data_directory.path().join(CREDENTIAL_FILE_NAME);
        prop_assert!(!credential_path.exists());
    }
}
