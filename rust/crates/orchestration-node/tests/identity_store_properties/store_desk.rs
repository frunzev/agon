use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;

use keyring_core::{CredentialStore, Entry, Error as KeychainError, mock};
use orchestration_node::identity_store::{
    FileIdentityStore, KeychainIdentityStore, PEER_SECRET_LENGTH,
};
use orchestration_security::identity::{
    DeviceIdentity, IDENTITY_SECRET_LENGTH,
};
use proptest::collection::vec;
use proptest::prelude::*;
use tempfile::{Builder, TempDir};

use crate::support::test_device::fail;

const TARGET_TEMPORARY_FOLDER: &str = env!("CARGO_TARGET_TMPDIR");
const CASE_FOLDER_PREFIX: &str = "identity-store-";
const LONGEST_CREDENTIAL: usize = 4096;
const SERVICE_NAME_PATTERN: &str = "\\PC{0,24}";
pub const IDENTITY_FILE_NAME: &str = "device-identity.key";
pub const PEER_SECRET_FILE_NAME: &str = "peer-secret.key";
pub const AGENT_CREDENTIAL_FILE_NAME: &str = "agent-credential.key";
pub const UNFINISHED_FILE_SUFFIX: &str = ".incomplete";
pub const STORE_CASE_COUNT: u32 = 24;
pub const TEST_SERVICE_NAME: &str = "agents-orchestration-tests";

pub type PeerSecretBytes = [u8; PEER_SECRET_LENGTH];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SecretKind {
    Identity,
    PeerSecret,
    AgentCredential,
}

pub const SECRET_KINDS: [SecretKind; 3] = [
    SecretKind::Identity,
    SecretKind::PeerSecret,
    SecretKind::AgentCredential,
];

impl SecretKind {
    pub fn file_name(self) -> &'static str {
        match self {
            Self::Identity => IDENTITY_FILE_NAME,
            Self::PeerSecret => PEER_SECRET_FILE_NAME,
            Self::AgentCredential => AGENT_CREDENTIAL_FILE_NAME,
        }
    }

    pub fn account_name(self) -> &'static str {
        match self {
            Self::Identity => "device-identity",
            Self::PeerSecret => "peer-secret",
            Self::AgentCredential => "agent-credential",
        }
    }
}

#[derive(Debug)]
pub struct FileDesk {
    pub folder: TempDir,
    pub store: FileIdentityStore,
}

impl FileDesk {
    pub fn path_of(&self, kind: SecretKind) -> PathBuf {
        self.folder.path().join(kind.file_name())
    }

    pub fn plant(
        &self,
        kind: SecretKind,
        stored_bytes: &[u8],
    ) -> Result<(), TestCaseError> {
        fs::write(self.path_of(kind), stored_bytes).map_err(fail)
    }
}

#[derive(Debug)]
pub struct KeychainDesk {
    pub credential_store: Arc<CredentialStore>,
    pub service_name: String,
    pub store: KeychainIdentityStore,
}

impl KeychainDesk {
    pub fn entry_of(&self, kind: SecretKind) -> Result<Entry, TestCaseError> {
        self.credential_store
            .build(&self.service_name, kind.account_name(), None)
            .map_err(fail)
    }

    pub fn plant(
        &self,
        kind: SecretKind,
        stored_bytes: &[u8],
    ) -> Result<(), TestCaseError> {
        self.entry_of(kind)?.set_secret(stored_bytes).map_err(fail)
    }

    pub fn read_planted(
        &self,
        kind: SecretKind,
    ) -> Result<Option<Vec<u8>>, TestCaseError> {
        match self.entry_of(kind)?.get_secret() {
            Ok(stored_bytes) => Ok(Some(stored_bytes)),
            Err(KeychainError::NoEntry) => Ok(None),
            Err(error) => Err(fail(error)),
        }
    }

    pub fn fail_next_call(
        &self,
        kind: SecretKind,
        problem: KeychainError,
    ) -> Result<(), TestCaseError> {
        let entry = self.entry_of(kind)?;
        let Some(mock_credential) =
            entry.as_any().downcast_ref::<mock::Cred>()
        else {
            return Err(fail("the entry is not a mock credential"));
        };
        mock_credential.set_error(problem);
        Ok(())
    }
}

pub fn create_case_folder() -> Result<TempDir, TestCaseError> {
    fs::create_dir_all(TARGET_TEMPORARY_FOLDER).map_err(fail)?;
    Builder::new()
        .prefix(CASE_FOLDER_PREFIX)
        .tempdir_in(TARGET_TEMPORARY_FOLDER)
        .map_err(fail)
}

pub fn open_file_desk() -> Result<FileDesk, TestCaseError> {
    let folder = create_case_folder()?;
    let store = FileIdentityStore::new(folder.path().join(IDENTITY_FILE_NAME));
    Ok(FileDesk { folder, store })
}

pub fn open_mock_keychain() -> Result<Arc<CredentialStore>, TestCaseError> {
    let credential_store: Arc<CredentialStore> =
        mock::Store::new().map_err(fail)?;
    Ok(credential_store)
}

pub fn open_keychain_desk(
    service_name: &str,
) -> Result<KeychainDesk, TestCaseError> {
    let credential_store = open_mock_keychain()?;
    let store =
        KeychainIdentityStore::new(service_name, credential_store.clone());
    Ok(KeychainDesk {
        credential_store,
        service_name: service_name.to_owned(),
        store,
    })
}

pub fn identity_strategy() -> impl Strategy<Value = DeviceIdentity> {
    vec(any::<u8>(), IDENTITY_SECRET_LENGTH)
        .prop_filter_map("the identity is built", |secret| {
            DeviceIdentity::from_secret_bytes(&secret).ok()
        })
}

pub fn peer_secret_strategy() -> impl Strategy<Value = PeerSecretBytes> {
    any::<PeerSecretBytes>()
}

pub fn credential_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..LONGEST_CREDENTIAL)
}

pub fn wrong_length_strategy(
    right_length: usize,
) -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..right_length * 2)
        .prop_filter("the length is wrong", move |stored_bytes| {
            stored_bytes.len() != right_length
        })
}

pub fn service_name_strategy() -> impl Strategy<Value = String> {
    SERVICE_NAME_PATTERN
}

pub fn list_file_names(folder: &Path) -> Result<Vec<String>, TestCaseError> {
    let mut names = Vec::new();
    for entry in fs::read_dir(folder).map_err(fail)? {
        let entry = entry.map_err(fail)?;
        names.push(entry.file_name().to_string_lossy().into_owned());
    }
    names.sort();
    Ok(names)
}

#[cfg(unix)]
pub fn read_permission_bits(path: &Path) -> Result<u32, TestCaseError> {
    use std::os::unix::fs::PermissionsExt;

    const PERMISSION_BITS: u32 = 0o777;
    let metadata = fs::metadata(path).map_err(fail)?;
    Ok(metadata.permissions().mode() & PERMISSION_BITS)
}
