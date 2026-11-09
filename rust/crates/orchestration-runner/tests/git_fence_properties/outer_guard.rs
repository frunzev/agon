use std::collections::BTreeMap;
use std::fmt::Display;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

use orchestration_core::git_ceiling::GIT_CEILING_VARIABLE;
use proptest::prelude::*;
use proptest::test_runner::TestCaseError;
use tempfile::TempDir;

pub type FolderFiles = BTreeMap<String, String>;

pub const GUARD_WORK_SUBJECT: &str = "Guard work";
pub const NESTED_START_SUBJECT: &str = "Nested start";
pub const FENCE_CASES: u32 = 6;

const CASE_ROOT: &str = env!("CARGO_TARGET_TMPDIR");
const CASE_FOLDER_PREFIX: &str = "runner-git-fence-";
const GUARD_FOLDER_NAME: &str = "guard";
const ORIGIN_FOLDER_NAME: &str = "origin.git";
const GIT_FOLDER_NAME: &str = ".git";
const STEP_FOLDER_NAME: &str = "step";
const PARENT_STEP: &str = "..";
const GIT_PROGRAM: &str = "git";
const REMOTE_NAME: &str = "origin";
const REFERENCE_FORMAT: &str = "--format=%(refname) %(objectname)";
const GIT_TEST_SETTINGS: [&str; 10] = [
    "-c",
    "user.name=Guard Keeper",
    "-c",
    "user.email=guard@example.invalid",
    "-c",
    "commit.gpgsign=false",
    "-c",
    "core.hooksPath=/dev/null",
    "-c",
    "init.defaultBranch=main",
];
const TRACKED_FILE: (&str, &str) = ("tracked.txt", "committed by the guard\n");
const WORK_FILE: (&str, &str) = ("work.txt", "unpushed guard work\n");
const EDITED_TRACKED_TEXT: &str = "edited but never committed\n";
const STAGED_FILE: (&str, &str) = ("staged.txt", "staged in the guard\n");
const UNTRACKED_FILE: (&str, &str) = ("untracked.txt", "left untracked\n");
const BROKEN_GIT_LINK: &str = "gitdir: missing-repository\n";
const FOLDER_NAME_PATTERN: &str = "[a-z\u{e9}][a-z0-9 \u{e9}-]{0,8}";
const FILE_NAME_PATTERN: &str = "[a-z]{1,6}\\.md";
const FILE_TEXT_PATTERN: &str = "[a-z \u{e9}\u{4e2d}]{0,16}";
const MOST_FILES: usize = 3;

#[derive(Clone, Copy, Debug)]
pub enum FolderShape {
    WithoutRepository,
    ReachedThroughParentStep,
    EmptyGitFolder,
    BrokenGitLink,
    OwnRepository,
}

#[derive(Debug, PartialEq, Eq)]
pub struct GuardState {
    head: String,
    references: String,
    index: String,
    status: String,
    changes: String,
    origin_references: String,
}

#[derive(Debug)]
pub struct OuterGuard {
    case_root: TempDir,
    pub repository: PathBuf,
    pub working_folder: PathBuf,
    origin: PathBuf,
}

pub fn fail(problem: impl Display) -> TestCaseError {
    TestCaseError::fail(problem.to_string())
}

pub fn folder_name_strategy() -> impl Strategy<Value = String> {
    FOLDER_NAME_PATTERN
}

pub fn folder_files_strategy() -> impl Strategy<Value = FolderFiles> {
    prop::collection::btree_map(
        FILE_NAME_PATTERN,
        FILE_TEXT_PATTERN,
        0..=MOST_FILES,
    )
}

pub fn shape_without_git_strategy() -> impl Strategy<Value = FolderShape> {
    prop_oneof![
        Just(FolderShape::WithoutRepository),
        Just(FolderShape::ReachedThroughParentStep),
    ]
}

pub fn refused_shape_strategy() -> impl Strategy<Value = FolderShape> {
    prop_oneof![
        Just(FolderShape::WithoutRepository),
        Just(FolderShape::ReachedThroughParentStep),
        Just(FolderShape::EmptyGitFolder),
        Just(FolderShape::BrokenGitLink),
    ]
}

impl OuterGuard {
    pub fn build(
        folder_name: &str,
        files: &FolderFiles,
        shape: FolderShape,
    ) -> Result<Self, TestCaseError> {
        fs::create_dir_all(CASE_ROOT).map_err(fail)?;
        let case_root = tempfile::Builder::new()
            .prefix(CASE_FOLDER_PREFIX)
            .tempdir_in(CASE_ROOT)
            .map_err(fail)?;
        let repository = case_root.path().join(GUARD_FOLDER_NAME);
        let origin = case_root.path().join(ORIGIN_FOLDER_NAME);
        let chosen_folder = repository.join(folder_name);
        let working_folder = match shape {
            FolderShape::ReachedThroughParentStep => {
                chosen_folder.join(STEP_FOLDER_NAME).join(PARENT_STEP)
            }
            _ => chosen_folder.clone(),
        };
        let guard = Self {
            case_root,
            repository,
            working_folder,
            origin,
        };

        guard.start_guard_repository()?;
        guard.leave_guard_changes()?;
        guard.shape_chosen_folder(&chosen_folder, files, shape)?;
        Ok(guard)
    }

    pub fn read_state(&self) -> Result<GuardState, TestCaseError> {
        let repository = &self.repository;
        let status_arguments =
            ["status", "--porcelain", "--untracked-files=all"];

        let head = self.run_git(repository, &["rev-parse", "HEAD"])?;
        let references =
            self.run_git(repository, &["for-each-ref", REFERENCE_FORMAT])?;
        let index = self.run_git(repository, &["ls-files", "--stage"])?;
        let status = self.run_git(repository, &status_arguments)?;
        let changes = self.run_git(repository, &["diff", "HEAD"])?;
        let origin_references =
            self.run_git(&self.origin, &["for-each-ref", REFERENCE_FORMAT])?;
        Ok(GuardState {
            head,
            references,
            index,
            status,
            changes,
            origin_references,
        })
    }

    pub fn list_subjects(
        &self,
        folder: &Path,
    ) -> Result<Vec<String>, TestCaseError> {
        let subjects = self.run_git(folder, &["log", "--format=%s"])?;
        Ok(subjects.lines().map(ToString::to_string).collect())
    }

    fn run_git(
        &self,
        folder: &Path,
        arguments: &[&str],
    ) -> Result<String, TestCaseError> {
        let output = Command::new(GIT_PROGRAM)
            .args(GIT_TEST_SETTINGS)
            .args(arguments)
            .env(GIT_CEILING_VARIABLE, self.case_root.path())
            .current_dir(folder)
            .output()
            .map_err(fail)?;
        if !output.status.success() {
            return Err(fail(String::from_utf8_lossy(&output.stderr)));
        }
        Ok(String::from_utf8_lossy(&output.stdout).into_owned())
    }

    fn start_guard_repository(&self) -> Result<(), TestCaseError> {
        let repository = &self.repository;
        fs::create_dir_all(repository).map_err(fail)?;
        self.run_git(repository, &["init", "--quiet"])?;
        self.commit_file(TRACKED_FILE, "Guard start")?;

        let repository_text = repository.display().to_string();
        let origin_text = self.origin.display().to_string();
        let clone_arguments =
            ["clone", "--quiet", "--bare", &repository_text, &origin_text];
        self.run_git(self.case_root.path(), &clone_arguments)?;
        let remote_arguments = ["remote", "add", REMOTE_NAME, &origin_text];
        self.run_git(repository, &remote_arguments)?;
        self.run_git(repository, &["fetch", "--quiet", REMOTE_NAME])?;
        self.commit_file(WORK_FILE, GUARD_WORK_SUBJECT)
    }

    fn leave_guard_changes(&self) -> Result<(), TestCaseError> {
        let repository = &self.repository;
        fs::write(repository.join(TRACKED_FILE.0), EDITED_TRACKED_TEXT)
            .map_err(fail)?;
        fs::write(repository.join(STAGED_FILE.0), STAGED_FILE.1)
            .map_err(fail)?;
        self.run_git(repository, &["add", STAGED_FILE.0])?;
        fs::write(repository.join(UNTRACKED_FILE.0), UNTRACKED_FILE.1)
            .map_err(fail)
    }

    fn commit_file(
        &self,
        file: (&str, &str),
        subject: &str,
    ) -> Result<(), TestCaseError> {
        let (file_name, file_text) = file;
        fs::write(self.repository.join(file_name), file_text).map_err(fail)?;
        self.run_git(&self.repository, &["add", file_name])?;
        let commit_arguments = ["commit", "--quiet", "-m", subject];
        self.run_git(&self.repository, &commit_arguments)?;
        Ok(())
    }

    fn shape_chosen_folder(
        &self,
        chosen_folder: &Path,
        files: &FolderFiles,
        shape: FolderShape,
    ) -> Result<(), TestCaseError> {
        fs::create_dir_all(chosen_folder.join(STEP_FOLDER_NAME))
            .map_err(fail)?;
        for (file_name, file_text) in files {
            fs::write(chosen_folder.join(file_name), file_text)
                .map_err(fail)?;
        }

        let git_folder = chosen_folder.join(GIT_FOLDER_NAME);
        match shape {
            FolderShape::WithoutRepository
            | FolderShape::ReachedThroughParentStep => Ok(()),
            FolderShape::EmptyGitFolder => {
                fs::create_dir(git_folder).map_err(fail)
            }
            FolderShape::BrokenGitLink => {
                fs::write(git_folder, BROKEN_GIT_LINK).map_err(fail)
            }
            FolderShape::OwnRepository => {
                self.start_nested_repository(chosen_folder)
            }
        }
    }

    fn start_nested_repository(
        &self,
        chosen_folder: &Path,
    ) -> Result<(), TestCaseError> {
        self.run_git(chosen_folder, &["init", "--quiet"])?;
        let commit_arguments = [
            "commit",
            "--quiet",
            "--allow-empty",
            "-m",
            NESTED_START_SUBJECT,
        ];
        self.run_git(chosen_folder, &commit_arguments)?;
        Ok(())
    }
}
