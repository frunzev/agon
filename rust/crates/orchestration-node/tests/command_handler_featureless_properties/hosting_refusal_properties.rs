use proptest::prelude::*;
use serde_json::{Value, json};

use crate::featureless_node::{
    ERROR_KIND_FIELD, FEATURELESS_CASES, FeaturelessNode, create_account,
};
use crate::test_device::fail;
use crate::test_server::TestServer;

const HOSTING_UNAVAILABLE: &str = "this device cannot host the app server";
const ROLE_NAMES: [&str; 3] = ["client", "runner", "client_and_runner"];
const NAME_PATTERN: &str = "\\PC{0,12}";
const MOST_REPEATS: usize = 3;

fn hosted_account_command(
    workspace_name: &str,
    device_name: &str,
    role: &str,
) -> Value {
    json!({
        "command": "create_hosted_account",
        "workspace_name": workspace_name,
        "device_name": device_name,
        "role": role,
    })
}

fn role_strategy() -> impl Strategy<Value = &'static str> {
    prop::sample::select(ROLE_NAMES.to_vec())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FEATURELESS_CASES))]

    #[test]
    fn test_create_hosted_account_property_refuses_without_hosting(
        workspace_name in NAME_PATTERN,
        device_name in NAME_PATTERN,
        role in role_strategy(),
    ) {
        let node = FeaturelessNode::start().map_err(fail)?;

        let reply = node.send(&hosted_account_command(
            &workspace_name,
            &device_name,
            role,
        ));

        prop_assert_eq!(&reply["error"], &json!(HOSTING_UNAVAILABLE));
        prop_assert!(reply.get(ERROR_KIND_FIELD).is_none(), "{}", reply);
    }

    #[test]
    fn test_create_hosted_account_property_leaves_room_for_an_account(
        role in role_strategy(),
    ) {
        let server = TestServer::start().map_err(fail)?;
        let node = FeaturelessNode::start().map_err(fail)?;
        let command = hosted_account_command("acme", "air-laptop", role);
        let refused = node.run(&command);

        let status = node.run(&json!({ "command": "status" })).map_err(fail)?;
        let created = create_account(&node, &server);

        prop_assert_eq!(refused, Err(HOSTING_UNAVAILABLE.to_owned()));
        prop_assert_eq!(&status["account"], &Value::Null);
        prop_assert!(created.is_ok(), "{:?}", created);
    }

    #[test]
    fn test_create_hosted_account_property_repeats_the_same_refusal(
        role in role_strategy(),
        repeat_count in 2..=MOST_REPEATS,
    ) {
        let node = FeaturelessNode::start().map_err(fail)?;
        let command = hosted_account_command("acme", "air-laptop", role);

        for _ in 0..repeat_count {
            prop_assert_eq!(
                node.run(&command),
                Err(HOSTING_UNAVAILABLE.to_owned())
            );
        }
    }
}
