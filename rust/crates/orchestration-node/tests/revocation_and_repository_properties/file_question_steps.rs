use std::sync::atomic::{AtomicUsize, Ordering};

use proptest::prelude::*;
use serde_json::{Value, json};

pub const UNEXPECTED_ANSWER_PROBLEM: &str = "the live link message could not \
                                             be read: the runner answered \
                                             another question";
pub const UNIQUE_BRANCH_PATTERN: &str = "branch-[a-z0-9]{16}";
pub const PLACE_PATTERN: &str = "[a-z]{1,8}(/[a-z]{1,8}){0,2}";
pub const SAMPLE_PLACE: &str = "docs";
const UUID_TAIL_PATTERN: &str = "[0-9a-f]{8}";

static ASKED_QUESTIONS: AtomicUsize = AtomicUsize::new(0);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum FileCommandKind {
    ListBranches,
    ListFiles,
    ReadFile,
}

pub const FILE_COMMAND_KINDS: [FileCommandKind; 3] = [
    FileCommandKind::ListBranches,
    FileCommandKind::ListFiles,
    FileCommandKind::ReadFile,
];
pub const RUNNER_COMMAND_KINDS: [FileCommandKind; 2] =
    [FileCommandKind::ListFiles, FileCommandKind::ReadFile];

#[derive(Clone, Copy, Debug)]
pub struct FileQuestion<'question> {
    pub kind: FileCommandKind,
    pub project_id: &'question str,
    pub address: &'question str,
    pub runner_id: &'question str,
    pub branch: &'question str,
    pub place: &'question str,
}

impl FileQuestion<'_> {
    pub fn build_command(&self) -> Value {
        match self.kind {
            FileCommandKind::ListBranches => json!({
                "command": "list_repository_branches",
                "project_id": self.project_id,
                "repository_address": self.address,
                "preferred_runner_id": self.runner_id,
            }),
            FileCommandKind::ListFiles => json!({
                "command": "list_repository_files",
                "project_id": self.project_id,
                "repository_address": self.address,
                "runner_id": self.runner_id,
                "branch": self.branch,
                "folder": self.place,
            }),
            FileCommandKind::ReadFile => json!({
                "command": "read_repository_file",
                "project_id": self.project_id,
                "repository_address": self.address,
                "runner_id": self.runner_id,
                "branch": self.branch,
                "path": self.place,
            }),
        }
    }
}

pub fn read_echoed_address(kind: FileCommandKind, reply: &Value) -> Value {
    match kind {
        FileCommandKind::ListBranches => reply["branches"][0].clone(),
        FileCommandKind::ListFiles => reply["entries"][0]["name"].clone(),
        FileCommandKind::ReadFile => reply["preview"]["text"].clone(),
    }
}

pub fn make_branch_unique(branch: &str) -> String {
    let question_number = ASKED_QUESTIONS.fetch_add(1, Ordering::SeqCst);
    format!("{branch}-{question_number}")
}

pub fn remove_repository_command(project_id: &str, address: &str) -> Value {
    json!({
        "command": "remove_repository",
        "project_id": project_id,
        "address": address,
    })
}

pub fn outside_problem(canonical_address: &str) -> String {
    format!("the repository {canonical_address} is not part of the project")
}

pub fn unknown_project_problem(project_id: &str) -> String {
    format!("project {project_id} was not found")
}

pub fn read_refusal(reply: Result<Value, String>) -> String {
    match reply {
        Ok(answer) => format!("an answer instead of a refusal: {answer}"),
        Err(problem) => problem,
    }
}

pub fn file_command_kind_strategy() -> impl Strategy<Value = FileCommandKind> {
    prop::sample::select(FILE_COMMAND_KINDS.to_vec())
}

pub fn runner_command_kind_strategy() -> impl Strategy<Value = FileCommandKind>
{
    prop::sample::select(RUNNER_COMMAND_KINDS.to_vec())
}

fn build_uuid(tail: &str) -> String {
    format!("00000000-0000-4000-8000-0000{tail}")
}

pub fn unknown_project_strategy() -> impl Strategy<Value = String> {
    UUID_TAIL_PATTERN.prop_map(|tail| build_uuid(&tail))
}
