use std::sync::Arc;

use keyring_core::{CredentialStore, Error as KeychainError};

use super::IdentityStoreError;

pub(super) fn open_platform_store()
-> Result<Arc<CredentialStore>, IdentityStoreError> {
    build_platform_store().map_err(|error| describe_keychain_error(&error))
}

pub(super) fn describe_keychain_error(
    error: &KeychainError,
) -> IdentityStoreError {
    IdentityStoreError::Keychain(error.to_string())
}

#[cfg(target_os = "macos")]
fn build_platform_store() -> Result<Arc<CredentialStore>, KeychainError> {
    let store: Arc<CredentialStore> =
        apple_native_keyring_store::keychain::Store::new()?;
    Ok(store)
}

#[cfg(target_os = "ios")]
fn build_platform_store() -> Result<Arc<CredentialStore>, KeychainError> {
    let store: Arc<CredentialStore> =
        apple_native_keyring_store::protected::Store::new()?;
    Ok(store)
}

#[cfg(target_os = "windows")]
fn build_platform_store() -> Result<Arc<CredentialStore>, KeychainError> {
    let store: Arc<CredentialStore> =
        windows_native_keyring_store::Store::new()?;
    Ok(store)
}

#[cfg(target_os = "linux")]
fn build_platform_store() -> Result<Arc<CredentialStore>, KeychainError> {
    let store: Arc<CredentialStore> =
        zbus_secret_service_keyring_store::Store::new()?;
    Ok(store)
}

#[cfg(not(any(
    target_os = "macos",
    target_os = "ios",
    target_os = "windows",
    target_os = "linux"
)))]
fn build_platform_store() -> Result<Arc<CredentialStore>, KeychainError> {
    Err(KeychainError::NotSupportedByStore(
        "this platform has no keychain; use the encrypted_file store".into(),
    ))
}
