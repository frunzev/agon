use orchestration_core::device::SandboxKind;
use orchestration_hub::sandbox::{ContainerEngine, ContainerSettings};
use orchestration_node::agent_credentials::{
    API_KEY_VARIABLE, AgentCredential, AgentCredentialKind,
    LONG_LIVED_TOKEN_VARIABLE,
};
use orchestration_node::runner_bridge::{
    choose_container_credential, pass_agent_credential,
};
use orchestration_node::runner_settings::SandboxSettings;
use orchestration_runner::agent_sandbox::AgentSandbox;
use proptest::prelude::*;

use crate::runner_settings_samples::{
    credential_strategy, environment_strategy, sandbox_strategy,
};

const MOST_SANDBOXES: usize = 5;
const HOST_PATTERN: &str = "[a-z]{1,8}\\.com";
const IMAGE_PATTERN: &str = "[a-z]{1,8}:[a-z0-9]{1,4}";

fn sandboxes_strategy() -> impl Strategy<Value = Vec<SandboxSettings>> {
    prop::collection::vec(sandbox_strategy(), 0..MOST_SANDBOXES)
}

fn agent_sandbox_strategy() -> impl Strategy<Value = AgentSandbox> {
    (
        prop_oneof![
            Just(SandboxKind::Container),
            Just(SandboxKind::LocalProcess),
        ],
        IMAGE_PATTERN,
        prop::collection::vec(HOST_PATTERN, 0..3),
        environment_strategy(),
    )
        .prop_map(|(kind, image, allowed_hosts, environment)| {
            AgentSandbox {
                kind,
                container: ContainerSettings {
                    engine: ContainerEngine::Podman,
                    image,
                },
                allowed_hosts,
                environment,
            }
        })
}

fn variable_of(credential: &AgentCredential) -> &'static str {
    match credential.kind() {
        AgentCredentialKind::LongLivedToken => LONG_LIVED_TOKEN_VARIABLE,
        AgentCredentialKind::ApiKey => API_KEY_VARIABLE,
    }
}

fn other_variable_of(credential: &AgentCredential) -> &'static str {
    match credential.kind() {
        AgentCredentialKind::LongLivedToken => API_KEY_VARIABLE,
        AgentCredentialKind::ApiKey => LONG_LIVED_TOKEN_VARIABLE,
    }
}

proptest! {
    #[test]
    fn test_choose_container_credential_property_order_never_matters(
        sandboxes in sandboxes_strategy(),
        credential in credential_strategy(),
    ) {
        let mut reversed = sandboxes.clone();
        reversed.reverse();

        let chosen =
            choose_container_credential(&sandboxes, Some(credential.clone()));
        let chosen_reversed =
            choose_container_credential(&reversed, Some(credential));

        prop_assert_eq!(chosen, chosen_reversed);
    }

    #[test]
    fn test_choose_container_credential_property_no_offer_gets_nothing(
        credential in credential_strategy(),
    ) {
        let chosen = choose_container_credential(&[], Some(credential));

        prop_assert!(chosen.is_none());
    }

    #[test]
    fn test_pass_agent_credential_property_uses_the_variable_of_its_kind(
        sandbox in agent_sandbox_strategy(),
        credential in credential_strategy(),
    ) {
        let mut plain = sandbox;
        plain.kind = SandboxKind::Container;
        plain.environment.remove(LONG_LIVED_TOKEN_VARIABLE);
        plain.environment.remove(API_KEY_VARIABLE);

        let passed = pass_agent_credential(&plain, Some(&credential));

        let named = passed.environment.get(variable_of(&credential));
        prop_assert_eq!(named.map(String::as_str), Some(credential.secret()));
        let other = other_variable_of(&credential);
        prop_assert!(!passed.environment.contains_key(other));
        prop_assert_eq!(passed.environment.len(), plain.environment.len() + 1);
    }

    #[test]
    fn test_pass_agent_credential_property_keeps_every_other_field(
        sandbox in agent_sandbox_strategy(),
        credential in proptest::option::of(credential_strategy()),
    ) {
        let passed = pass_agent_credential(&sandbox, credential.as_ref());

        prop_assert_eq!(passed.kind, sandbox.kind);
        prop_assert_eq!(&passed.container, &sandbox.container);
        prop_assert_eq!(&passed.allowed_hosts, &sandbox.allowed_hosts);
        for (name, value) in &sandbox.environment {
            let is_credential_name = credential
                .as_ref()
                .is_some_and(|known| variable_of(known) == name);
            if !is_credential_name || sandbox.kind != SandboxKind::Container {
                prop_assert_eq!(passed.environment.get(name), Some(value));
            }
        }
    }

    #[test]
    fn test_pass_agent_credential_property_passing_twice_is_passing_once(
        sandbox in agent_sandbox_strategy(),
        credential in proptest::option::of(credential_strategy()),
    ) {
        let passed_once = pass_agent_credential(&sandbox, credential.as_ref());
        let passed_twice =
            pass_agent_credential(&passed_once, credential.as_ref());

        prop_assert_eq!(passed_twice, passed_once);
    }
}
