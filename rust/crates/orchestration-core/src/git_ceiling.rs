use std::path::Path;

pub const GIT_CEILING_VARIABLE: &str = "GIT_CEILING_DIRECTORIES";

#[must_use]
pub fn name_git_ceiling(folder: &Path) -> Option<String> {
    let enclosing_folder = folder.parent()?;
    Some(enclosing_folder.display().to_string())
}
