use proptest::prelude::*;
use serde_json::{Value, json};

use crate::featureless_node::{
    ERROR_KIND_FIELD, FEATURELESS_CASES, NOT_A_RUNNER_PROBLEM, ServedNode,
    start_served_node,
};
use crate::test_device::fail;

const FILE_COMMANDS: [&str; 2] =
    ["list_repository_files", "read_repository_file"];
const BRANCH_PATTERN: &str = "[a-z][a-z0-9-]{0,8}";
const PATH_PATTERN: &str = "[a-z]{1,6}(/[a-z]{1,6}){0,2}";
const MOST_REPEATS: usize = 3;

fn list_branches(served: &ServedNode, preferred: &Value) -> Value {
    json!({
        "command": "list_repository_branches",
        "project_id": served.project_id,
        "repository_address": served.repository_address,
        "preferred_runner_id": preferred,
    })
}

fn own_file_question(
    served: &ServedNode,
    command: &str,
    branch: &str,
    path: &str,
) -> Value {
    let mut question = json!({
        "command": command,
        "project_id": served.project_id,
        "repository_address": served.repository_address,
        "runner_id": served.device_id,
        "branch": branch,
    });
    if command == FILE_COMMANDS[0] {
        question["folder"] = json!(path);
    } else {
        question["path"] = json!(path);
    }
    question
}

fn unavailable_source() -> Value {
    json!({ "kind": "unavailable", "holders": [] })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FEATURELESS_CASES))]

    #[test]
    fn test_holds_own_copy_property_a_runnerless_device_holds_nothing(
        _seed in any::<u8>(),
    ) {
        let served = start_served_node().map_err(fail)?;

        let source = served.node.run(&list_branches(&served, &Value::Null));

        prop_assert_eq!(source, Ok(unavailable_source()));
    }

    #[test]
    fn test_holds_own_copy_property_preferring_itself_changes_nothing(
        _seed in any::<u8>(),
    ) {
        let served = start_served_node().map_err(fail)?;
        let preferred = json!(served.device_id);

        let source = served.node.run(&list_branches(&served, &preferred));

        prop_assert_eq!(source, Ok(unavailable_source()));
    }

    #[test]
    fn test_holds_own_copy_property_asking_again_gives_the_same_answer(
        repeat_count in 2..=MOST_REPEATS,
    ) {
        let served = start_served_node().map_err(fail)?;
        let first = served.node.run(&list_branches(&served, &Value::Null));

        for _ in 1..repeat_count {
            let again = served.node.run(&list_branches(&served, &Value::Null));
            prop_assert_eq!(&again, &first);
        }
    }

    #[test]
    fn test_read_own_copy_property_listing_needs_a_runner(
        branch in BRANCH_PATTERN,
        folder in PATH_PATTERN,
    ) {
        let served = start_served_node().map_err(fail)?;
        let question =
            own_file_question(&served, FILE_COMMANDS[0], &branch, &folder);

        let listed = served.node.run(&question);

        prop_assert_eq!(listed, Err(NOT_A_RUNNER_PROBLEM.to_owned()));
    }

    #[test]
    fn test_read_own_copy_property_reading_needs_a_runner(
        branch in BRANCH_PATTERN,
        path in PATH_PATTERN,
    ) {
        let served = start_served_node().map_err(fail)?;
        let question =
            own_file_question(&served, FILE_COMMANDS[1], &branch, &path);

        let read = served.node.run(&question);

        prop_assert_eq!(read, Err(NOT_A_RUNNER_PROBLEM.to_owned()));
    }

    #[test]
    fn test_read_own_copy_property_the_refusal_carries_no_kind(
        command in prop::sample::select(FILE_COMMANDS.to_vec()),
        path in PATH_PATTERN,
    ) {
        let served = start_served_node().map_err(fail)?;
        let question = own_file_question(&served, command, "main", &path);

        let reply = served.node.send(&question);

        prop_assert_eq!(&reply["error"], &json!(NOT_A_RUNNER_PROBLEM));
        prop_assert!(reply.get(ERROR_KIND_FIELD).is_none(), "{}", reply);
    }
}
