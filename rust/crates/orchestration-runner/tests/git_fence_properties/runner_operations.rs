use std::path::Path;

use orchestration_runner::branch_pusher::{BranchPusher, GitBranchPusher};
use orchestration_runner::git_command::GitError;
use orchestration_runner::uncommitted_changes::commit_uncommitted_changes;
use orchestration_runner::unpushed_commits::list_unpushed_commit_subjects;
use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use tokio::runtime::Runtime;

use crate::outer_guard::fail;

pub type GitOutcome<Value> = Result<Value, GitError>;

pub const CHANGE_SUBJECT: &str = "build: changes from Codex";

const TASK_BRANCH: &str = "task/fenced-push";

#[derive(Clone, Copy, Debug)]
pub enum RunnerGitOperation {
    CommitChanges,
    ListUnpushedCommits,
    PushBranch,
}

pub fn operation_strategy() -> impl Strategy<Value = RunnerGitOperation> {
    prop_oneof![
        Just(RunnerGitOperation::CommitChanges),
        Just(RunnerGitOperation::ListUnpushedCommits),
        Just(RunnerGitOperation::PushBranch),
    ]
}

pub fn commit_changes(folder: &Path) -> Result<GitOutcome<()>, TestCaseError> {
    let runtime = Runtime::new().map_err(fail)?;
    let committing = commit_uncommitted_changes(folder, CHANGE_SUBJECT);
    Ok(runtime.block_on(committing))
}

pub fn list_unpushed_commits(
    folder: &Path,
) -> Result<GitOutcome<Vec<String>>, TestCaseError> {
    let runtime = Runtime::new().map_err(fail)?;
    Ok(runtime.block_on(list_unpushed_commit_subjects(folder)))
}

pub fn push_task_branch(
    folder: &Path,
) -> Result<GitOutcome<()>, TestCaseError> {
    let runtime = Runtime::new().map_err(fail)?;
    let pushing = GitBranchPusher.push_branch(folder, TASK_BRANCH);
    Ok(runtime.block_on(pushing))
}

pub fn run_operation(
    operation: RunnerGitOperation,
    folder: &Path,
) -> Result<GitOutcome<()>, TestCaseError> {
    match operation {
        RunnerGitOperation::CommitChanges => commit_changes(folder),
        RunnerGitOperation::ListUnpushedCommits => {
            let listing = list_unpushed_commits(folder)?;
            Ok(listing.map(drop))
        }
        RunnerGitOperation::PushBranch => push_task_branch(folder),
    }
}
