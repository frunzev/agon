use proptest::prelude::*;
use serde_json::{Value, json};

use crate::command_shapes::AGENT_LOGIN_SHAPES;
use crate::handler_desk::{
    NOT_A_RUNNER_PROBLEM, list_object_keys, read_error_kind,
    read_reply_problem, shared_fresh_device, sorted_texts,
};
use crate::shape_checks::shape_strategy;
use crate::support::login_runner::{
    ClaudePresence, LoginRunner, local_sandbox,
};
use crate::support::test_device::fail;

const LOGIN_CASES: u32 = 2;
const MOST_STEPS: usize = 5;
const RUNNERLESS_CASES: u32 = 8;
const API_KEY_PATTERN: &str = "[A-Za-z0-9_-]{8,40}";
const BREAKING_CHARACTERS: [&str; 4] = [" ", "\n", "\t", "\r"];
const NO_LOGIN_PROBLEM: &str = "no Claude Code login is open";
const BAD_SECRET_PROBLEM: &str =
    "the token or API key cannot have spaces or line breaks";
const CREDENTIAL_FILE_NAME: &str = "agent-credential.key";
const CREDENTIAL_FIELD: &str = "container_credential";
const CLAUDE_LOGIN_FIELD: &str = "claude_login";
const API_KEY_KIND: &str = "api_key";
const DART_STATUS_FIELDS: [&str; 2] = [CLAUDE_LOGIN_FIELD, CREDENTIAL_FIELD];
const DART_CLAUDE_LOGIN_NAMES: [&str; 4] =
    ["logged_in", "not_logged_in", "not_installed", "unknown"];
const DART_CREDENTIAL_NAMES: [&str; 2] = ["long_lived_token", API_KEY_KIND];

fn start_login_runner() -> Result<LoginRunner, TestCaseError> {
    LoginRunner::start(&local_sandbox(), ClaudePresence::Installed)
        .map_err(fail)
}

fn save_api_key(runner: &LoginRunner, api_key: &str) -> Result<Value, String> {
    runner.run(&json!({ "command": "save_agent_api_key", "api_key": api_key }))
}

fn forget_credential(runner: &LoginRunner) -> Result<Value, String> {
    runner.run(&json!({ "command": "forget_agent_credential" }))
}

fn read_credential(runner: &LoginRunner) -> Result<Value, TestCaseError> {
    let status = runner.read_login_status().map_err(fail)?;
    Ok(status[CREDENTIAL_FIELD].clone())
}

fn insert_breaking_character(api_key: &str, chosen: usize) -> String {
    let breaking = BREAKING_CHARACTERS[chosen % BREAKING_CHARACTERS.len()];
    let middle = api_key.len() / 2;
    format!("{}{breaking}{}", &api_key[..middle], &api_key[middle..])
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(RUNNERLESS_CASES))]

    #[test]
    fn test_handle_agent_login_command_property_needs_a_runner(
        shape in shape_strategy(&AGENT_LOGIN_SHAPES),
    ) {
        let device = shared_fresh_device()?;

        let reply = device.send(&shape.build_command());

        prop_assert_eq!(read_reply_problem(&reply), NOT_A_RUNNER_PROBLEM);
        prop_assert_eq!(read_error_kind(&reply), None);
        let credential_path =
            device.data_directory.path().join(CREDENTIAL_FILE_NAME);
        prop_assert!(!credential_path.exists());
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LOGIN_CASES))]

    #[test]
    fn test_handle_agent_login_command_property_a_saved_key_can_be_forgotten(
        api_key in API_KEY_PATTERN,
    ) {
        let runner = start_login_runner()?;

        let saved = save_api_key(&runner, &api_key);
        let after_saving = read_credential(&runner)?;
        let forgotten = forget_credential(&runner);
        let after_forgetting = read_credential(&runner)?;

        prop_assert_eq!(saved, Ok(Value::Null));
        prop_assert_eq!(after_saving, json!(API_KEY_KIND));
        prop_assert_eq!(forgotten, Ok(Value::Null));
        prop_assert_eq!(after_forgetting, Value::Null);
    }

    #[test]
    fn test_handle_agent_login_command_property_typing_needs_an_open_login(
        keys in "\\PC{0,12}",
    ) {
        let runner = start_login_runner()?;

        let typed = runner.run(&json!({
            "command": "type_agent_login",
            "keys": keys,
        }));
        let stopped = runner.run(&json!({ "command": "stop_agent_login" }));
        let shown = runner.run(&json!({ "command": "read_agent_login" }));

        prop_assert_eq!(typed, Err(NO_LOGIN_PROBLEM.to_owned()));
        prop_assert_eq!(stopped, Ok(Value::Null));
        prop_assert_eq!(shown, Ok(Value::Null));
    }

    #[test]
    fn test_handle_agent_login_command_property_a_broken_key_keeps_the_old(
        api_key in API_KEY_PATTERN,
        chosen in any::<usize>(),
    ) {
        let runner = start_login_runner()?;
        save_api_key(&runner, &api_key).map_err(fail)?;
        let broken_key = insert_breaking_character(&api_key, chosen);

        let refused = save_api_key(&runner, &broken_key);
        let credential = read_credential(&runner)?;

        prop_assert_eq!(refused, Err(BAD_SECRET_PROBLEM.to_owned()));
        prop_assert_eq!(credential, json!(API_KEY_KIND));
    }

    #[test]
    fn test_agent_login_status_view_property_has_the_dart_fields(
        api_key in prop::option::of(API_KEY_PATTERN),
    ) {
        let runner = start_login_runner()?;
        if let Some(api_key) = &api_key {
            save_api_key(&runner, api_key).map_err(fail)?;
        }

        let status = runner.read_login_status().map_err(fail)?;

        prop_assert_eq!(
            list_object_keys(&status),
            sorted_texts(&DART_STATUS_FIELDS)
        );
    }

    #[test]
    fn test_agent_login_status_view_property_names_known_dart_values(
        api_key in prop::option::of(API_KEY_PATTERN),
    ) {
        let runner = start_login_runner()?;
        if let Some(api_key) = &api_key {
            save_api_key(&runner, api_key).map_err(fail)?;
        }

        let status = runner.read_login_status().map_err(fail)?;

        let claude_login = status[CLAUDE_LOGIN_FIELD].as_str().unwrap_or("");
        prop_assert!(DART_CLAUDE_LOGIN_NAMES.contains(&claude_login));
        let credential = &status[CREDENTIAL_FIELD];
        let credential_name = credential.as_str().unwrap_or("");
        let is_dart_name = DART_CREDENTIAL_NAMES.contains(&credential_name);
        let is_known_credential = credential.is_null() || is_dart_name;
        prop_assert!(is_known_credential, "{}", credential);
    }

    #[test]
    fn test_agent_login_status_view_property_follows_saves_and_forgets(
        steps in prop::collection::vec(
            prop::option::of(API_KEY_PATTERN),
            1..MOST_STEPS,
        ),
    ) {
        let runner = start_login_runner()?;

        for step in &steps {
            match step {
                Some(api_key) => save_api_key(&runner, api_key),
                None => forget_credential(&runner),
            }
            .map_err(fail)?;
            let expected = match step {
                Some(_) => json!(API_KEY_KIND),
                None => Value::Null,
            };
            prop_assert_eq!(read_credential(&runner)?, expected);
        }
    }
}
