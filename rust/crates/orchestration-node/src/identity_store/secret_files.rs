use std::fs::{self, OpenOptions};
use std::io::ErrorKind;
use std::path::Path;

use zeroize::Zeroizing;

use super::IdentityStoreError;
use crate::file_removal::remove_file_if_present;
use crate::file_replacement::{new_file_options, replace_file_atomically};

#[cfg(unix)]
const OWNER_ONLY_MODE: u32 = 0o600;

pub(super) fn read_secret_file(
    path: &Path,
) -> Result<Option<Zeroizing<Vec<u8>>>, IdentityStoreError> {
    match fs::read(path) {
        Ok(secret_bytes) => Ok(Some(Zeroizing::new(secret_bytes))),
        Err(error) if error.kind() == ErrorKind::NotFound => Ok(None),
        Err(error) => Err(IdentityStoreError::File(error)),
    }
}

pub(super) fn remove_secret_file(
    path: &Path,
) -> Result<(), IdentityStoreError> {
    remove_file_if_present(path).map_err(IdentityStoreError::File)
}

pub(super) fn write_secret_file(
    path: &Path,
    secret: &[u8],
) -> Result<(), IdentityStoreError> {
    replace_file_atomically(path, secret, &owner_only_file_options())?;
    Ok(())
}

#[cfg(unix)]
fn owner_only_file_options() -> OpenOptions {
    use std::os::unix::fs::OpenOptionsExt;

    let mut open_options = new_file_options();
    open_options.mode(OWNER_ONLY_MODE);
    open_options
}

#[cfg(not(unix))]
fn owner_only_file_options() -> OpenOptions {
    new_file_options()
}
