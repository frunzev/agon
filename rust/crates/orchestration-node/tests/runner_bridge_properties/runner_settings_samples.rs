use std::collections::BTreeMap;
use std::path::PathBuf;

use orchestration_core::agent_place::AgentPlace;
use orchestration_node::agent_credentials::{
    AgentCredential, AgentCredentialKind,
};
use orchestration_node::runner_settings::{
    ContainerEngineChoice, RunnerSettings, SandboxSettings,
};
use proptest::collection::{btree_map, vec};
use proptest::prelude::*;

pub const DATA_FOLDER_NAME: &str = "runner-bridge-properties";
const VARIABLE_NAME_PATTERN: &str = "[A-Z][A-Z0-9_]{1,16}";
const VARIABLE_VALUE_PATTERN: &str = "\\PC{0,24}";
const IMAGE_PATTERN: &str = "[a-z][a-z0-9-]{0,12}:[a-z0-9]{1,6}";
const HOST_PATTERN: &str = "[a-z]{1,8}\\.(com|dev|io)";
const LABEL_PATTERN: &str = "[a-z0-9]{1,8}";
const TEMPLATE_PATTERN: &str = "(file|https)://[a-z/]{1,12}\\{address\\}";
const SECRET_PATTERN: &str = "sk-ant-[A-Za-z0-9_-]{8,40}";
const MOST_HOSTS: usize = 4;
const MOST_LABELS: usize = 4;
const MOST_VARIABLES: usize = 8;
const MOST_OFFERS: usize = 6;
const MOST_SLOTS: u32 = 16;

pub type ProcessEnvironment = BTreeMap<String, String>;

pub fn data_directory() -> PathBuf {
    PathBuf::from(env!("CARGO_TARGET_TMPDIR")).join(DATA_FOLDER_NAME)
}

pub fn place_strategy() -> impl Strategy<Value = AgentPlace> {
    prop_oneof![Just(AgentPlace::LocalProcess), Just(AgentPlace::Container)]
}

pub fn offers_strategy() -> impl Strategy<Value = Vec<AgentPlace>> {
    vec(place_strategy(), 0..MOST_OFFERS)
}

pub fn engine_strategy() -> impl Strategy<Value = ContainerEngineChoice> {
    prop_oneof![
        Just(ContainerEngineChoice::Docker),
        Just(ContainerEngineChoice::Podman),
    ]
}

pub fn container_strategy() -> impl Strategy<Value = SandboxSettings> {
    (
        engine_strategy(),
        IMAGE_PATTERN,
        vec(HOST_PATTERN, 0..MOST_HOSTS),
    )
        .prop_map(|(engine, image, allowed_hosts)| {
            SandboxSettings::Container {
                engine,
                image,
                allowed_hosts,
            }
        })
}

pub fn sandbox_strategy() -> impl Strategy<Value = SandboxSettings> {
    prop_oneof![Just(SandboxSettings::LocalProcess), container_strategy()]
}

pub fn environment_strategy() -> impl Strategy<Value = ProcessEnvironment> {
    btree_map(
        VARIABLE_NAME_PATTERN,
        VARIABLE_VALUE_PATTERN,
        0..MOST_VARIABLES,
    )
}

pub fn settings_strategy() -> impl Strategy<Value = RunnerSettings> {
    (
        vec(LABEL_PATTERN, 0..MOST_LABELS),
        1..MOST_SLOTS,
        sandbox_strategy(),
        proptest::option::of(TEMPLATE_PATTERN),
    )
        .prop_map(|(labels, slot_capacity, sandbox, template)| {
            RunnerSettings {
                labels,
                slot_capacity,
                sandbox,
                clone_url_template: template,
                passed_environment: Vec::new(),
            }
        })
}

pub fn credential_strategy() -> impl Strategy<Value = AgentCredential> {
    (
        prop_oneof![
            Just(AgentCredentialKind::LongLivedToken),
            Just(AgentCredentialKind::ApiKey),
        ],
        SECRET_PATTERN,
    )
        .prop_filter_map("the secret is valid", |(kind, secret)| {
            AgentCredential::new(kind, &secret).ok()
        })
}
