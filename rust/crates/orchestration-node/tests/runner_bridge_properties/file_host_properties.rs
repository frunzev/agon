use orchestration_core::repository_files::FilePreview;
use orchestration_node::live_link_messages::{
    FileAnswer, FileRequest, RunnerMessage,
};
use proptest::prelude::*;
use serde_json::json;

use crate::file_host_fixture::{
    CRAFTED_FILES, MAIN_BRANCH, ODD_BRANCH, file_host,
};
use crate::file_host_steps::{ask_raw, own_repository, repository_of};
use crate::support::test_device::{describe, fail};

const FILE_CASES: u32 = 6;
const NAME_PATTERN: &str = "[a-z][a-z0-9-]{0,8}";
const LEAVES_REPOSITORY: &str = "leaves the repository";
const ABSOLUTE_PATH: &str = "is absolute";
const UNTRUSTED_WORD: &str = "trusted";
const OUTSIDE_PROJECT: &str = "is not part of the project";
const STRANGER_ADDRESS: &str = "local.test/acme/stranger";

fn hostile_path_strategy() -> impl Strategy<Value = (String, &'static str)> {
    prop_oneof![
        NAME_PATTERN
            .prop_map(|name| (format!("../{name}"), LEAVES_REPOSITORY)),
        NAME_PATTERN.prop_map(|name| (
            format!("{name}/../../{name}"),
            LEAVES_REPOSITORY
        )),
        NAME_PATTERN.prop_map(|name| (format!("/{name}"), ABSOLUTE_PATH)),
        Just(("/etc/passwd".to_owned(), ABSOLUTE_PATH)),
        Just(("..".to_owned(), LEAVES_REPOSITORY)),
    ]
}

fn read_request(
    branch: &str,
    path: &str,
) -> Result<FileRequest, TestCaseError> {
    let host = file_host().map_err(fail)?;
    Ok(FileRequest::ReadFile {
        repository: own_repository(host).map_err(fail)?,
        branch: branch.to_owned(),
        path: path.to_owned(),
    })
}

fn refusal_reason(message: RunnerMessage) -> Result<String, TestCaseError> {
    match message {
        RunnerMessage::Refused { reason } => Ok(reason),
        other => Err(fail(format!("not refused: {other:?}"))),
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FILE_CASES))]

    #[test]
    fn test_answer_file_request_property_a_client_reads_a_pushed_file(
        (path, text) in prop::sample::select(CRAFTED_FILES.to_vec()),
    ) {
        let host = file_host().map_err(fail)?;
        let request = read_request(MAIN_BRANCH, path)?;

        let answer =
            ask_raw(host, host.client_secret, request).map_err(fail)?;

        let RunnerMessage::Answered { answer: FileAnswer::File { file } } =
            answer
        else {
            return Err(fail(format!("{answer:?}")));
        };
        prop_assert_eq!(file.path, path);
        prop_assert_eq!(file.preview, FilePreview::Text { text: text.into() });
    }

    #[test]
    fn test_answer_file_request_property_paths_outside_are_refused(
        (path, expected_reason) in hostile_path_strategy(),
        reads_a_file in any::<bool>(),
    ) {
        let host = file_host().map_err(fail)?;
        let repository = own_repository(host).map_err(fail)?;
        let request = if reads_a_file {
            FileRequest::ReadFile {
                repository,
                branch: MAIN_BRANCH.to_owned(),
                path,
            }
        } else {
            FileRequest::ListFolder {
                repository,
                branch: MAIN_BRANCH.to_owned(),
                folder: path,
            }
        };

        let answer =
            ask_raw(host, host.client_secret, request).map_err(fail)?;

        let reason = refusal_reason(answer)?;
        prop_assert!(reason.contains(expected_reason), "{}", reason);
    }

    #[test]
    fn test_answer_file_request_property_a_stranger_is_refused(
        stranger_secret in any::<[u8; 32]>(),
    ) {
        let host = file_host().map_err(fail)?;
        prop_assume!(stranger_secret != host.client_secret);
        let request = FileRequest::ListBranches {
            repository: own_repository(host).map_err(fail)?,
        };

        let answer = ask_raw(host, stranger_secret, request).map_err(fail)?;

        let reason = refusal_reason(answer)?;
        prop_assert!(reason.contains(UNTRUSTED_WORD), "{}", reason);
    }

    #[test]
    fn test_answer_file_request_property_another_repository_is_refused(
        name in NAME_PATTERN,
    ) {
        let host = file_host().map_err(fail)?;
        let address = format!("{STRANGER_ADDRESS}-{name}");
        let request = FileRequest::ListBranches {
            repository: repository_of(host, &address).map_err(fail)?,
        };

        let answer =
            ask_raw(host, host.client_secret, request).map_err(fail)?;

        let reason = refusal_reason(answer)?;
        prop_assert!(reason.contains(OUTSIDE_PROJECT), "{}", reason);
    }

    #[test]
    fn test_read_cached_clone_property_lists_the_pushed_branches(
        _seed in any::<u8>(),
    ) {
        let host = file_host().map_err(fail)?;
        let request = FileRequest::ListBranches {
            repository: own_repository(host).map_err(fail)?,
        };

        let answer =
            ask_raw(host, host.client_secret, request).map_err(fail)?;

        let RunnerMessage::Answered {
            answer: FileAnswer::Branches { branches },
        } = answer
        else {
            return Err(fail(format!("{answer:?}")));
        };
        prop_assert!(branches.branches.contains(&MAIN_BRANCH.to_owned()));
        prop_assert!(branches.branches.contains(&ODD_BRANCH.to_owned()));
    }

    #[test]
    fn test_read_cached_clone_property_asking_again_answers_the_same(
        (path, _text) in prop::sample::select(CRAFTED_FILES.to_vec()),
    ) {
        let host = file_host().map_err(fail)?;

        let first_request = read_request(MAIN_BRANCH, path)?;
        let second_request = read_request(MAIN_BRANCH, path)?;
        let first = ask_raw(host, host.client_secret, first_request)
            .map_err(fail)?;
        let second = ask_raw(host, host.client_secret, second_request)
            .map_err(fail)?;

        prop_assert_eq!(first, second);
    }

    #[test]
    fn test_read_cached_clone_property_a_project_without_a_copy_says_so(
        name in NAME_PATTERN,
    ) {
        let host = file_host().map_err(fail)?;
        let address = format!("{STRANGER_ADDRESS}-copy-{name}");
        let project = host.nodes.client.run(&json!({
            "command": "create_project",
            "workspace_id": host.nodes.workspace_id,
            "name": format!("copyless-{name}"),
            "repositories": [{
                "address": address,
                "default_branch": MAIN_BRANCH,
                "agent_access": "read_only",
            }],
        }))
        .map_err(fail)?;
        let project_id = serde_json::from_value(project["id"].clone())
            .map_err(describe)
            .map_err(fail)?;
        let mut repository = repository_of(host, &address).map_err(fail)?;
        repository.project_id = project_id;

        let answer = ask_raw(
            host,
            host.client_secret,
            FileRequest::ListBranches { repository },
        )
        .map_err(fail)?;

        let reason = refusal_reason(answer)?;
        prop_assert!(reason.contains("no copy"), "{}", reason);
    }
}
