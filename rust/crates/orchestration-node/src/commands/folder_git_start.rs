use std::path::Path;

use orchestration_core::git_ceiling::{
    GIT_CEILING_VARIABLE, name_git_ceiling,
};

use crate::node_error::NodeError;

const GIT_PROGRAM: &str = "git";
pub(super) const OWN_REPOSITORY_OPTION: &str = "--git-dir=.git";
const FIRST_BRANCH_REFERENCE: &str = "refs/heads/main";
const FIRST_COMMIT_SUBJECT_START: &str = "Start";
const CONFIGURATION_OPTION: &str = "-c";
const FALLBACK_IDENTITY: [(&str, &str); 2] = [
    ("user.name", "Agon"),
    ("user.email", "agon@agents-orchestration.invalid"),
];

pub(crate) fn start_git_when_missing(
    folder: &Path,
) -> Result<bool, NodeError> {
    if !has_own_repository(folder)? {
        run_git(folder, &["init", "--quiet"])?;
    }
    if has_commits(folder)? {
        return Ok(false);
    }
    make_first_commit(folder)?;
    Ok(true)
}

pub(super) fn has_own_repository(folder: &Path) -> Result<bool, NodeError> {
    let own_check =
        start_git(folder, &[OWN_REPOSITORY_OPTION, "rev-parse", "--git-dir"])?;
    Ok(own_check.has_succeeded)
}

fn has_commits(folder: &Path) -> Result<bool, NodeError> {
    let head_check =
        start_git(folder, &["rev-parse", "--verify", "--quiet", "HEAD"])?;
    let branch_check = start_git(folder, &["show-ref", "--heads", "--quiet"])?;
    Ok(head_check.has_succeeded || branch_check.has_succeeded)
}

fn make_first_commit(folder: &Path) -> Result<(), NodeError> {
    run_git(folder, &["symbolic-ref", "HEAD", FIRST_BRANCH_REFERENCE])?;
    run_git(folder, &["add", "--all"])?;

    let folder_name = folder.file_name().unwrap_or(folder.as_os_str());
    let subject = format!(
        "{FIRST_COMMIT_SUBJECT_START} {}",
        folder_name.to_string_lossy()
    );
    let mut arguments = list_missing_identity_settings(folder)?;
    arguments.extend([
        "commit".to_owned(),
        "--quiet".to_owned(),
        "--allow-empty".to_owned(),
        "--message".to_owned(),
        subject,
    ]);
    run_git(folder, &arguments)
}

fn list_missing_identity_settings(
    folder: &Path,
) -> Result<Vec<String>, NodeError> {
    let mut settings = Vec::new();
    for (key, fallback_value) in FALLBACK_IDENTITY {
        let configured = start_git(folder, &["config", "--get", key])?;
        if !configured.has_succeeded {
            settings.push(CONFIGURATION_OPTION.to_owned());
            settings.push(format!("{key}={fallback_value}"));
        }
    }
    Ok(settings)
}

pub(super) struct GitAnswer {
    pub(super) has_succeeded: bool,
    pub(super) output: String,
    errors: String,
}

fn run_git<Argument: AsRef<str>>(
    folder: &Path,
    arguments: &[Argument],
) -> Result<(), NodeError> {
    let answer = start_git(folder, arguments)?;
    if answer.has_succeeded {
        return Ok(());
    }
    Err(describe_git_problem(folder, answer.errors.trim()))
}

#[cfg(unix)]
pub(super) fn start_git<Argument: AsRef<str>>(
    folder: &Path,
    arguments: &[Argument],
) -> Result<GitAnswer, NodeError> {
    let owned_arguments: Vec<String> = arguments
        .iter()
        .map(|argument| argument.as_ref().to_owned())
        .collect();
    let outcome = crate::reaper_safe_program::run_program(
        GIT_PROGRAM,
        &owned_arguments,
        &list_fence_variables(folder),
        folder,
    )
    .map_err(|error| describe_git_problem(folder, &error.to_string()))?;
    Ok(GitAnswer {
        has_succeeded: outcome.has_succeeded(),
        output: outcome.output,
        errors: outcome.errors,
    })
}

#[cfg(not(unix))]
pub(super) fn start_git<Argument: AsRef<str>>(
    folder: &Path,
    arguments: &[Argument],
) -> Result<GitAnswer, NodeError> {
    let output = std::process::Command::new(GIT_PROGRAM)
        .args(arguments.iter().map(AsRef::as_ref))
        .envs(list_fence_variables(folder))
        .current_dir(folder)
        .output()
        .map_err(|error| describe_git_problem(folder, &error.to_string()))?;
    Ok(GitAnswer {
        has_succeeded: output.status.success(),
        output: String::from_utf8_lossy(&output.stdout).into_owned(),
        errors: String::from_utf8_lossy(&output.stderr).into_owned(),
    })
}

fn list_fence_variables(folder: &Path) -> Vec<(&'static str, String)> {
    let mut fence_variables = Vec::new();
    if let Some(ceiling) = name_git_ceiling(folder) {
        fence_variables.push((GIT_CEILING_VARIABLE, ceiling));
    }
    fence_variables
}

fn describe_git_problem(folder: &Path, problem: &str) -> NodeError {
    NodeError::GitNotStarted {
        folder: folder.display().to_string(),
        problem: problem.to_owned(),
    }
}
