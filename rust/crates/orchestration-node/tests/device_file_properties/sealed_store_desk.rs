use std::fs;
use std::path::Path;

use orchestration_node::identity_store::EncryptedFileIdentityStore;
use orchestration_security::identity::{
    DeviceIdentity, IDENTITY_SECRET_LENGTH,
};
use proptest::collection::vec;
use proptest::prelude::*;
use proptest::sample::Index;

use crate::device_folder::{DeviceFolder, list_file_names, open_device_files};
use crate::support::test_device::fail;

pub const STORE_KEY_LENGTH: usize = 32;
pub const PEER_SECRET_LENGTH: usize = 32;
pub const SEALED_IDENTITY_FILE_NAME: &str = "device-identity.sealed";
pub const PEER_SECRET_FILE_NAME: &str = "peer-secret.sealed";
pub const AGENT_CREDENTIAL_FILE_NAME: &str = "agent-credential.sealed";
pub const SEALED_CASE_COUNT: u32 = 24;
const SHORTEST_SEARCHABLE_SECRET: usize = 16;
const LONGEST_CREDENTIAL: usize = 2048;
const LONGEST_APPENDED: usize = 32;

pub type StoreKey = [u8; STORE_KEY_LENGTH];
pub type PeerSecretBytes = [u8; PEER_SECRET_LENGTH];

#[derive(Clone, Debug)]
pub enum SealedDamage {
    Truncate(Index),
    Append(Vec<u8>),
    Flip(Index, u8),
}

pub fn open_sealed_store(
    folder: &DeviceFolder,
    key: &StoreKey,
) -> Result<EncryptedFileIdentityStore, TestCaseError> {
    let files = open_device_files(folder)?;
    EncryptedFileIdentityStore::new(files.sealed_identity_path(), key)
        .map_err(fail)
}

pub fn identity_strategy() -> impl Strategy<Value = DeviceIdentity> {
    vec(any::<u8>(), IDENTITY_SECRET_LENGTH)
        .prop_filter_map("the identity is built", |secret| {
            DeviceIdentity::from_secret_bytes(&secret).ok()
        })
}

pub fn distinct_keys_strategy() -> impl Strategy<Value = (StoreKey, StoreKey)>
{
    (any::<StoreKey>(), any::<StoreKey>())
        .prop_filter("the keys differ", |(first, second)| first != second)
}

pub fn credential_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), 0..LONGEST_CREDENTIAL)
}

pub fn searchable_credential_strategy() -> impl Strategy<Value = Vec<u8>> {
    vec(any::<u8>(), SHORTEST_SEARCHABLE_SECRET..LONGEST_CREDENTIAL)
}

pub fn damage_strategy() -> impl Strategy<Value = SealedDamage> {
    prop_oneof![
        any::<Index>().prop_map(SealedDamage::Truncate),
        vec(any::<u8>(), 1..LONGEST_APPENDED).prop_map(SealedDamage::Append),
        (any::<Index>(), 1_u8..=u8::MAX)
            .prop_map(|(position, mask)| SealedDamage::Flip(position, mask)),
    ]
}

pub fn apply_damage(
    sealed_path: &Path,
    damage: &SealedDamage,
) -> Result<(), TestCaseError> {
    let mut sealed_bytes = fs::read(sealed_path).map_err(fail)?;
    match damage {
        SealedDamage::Truncate(cut) => {
            sealed_bytes.truncate(cut.index(sealed_bytes.len()));
        }
        SealedDamage::Append(appended) => {
            sealed_bytes.extend_from_slice(appended);
        }
        SealedDamage::Flip(position, mask) => {
            let flipped = position.index(sealed_bytes.len());
            sealed_bytes[flipped] ^= mask;
        }
    }
    fs::write(sealed_path, sealed_bytes).map_err(fail)
}

fn contains_bytes(haystack: &[u8], needle: &[u8]) -> bool {
    haystack
        .windows(needle.len())
        .any(|window| window == needle)
}

pub fn find_files_holding(
    folder: &Path,
    secret: &[u8],
) -> Result<Vec<String>, TestCaseError> {
    let secret_hex = hex::encode(secret);
    let mut holding_names = Vec::new();
    for name in list_file_names(folder)? {
        let stored_bytes = fs::read(folder.join(&name)).map_err(fail)?;
        let holds_plain = contains_bytes(&stored_bytes, secret);
        let holds_hex = contains_bytes(&stored_bytes, secret_hex.as_bytes());
        if holds_plain || holds_hex {
            holding_names.push(name);
        }
    }
    Ok(holding_names)
}

#[cfg(unix)]
pub fn read_permission_bits(path: &Path) -> Result<u32, TestCaseError> {
    use std::os::unix::fs::PermissionsExt;

    const PERMISSION_BITS: u32 = 0o777;
    let metadata = fs::metadata(path).map_err(fail)?;
    Ok(metadata.permissions().mode() & PERMISSION_BITS)
}
