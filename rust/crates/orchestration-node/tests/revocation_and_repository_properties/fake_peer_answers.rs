use orchestration_core::repository_files::{
    FilePreview, RepositoryBranches, RepositoryEntry, RepositoryEntryKind,
    RepositoryFile,
};
use orchestration_node::live_link_messages::{FileAnswer, FileRequest};

pub const HONEST_ADDRESS: &str = "github.com/acme/app";
pub const CONFUSED_ADDRESS: &str = "github.com/acme/confused";

pub fn answer_file_request(request: &FileRequest) -> FileAnswer {
    if request.repository().address == CONFUSED_ADDRESS {
        return answer_another_question(request);
    }
    answer_honestly(request)
}

pub fn answer_honestly(request: &FileRequest) -> FileAnswer {
    let address = request.repository().address.clone();
    match request {
        FileRequest::ListBranches { .. } => FileAnswer::Branches {
            branches: RepositoryBranches {
                branches: vec![address],
                task_branches: Vec::new(),
            },
        },
        FileRequest::ListFolder { .. } => FileAnswer::Folder {
            entries: vec![RepositoryEntry {
                name: address,
                kind: RepositoryEntryKind::Folder,
                size: None,
            }],
        },
        FileRequest::ReadFile { path, .. } => FileAnswer::File {
            file: RepositoryFile {
                path: path.clone(),
                size: 0,
                preview: FilePreview::Text { text: address },
            },
        },
    }
}

fn answer_another_question(request: &FileRequest) -> FileAnswer {
    match request {
        FileRequest::ListBranches { .. } | FileRequest::ReadFile { .. } => {
            FileAnswer::Folder {
                entries: Vec::new(),
            }
        }
        FileRequest::ListFolder { .. } => FileAnswer::Branches {
            branches: RepositoryBranches::default(),
        },
    }
}
