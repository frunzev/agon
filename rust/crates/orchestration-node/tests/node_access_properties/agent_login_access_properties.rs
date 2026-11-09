use orchestration_node::agent_credentials::{
    AgentCredential, AgentCredentialKind,
};
use proptest::prelude::*;
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::access_node::{ACCESS_CASES, open_node};
use crate::login_steps::{
    API_KEY_NAME, CONTAINER_PLACE, CREDENTIAL_KIND_FIELD, FINISHED_STATE,
    LOGIN_CASES, RUNNING_STATE, TOKEN_START, any_login_code, any_place,
    finish_login, read_kept_secret, read_login, read_status_field,
    save_api_key, start_login_to_prompt, start_nodes, stop_login,
};
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::test_device::fail;

const LONG_LIVED_TOKEN_NAME: &str = "long_lived_token";

fn credential_strategy() -> impl Strategy<Value = AgentCredential> {
    let kinds = prop_oneof![
        Just(AgentCredentialKind::LongLivedToken),
        Just(AgentCredentialKind::ApiKey),
    ];
    (kinds, secret_text_strategy())
        .prop_filter_map("the secret makes a credential", |(kind, secret)| {
            AgentCredential::new(kind, &secret).ok()
        })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(ACCESS_CASES))]

    #[test]
    fn test_agent_credentials_property_is_one_store_for_the_node(
        credential in credential_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        let first = node.agent_credentials();
        let second = node.agent_credentials();

        first.keep(credential.clone()).map_err(fail)?;

        prop_assert!(std::ptr::eq(first, second));
        prop_assert_eq!(second.current(), Some(credential));
    }

    #[test]
    fn test_agent_credentials_property_a_kept_credential_survives_reopening(
        credential in credential_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        node.agent_credentials()
            .keep(credential.clone())
            .map_err(fail)?;
        drop(node);

        let reopened = open_node(&data_directory).map_err(fail)?;

        let kept = reopened.agent_credentials().current();
        prop_assert_eq!(kept, Some(credential));
    }

    #[test]
    fn test_agent_credentials_property_forgetting_clears_it_everywhere(
        credential in credential_strategy(),
    ) {
        let data_directory = TempDir::new().map_err(fail)?;
        let node = open_node(&data_directory).map_err(fail)?;
        node.agent_credentials().keep(credential).map_err(fail)?;

        node.agent_credentials().forget().map_err(fail)?;

        prop_assert_eq!(node.agent_credentials().current(), None);
        drop(node);
        let reopened = open_node(&data_directory).map_err(fail)?;
        prop_assert_eq!(reopened.agent_credentials().current(), None);
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(LOGIN_CASES))]

    #[test]
    fn test_shared_agent_credentials_property_a_login_keeps_its_token(
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        finish_login(&nodes, CONTAINER_PLACE, &code)?;

        let credential = read_status_field(&nodes, CREDENTIAL_KIND_FIELD)?;
        prop_assert_eq!(credential, LONG_LIVED_TOKEN_NAME);
        let kept_secret = read_kept_secret(&nodes).map_err(fail)?;
        prop_assert!(kept_secret.starts_with(TOKEN_START), "{kept_secret}");
    }

    #[test]
    fn test_shared_agent_credentials_property_a_login_replaces_a_saved_key(
        api_key in secret_text_strategy(),
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        save_api_key(&nodes, &api_key).map_err(fail)?;
        let saved_kind = read_status_field(&nodes, CREDENTIAL_KIND_FIELD)?;

        finish_login(&nodes, CONTAINER_PLACE, &code)?;

        prop_assert_eq!(saved_kind, API_KEY_NAME);
        let credential = read_status_field(&nodes, CREDENTIAL_KIND_FIELD)?;
        prop_assert_eq!(credential, LONG_LIVED_TOKEN_NAME);
        let kept_secret = read_kept_secret(&nodes).map_err(fail)?;
        prop_assert_ne!(kept_secret, api_key);
    }

    #[test]
    fn test_shared_agent_credentials_property_forgetting_drops_the_token(
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;
        finish_login(&nodes, CONTAINER_PLACE, &code)?;

        nodes
            .run(&json!({ "command": "forget_agent_credential" }))
            .map_err(fail)?;

        let credential = read_status_field(&nodes, CREDENTIAL_KIND_FIELD)?;
        prop_assert_eq!(credential, Value::Null);
    }

    #[test]
    fn test_agent_login_desk_property_one_login_spans_the_commands(
        place in any_place(),
    ) {
        let nodes = start_nodes()?;
        start_login_to_prompt(&nodes, place)?;

        let shown = read_login(&nodes).map_err(fail)?;

        prop_assert_eq!(&shown["place"], place);
        prop_assert_eq!(&shown["state"], RUNNING_STATE);
        stop_login(&nodes).map_err(fail)?;
    }

    #[test]
    fn test_agent_login_desk_property_typed_keys_finish_the_started_login(
        place in any_place(),
        code in any_login_code(),
    ) {
        let nodes = start_nodes()?;

        let ending = finish_login(&nodes, place, &code)?;

        prop_assert_eq!(&ending["state"], FINISHED_STATE);
        prop_assert_eq!(&ending["place"], place);
    }

    #[test]
    fn test_agent_login_desk_property_a_stop_empties_the_desk(
        place in any_place(),
    ) {
        let nodes = start_nodes()?;
        start_login_to_prompt(&nodes, place)?;

        stop_login(&nodes).map_err(fail)?;

        prop_assert_eq!(read_login(&nodes).map_err(fail)?, Value::Null);
    }
}
