use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};

use uuid::Uuid;

use crate::file_removal::remove_file_if_present;

const TEMPORARY_SUFFIX: &str = "incomplete";
#[cfg(unix)]
const CURRENT_FOLDER: &str = ".";

#[must_use]
pub(crate) fn new_file_options() -> OpenOptions {
    let mut open_options = OpenOptions::new();
    open_options.write(true).create_new(true);
    open_options
}

pub(crate) fn replace_file_atomically(
    path: &Path,
    contents: &[u8],
    open_options: &OpenOptions,
) -> std::io::Result<()> {
    let temporary_path = choose_temporary_path(path);
    let replaced =
        write_then_rename(&temporary_path, path, contents, open_options);
    if replaced.is_err() {
        remove_file_if_present(&temporary_path)?;
    }
    replaced
}

fn write_then_rename(
    temporary_path: &Path,
    path: &Path,
    contents: &[u8],
    open_options: &OpenOptions,
) -> std::io::Result<()> {
    let mut temporary_file = open_options.open(temporary_path)?;
    temporary_file.write_all(contents)?;
    temporary_file.sync_all()?;
    fs::rename(temporary_path, path)?;
    sync_parent_folder(path)
}

#[cfg(unix)]
fn sync_parent_folder(path: &Path) -> std::io::Result<()> {
    let parent_folder = match path.parent() {
        Some(folder) if !folder.as_os_str().is_empty() => folder,
        _ => Path::new(CURRENT_FOLDER),
    };
    fs::File::open(parent_folder)?.sync_all()
}

#[cfg(not(unix))]
fn sync_parent_folder(_path: &Path) -> std::io::Result<()> {
    Ok(())
}

fn choose_temporary_path(path: &Path) -> PathBuf {
    let unique_suffix =
        format!("{}.{TEMPORARY_SUFFIX}", Uuid::new_v4().simple());
    path.with_extension(unique_suffix)
}
