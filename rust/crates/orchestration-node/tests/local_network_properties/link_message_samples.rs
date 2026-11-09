use orchestration_api::work::RunEvent;
use orchestration_core::identifiers::{ProjectId, RunId};
use orchestration_core::repository_files::{
    FilePreview, RepositoryBranches, RepositoryEntry, RepositoryEntryKind,
    RepositoryFile,
};
use orchestration_node::live_link_messages::{
    ClientMessage, FileAnswer, FileRequest, RepositoryReference, RunnerMessage,
};
use proptest::collection::vec;
use proptest::prelude::*;
use uuid::Uuid;

use crate::support::entity_strategies::{
    sample_chat_message, sample_log_line,
};

pub const LINK_CASES: u32 = 64;
const HOSTILE_PATTERN: &str =
    "[\\x00-\\x1F\"\\\\{}\\[\\]:,\u{202E}\u{200B}\u{FEFF}é漢😀 a-z]{0,24}";
const MOST_LISTED: usize = 4;

pub fn hostile_text_strategy() -> impl Strategy<Value = String> {
    prop_oneof![Just(String::new()), HOSTILE_PATTERN, any::<String>()]
}

pub fn run_id_strategy() -> impl Strategy<Value = RunId> {
    any::<u128>().prop_map(|bits| RunId(Uuid::from_u128(bits)))
}

pub fn repository_reference_strategy()
-> impl Strategy<Value = RepositoryReference> {
    (any::<u128>(), hostile_text_strategy()).prop_map(|(bits, address)| {
        RepositoryReference {
            project_id: ProjectId(Uuid::from_u128(bits)),
            address,
        }
    })
}

pub fn file_request_strategy() -> impl Strategy<Value = FileRequest> {
    let texts = || (hostile_text_strategy(), hostile_text_strategy());
    prop_oneof![
        repository_reference_strategy()
            .prop_map(|repository| FileRequest::ListBranches { repository }),
        (repository_reference_strategy(), texts()).prop_map(
            |(repository, (branch, folder))| FileRequest::ListFolder {
                repository,
                branch,
                folder,
            }
        ),
        (repository_reference_strategy(), texts()).prop_map(
            |(repository, (branch, path))| FileRequest::ReadFile {
                repository,
                branch,
                path,
            }
        ),
    ]
}

pub fn client_message_strategy() -> impl Strategy<Value = ClientMessage> {
    prop_oneof![
        run_id_strategy().prop_map(|run_id| ClientMessage::Watch { run_id }),
        hostile_text_strategy().prop_map(|text| ClientMessage::Chat { text }),
        file_request_strategy()
            .prop_map(|request| ClientMessage::Browse { request }),
    ]
}

fn run_event_strategy() -> impl Strategy<Value = RunEvent> {
    prop_oneof![
        hostile_text_strategy()
            .prop_map(|session| RunEvent::SessionStarted { session }),
        hostile_text_strategy()
            .prop_map(|branch| RunEvent::WorktreeCreated { branch }),
        hostile_text_strategy().prop_map(|text| RunEvent::ChatAppended {
            message: sample_chat_message(&text),
        }),
        hostile_text_strategy().prop_map(|text| RunEvent::LogAppended {
            line: sample_log_line(&text),
        }),
        Just(RunEvent::Finished),
    ]
}

fn repository_entry_strategy() -> impl Strategy<Value = RepositoryEntry> {
    let kinds = prop_oneof![
        Just(RepositoryEntryKind::Folder),
        Just(RepositoryEntryKind::File),
        Just(RepositoryEntryKind::Link),
    ];
    (hostile_text_strategy(), kinds, any::<Option<u64>>())
        .prop_map(|(name, kind, size)| RepositoryEntry { name, kind, size })
}

fn file_preview_strategy() -> impl Strategy<Value = FilePreview> {
    prop_oneof![
        hostile_text_strategy().prop_map(|text| FilePreview::Text { text }),
        (any::<u32>(), any::<u32>(), hostile_text_strategy()).prop_map(
            |(width, height, base64_content)| FilePreview::Image {
                width,
                height,
                base64_content,
            }
        ),
        Just(FilePreview::TooLarge),
        Just(FilePreview::Binary),
        Just(FilePreview::Link),
    ]
}

pub fn file_answer_strategy() -> impl Strategy<Value = FileAnswer> {
    let names = || vec(hostile_text_strategy(), 0..MOST_LISTED);
    let branches = (names(), names()).prop_map(|(branches, task_branches)| {
        FileAnswer::Branches {
            branches: RepositoryBranches {
                branches,
                task_branches,
            },
        }
    });
    let folder = vec(repository_entry_strategy(), 0..MOST_LISTED)
        .prop_map(|entries| FileAnswer::Folder { entries });
    let file = (
        hostile_text_strategy(),
        any::<u64>(),
        file_preview_strategy(),
    )
        .prop_map(|(path, size, preview)| FileAnswer::File {
            file: RepositoryFile {
                path,
                size,
                preview,
            },
        });
    prop_oneof![branches, folder, file]
}

pub fn runner_message_strategy() -> impl Strategy<Value = RunnerMessage> {
    prop_oneof![
        Just(RunnerMessage::Accepted),
        hostile_text_strategy()
            .prop_map(|reason| RunnerMessage::Refused { reason }),
        vec(run_event_strategy(), 0..MOST_LISTED)
            .prop_map(|events| RunnerMessage::Events { events }),
        file_answer_strategy()
            .prop_map(|answer| RunnerMessage::Answered { answer }),
    ]
}

pub fn name_client_kind(message: &ClientMessage) -> &'static str {
    match message {
        ClientMessage::Watch { .. } => "watch",
        ClientMessage::Chat { .. } => "chat",
        ClientMessage::Browse { .. } => "browse",
    }
}

pub fn name_runner_kind(message: &RunnerMessage) -> &'static str {
    match message {
        RunnerMessage::Accepted => "accepted",
        RunnerMessage::Refused { .. } => "refused",
        RunnerMessage::Events { .. } => "events",
        RunnerMessage::Answered { .. } => "answered",
    }
}
