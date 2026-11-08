use std::any::Any;
use std::collections::HashMap;
use std::sync::Arc;

use keyring_core::api::CredentialStoreApi;
use keyring_core::{
    CredentialStore, Entry, Error as KeychainError, Result as KeychainResult,
};
use orchestration_node::identity_store::IdentityStoreError;
use proptest::prelude::*;

const REFUSING_VENDOR: &str = "refusing test keychain";
const PROBLEM_TEXT_PATTERN: &str = "\\PC{1,40}";

#[derive(Debug)]
pub struct RefusingKeychain {
    problem: String,
}

impl CredentialStoreApi for RefusingKeychain {
    fn vendor(&self) -> String {
        REFUSING_VENDOR.to_owned()
    }

    fn id(&self) -> String {
        self.problem.clone()
    }

    fn build(
        &self,
        _service: &str,
        _user: &str,
        _modifiers: Option<&HashMap<&str, &str>>,
    ) -> KeychainResult<Entry> {
        Err(KeychainError::NoStorageAccess(self.problem.clone().into()))
    }

    fn as_any(&self) -> &dyn Any {
        self
    }
}

#[derive(Clone, Debug)]
pub enum InjectedProblem {
    PlatformFailure(String),
    NoStorageAccess(String),
    BadStoreFormat(String),
    Invalid(String, String),
    NotSupportedByStore(String),
    TooLong(String, u32),
}

impl InjectedProblem {
    pub fn to_keychain_error(&self) -> KeychainError {
        match self {
            Self::PlatformFailure(detail) => {
                KeychainError::PlatformFailure(detail.clone().into())
            }
            Self::NoStorageAccess(detail) => {
                KeychainError::NoStorageAccess(detail.clone().into())
            }
            Self::BadStoreFormat(detail) => {
                KeychainError::BadStoreFormat(detail.clone())
            }
            Self::Invalid(attribute, detail) => {
                KeychainError::Invalid(attribute.clone(), detail.clone())
            }
            Self::NotSupportedByStore(detail) => {
                KeychainError::NotSupportedByStore(detail.clone())
            }
            Self::TooLong(attribute, limit) => {
                KeychainError::TooLong(attribute.clone(), *limit)
            }
        }
    }
}

pub fn open_refusing_keychain(problem: &str) -> Arc<CredentialStore> {
    Arc::new(RefusingKeychain {
        problem: problem.to_owned(),
    })
}

pub fn problem_text_strategy() -> impl Strategy<Value = String> {
    PROBLEM_TEXT_PATTERN
}

pub fn injected_problem_strategy() -> impl Strategy<Value = InjectedProblem> {
    prop_oneof![
        problem_text_strategy().prop_map(InjectedProblem::PlatformFailure),
        problem_text_strategy().prop_map(InjectedProblem::NoStorageAccess),
        problem_text_strategy().prop_map(InjectedProblem::BadStoreFormat),
        (problem_text_strategy(), problem_text_strategy()).prop_map(
            |(attribute, detail)| InjectedProblem::Invalid(attribute, detail)
        ),
        problem_text_strategy().prop_map(InjectedProblem::NotSupportedByStore),
        (problem_text_strategy(), any::<u32>()).prop_map(
            |(attribute, limit)| InjectedProblem::TooLong(attribute, limit)
        ),
    ]
}

pub fn read_keychain_message(
    outcome_problem: &IdentityStoreError,
) -> Option<&str> {
    match outcome_problem {
        IdentityStoreError::Keychain(message) => Some(message),
        _ => None,
    }
}
