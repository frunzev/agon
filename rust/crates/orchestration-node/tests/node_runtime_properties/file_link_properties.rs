use orchestration_api::work::RunEvent;
use orchestration_core::repository_files::{
    FilePreview, RepositoryEntry, RepositoryEntryKind, RepositoryFile,
};
use orchestration_node::live_link_messages::{
    ClientMessage, FileAnswer, FileRequest, RunnerMessage,
};
use proptest::collection::vec;
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::fake_runner::RunnerAnswer;
use crate::file_questions::{FILE_LISTING_NAMES, file_question};
use crate::forged_workspace::{
    HolderDesk, TAMPERINGS, UNTRUSTED_ADDRESS_END, open_holder_desk,
};
use crate::support::test_device::{fail, read_text};

const FILE_CASES: u32 = 2;
const MOST_ENTRIES: usize = 4;
const FILE_REFUSAL_START: &str = "the runner refused to show the files: ";
const CLOSED_LINK_REASON: &str = "the runner closed the link";
const ANSWER_WITHOUT_FILES: &str = "the live link message could not be read: \
     the runner answered without files";
const ASKED_PATH: &str = "README.md";
const ASKED_BRANCH: &str = "main";

fn read_project_address(desk: &HolderDesk) -> Result<String, String> {
    let workspace = &desk.workspace;
    let views = workspace.device.run(&json!({
        "command": "list_projects",
        "workspace_id": workspace.workspace_id,
    }))?;
    read_text(&views, "/0/project/repositories/0/address")
}

fn ask_holder(desk: &HolderDesk, command: &str) -> Result<Value, String> {
    let workspace = &desk.workspace;
    let question = file_question(
        command,
        &workspace.project_id,
        &read_project_address(desk)?,
        &desk.holder_id,
    );
    workspace.device.run(&question)
}

fn repository_file_strategy() -> impl Strategy<Value = RepositoryFile> {
    (
        "[a-z]{1,8}(/[a-z]{1,8}){0,2}\\.md",
        any::<u64>(),
        "\\PC{0,40}",
    )
        .prop_map(|(path, size, text)| RepositoryFile {
            path,
            size,
            preview: FilePreview::Text { text },
        })
}

fn repository_entry_strategy() -> impl Strategy<Value = RepositoryEntry> {
    let kinds = vec![
        RepositoryEntryKind::Folder,
        RepositoryEntryKind::File,
        RepositoryEntryKind::Link,
    ];
    (
        "[a-z]{1,10}",
        prop::sample::select(kinds),
        any::<Option<u64>>(),
    )
        .prop_map(|(name, kind, size)| RepositoryEntry {
            name,
            kind,
            size,
        })
}

fn answer_without_files_strategy() -> impl Strategy<Value = RunnerMessage> {
    prop_oneof![
        Just(RunnerMessage::Accepted),
        Just(RunnerMessage::Events { events: Vec::new() }),
        Just(RunnerMessage::Events {
            events: vec![RunEvent::Finished],
        }),
    ]
}

fn file_command_strategy() -> impl Strategy<Value = &'static str> {
    prop::sample::select(FILE_LISTING_NAMES.to_vec())
}

fn read_asked_requests(desk: &HolderDesk) -> Vec<FileRequest> {
    let mut requests = Vec::new();
    for message in desk.fake_runner.received() {
        if let ClientMessage::Browse { request } = message {
            requests.push(request);
        }
    }
    requests
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FILE_CASES))]

    #[test]
    fn test_ask_runner_for_files_property_returns_the_runner_file(
        file in repository_file_strategy(),
    ) {
        let answer = RunnerMessage::Answered {
            answer: FileAnswer::File { file: file.clone() },
        };
        let desk =
            open_holder_desk(RunnerAnswer::Reply(answer)).map_err(fail)?;

        let shown = ask_holder(&desk, FILE_LISTING_NAMES[1]).map_err(fail)?;

        let expected = serde_json::to_value(&file).map_err(fail)?;
        prop_assert_eq!(shown, expected);
        let requests = read_asked_requests(&desk);
        prop_assert_eq!(requests.len(), 1);
        let FileRequest::ReadFile { repository, branch, path } =
            &requests[0]
        else {
            return Err(TestCaseError::fail("the runner was not asked a file"));
        };
        prop_assert_eq!(&repository.project_id.0.to_string(),
            &desk.workspace.project_id);
        prop_assert_eq!(branch, ASKED_BRANCH);
        prop_assert_eq!(path, ASKED_PATH);
    }

    #[test]
    fn test_ask_runner_for_files_property_lists_the_runner_folder(
        entries in vec(repository_entry_strategy(), 0..MOST_ENTRIES),
    ) {
        let answer = RunnerMessage::Answered {
            answer: FileAnswer::Folder { entries: entries.clone() },
        };
        let desk =
            open_holder_desk(RunnerAnswer::Reply(answer)).map_err(fail)?;

        let shown = ask_holder(&desk, FILE_LISTING_NAMES[0]).map_err(fail)?;

        let expected = json!({ "entries": entries });
        prop_assert_eq!(shown, expected);
        let requests = read_asked_requests(&desk);
        let is_folder_request = matches!(
            requests.as_slice(),
            [FileRequest::ListFolder { .. }]
        );
        prop_assert!(is_folder_request, "{:?}", requests);
    }

    #[test]
    fn test_ask_runner_for_files_property_a_tampered_holder_is_not_dialed(
        tampering in prop::sample::select(TAMPERINGS.to_vec()),
        command in file_command_strategy(),
    ) {
        let answer = RunnerMessage::Answered {
            answer: FileAnswer::Folder { entries: Vec::new() },
        };
        let desk =
            open_holder_desk(RunnerAnswer::Reply(answer)).map_err(fail)?;
        desk.workspace.server.forge(&desk.holder_id, tampering);

        let refused = ask_holder(&desk, command);

        let expected =
            format!("device {} {UNTRUSTED_ADDRESS_END}", desk.holder_id);
        prop_assert_eq!(refused, Err(expected));
        prop_assert!(desk.fake_runner.received().is_empty());
    }

    #[test]
    fn test_exchange_file_request_property_a_refusal_carries_the_reason(
        reason in "[a-zA-Z0-9 .,]{1,40}",
        command in file_command_strategy(),
    ) {
        let refusal = RunnerMessage::Refused { reason: reason.clone() };
        let desk =
            open_holder_desk(RunnerAnswer::Reply(refusal)).map_err(fail)?;

        let refused = ask_holder(&desk, command);

        prop_assert_eq!(refused, Err(format!("{FILE_REFUSAL_START}{reason}")));
        prop_assert_eq!(read_asked_requests(&desk).len(), 1);
    }

    #[test]
    fn test_exchange_file_request_property_a_closed_link_is_a_refusal(
        command in file_command_strategy(),
    ) {
        let desk =
            open_holder_desk(RunnerAnswer::CloseTheLink).map_err(fail)?;

        let refused = ask_holder(&desk, command);

        let expected = format!("{FILE_REFUSAL_START}{CLOSED_LINK_REASON}");
        prop_assert_eq!(refused, Err(expected));
    }

    #[test]
    fn test_exchange_file_request_property_answers_without_files_fail(
        answer in answer_without_files_strategy(),
        command in file_command_strategy(),
    ) {
        let desk =
            open_holder_desk(RunnerAnswer::Reply(answer)).map_err(fail)?;

        let refused = ask_holder(&desk, command);

        prop_assert_eq!(refused, Err(ANSWER_WITHOUT_FILES.to_owned()));
    }
}
