use std::collections::BTreeSet;

use orchestration_node::live_link_messages::{FileRequest, RunnerMessage};
use proptest::prelude::*;
use serde_json::json;

use crate::file_host_fixture::{
    CRAFTED_FILES, LINK_NAME, MAIN_BRANCH, ODD_BRANCH, ODD_TEXT_NAME,
    file_host,
};
use crate::file_host_steps::{
    ask_raw, entry_names, list_folder, own_repository, read_file,
};
use crate::support::test_device::fail;

const FILE_CASES: u32 = 4;
const README_NAME: &str = "README.md";
const REPLACEMENT_CHARACTER: char = '\u{fffd}';
const UNKNOWN_BRANCH_END: &str = "is not on this runner";
const MISSING_FILE_END: &str = "is not on this branch";
const FOLDER_NOT_FILE: &str = "is a folder, not a file";
const READ_PROBLEM_START: &str = "the runner could not read the repository: ";

fn top_level_names() -> BTreeSet<String> {
    let mut names = BTreeSet::new();
    for (path, _text) in CRAFTED_FILES {
        let first_part = path.split('/').next().unwrap_or(path);
        names.insert(first_part.to_owned());
    }
    names.insert(LINK_NAME.to_owned());
    names.insert(README_NAME.to_owned());
    names
}

fn raw_refusal(request: FileRequest) -> Result<String, TestCaseError> {
    let host = file_host().map_err(fail)?;
    let answer = ask_raw(host, host.client_secret, request).map_err(fail)?;
    match answer {
        RunnerMessage::Refused { reason } => Ok(reason),
        other => Err(fail(format!("not refused: {other:?}"))),
    }
}

fn raw_read(branch: &str, path: &str) -> Result<FileRequest, TestCaseError> {
    let host = file_host().map_err(fail)?;
    Ok(FileRequest::ReadFile {
        repository: own_repository(host).map_err(fail)?,
        branch: branch.to_owned(),
        path: path.to_owned(),
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FILE_CASES))]

    #[test]
    fn test_read_repository_property_the_root_lists_what_was_pushed(
        _seed in any::<u8>(),
    ) {
        let host = file_host().map_err(fail)?;

        let root = list_folder(host, MAIN_BRANCH, "");

        let listed: BTreeSet<String> =
            entry_names(&root).into_iter().collect();
        prop_assert_eq!(listed, top_level_names(), "{}", root);
    }

    #[test]
    fn test_read_repository_property_files_read_back_their_text(
        (path, text) in prop::sample::select(CRAFTED_FILES.to_vec()),
    ) {
        let host = file_host().map_err(fail)?;

        let file = read_file(host, MAIN_BRANCH, path);

        let shown_text = &file["ok"]["preview"]["text"];
        prop_assert_eq!(shown_text, &json!(text), "{}", file);
        prop_assert_eq!(&file["ok"]["path"], &json!(path));
    }

    #[test]
    fn test_read_repository_property_a_link_is_never_followed(
        _seed in any::<u8>(),
    ) {
        let host = file_host().map_err(fail)?;

        let link = read_file(host, MAIN_BRANCH, LINK_NAME);

        let shown_kind = &link["ok"]["preview"]["kind"];
        prop_assert_eq!(shown_kind, &json!("link"), "{}", link);
    }

    #[test]
    fn test_read_repository_property_unreadable_names_are_left_out(
        _seed in any::<u8>(),
    ) {
        let host = file_host().map_err(fail)?;

        let root = list_folder(host, ODD_BRANCH, "");

        let names = entry_names(&root);
        prop_assert!(names.contains(&ODD_TEXT_NAME.to_owned()), "{}", root);
        for name in &names {
            prop_assert!(!name.contains(REPLACEMENT_CHARACTER), "{}", root);
        }
    }

    #[test]
    fn test_node_error_from_property_an_unknown_branch_keeps_the_reason(
        branch in "(--)?[a-z][a-z0-9-]{0,10}",
    ) {
        prop_assume!(branch != MAIN_BRANCH && branch != ODD_BRANCH);

        let reason = raw_refusal(raw_read(&branch, README_NAME)?)?;

        prop_assert!(reason.starts_with(READ_PROBLEM_START), "{}", reason);
        prop_assert!(reason.ends_with(UNKNOWN_BRANCH_END), "{}", reason);
    }

    #[test]
    fn test_node_error_from_property_a_missing_file_keeps_the_reason(
        name in "missing-[a-z]{1,10}\\.txt",
    ) {
        let reason = raw_refusal(raw_read(MAIN_BRANCH, &name)?)?;

        prop_assert!(reason.starts_with(READ_PROBLEM_START), "{}", reason);
        prop_assert!(reason.ends_with(MISSING_FILE_END), "{}", reason);
        prop_assert!(reason.contains(&name), "{}", reason);
    }

    #[test]
    fn test_node_error_from_property_a_folder_is_not_read_as_a_file(
        folder in prop::sample::select(vec!["src", "docs", "deep/a"]),
    ) {
        let reason = raw_refusal(raw_read(MAIN_BRANCH, folder)?)?;

        prop_assert!(reason.starts_with(READ_PROBLEM_START), "{}", reason);
        prop_assert!(reason.ends_with(FOLDER_NOT_FILE), "{}", reason);
    }
}
