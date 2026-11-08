use std::path::Path;

use proptest::prelude::*;
use serde_json::{Value, json};

use crate::drafted_folders::{
    FolderSnapshot, PlannedFiles, create_case_folder, create_plain_folder,
    has_own_git, planned_files_strategy, snapshot_folder,
};
use crate::support::drafting_desk::{DraftingDesk, open_desk_or_panic};
use crate::support::git_folders::create_git_folder;
use crate::support::item_drafting_desk::{
    StartedItemDraft, draft_item_command, drafted_project_answer,
    finish_item_draft, item_draft_status, read_device_id, start_item_draft,
};
use crate::support::test_device::{fail, read_success};

const STATUS_CASES: u32 = 4;
const AGENT_ADDRESS: &str = "github.com/acme/billing";
const FOREIGN_DEVICE_ID: &str = "f0f0f0";
const CHOSEN_BRANCH: &str = "main";

#[derive(Clone, Copy, Debug)]
enum HostileChoice {
    PlainPath,
    FolderOnAnotherDevice,
    PlainFolderHere,
}

fn hostile_choice_strategy() -> impl Strategy<Value = HostileChoice> {
    prop_oneof![
        Just(HostileChoice::PlainPath),
        Just(HostileChoice::FolderOnAnotherDevice),
        Just(HostileChoice::PlainFolderHere),
    ]
}

fn chosen_folder(address: &str) -> Value {
    json!({ "address": address, "default_branch": CHOSEN_BRANCH })
}

fn spell_hostile(
    choice: HostileChoice,
    device_id: &str,
    path: &str,
) -> String {
    match choice {
        HostileChoice::PlainPath => path.to_owned(),
        HostileChoice::FolderOnAnotherDevice => {
            format!("local:{FOREIGN_DEVICE_ID}:{path}")
        }
        HostileChoice::PlainFolderHere => format!("local:{device_id}:{path}"),
    }
}

fn describe_refusal(choice: HostileChoice, path: &str) -> String {
    match choice {
        HostileChoice::PlainPath => format!(
            "a local address is local:<device id>:<folder>, not {path:?}"
        ),
        HostileChoice::FolderOnAnotherDevice => {
            format!(
                "the folder {path} is on another computer, so add it there"
            )
        }
        HostileChoice::PlainFolderHere => {
            format!("the folder {path} is not a git repository")
        }
    }
}

struct HostileStatus {
    desk: DraftingDesk,
    draft: StartedItemDraft,
    plain_path: String,
    plain_snapshot: FolderSnapshot,
    refused: Result<Value, String>,
}

fn ask_status_with_hostile_folder(
    choice: HostileChoice,
    case_root: &Path,
    planned_files: &PlannedFiles,
) -> Result<HostileStatus, TestCaseError> {
    let desk = open_desk_or_panic();
    let device_id = read_device_id(&desk.prepared.device).map_err(fail)?;
    let git_folder =
        create_git_folder(case_root, CHOSEN_BRANCH).map_err(fail)?;
    let chosen_address = format!("local:{device_id}:{}", git_folder.display());
    let mut command =
        draft_item_command(&desk.prepared, "project", "Billing app");
    command["chosen_folders"] = json!([chosen_folder(&chosen_address)]);
    let draft = start_item_draft(&desk, &command).map_err(fail)?;
    let answer = drafted_project_answer(AGENT_ADDRESS).to_string();
    finish_item_draft(&desk, &draft, &answer).map_err(fail)?;

    let plain_folder = create_plain_folder(case_root, planned_files)?;
    let plain_path = plain_folder.display().to_string();
    let plain_snapshot = snapshot_folder(&plain_folder)?;
    let hostile_address = spell_hostile(choice, &device_id, &plain_path);
    let refused = read_success(&desk.prepared.device.send(&json!({
        "command": "item_draft_status",
        "workspace_id": desk.prepared.workspace_id,
        "task_id": draft.task_id,
        "kind": "project",
        "chosen_folders": [
            chosen_folder(&chosen_address),
            chosen_folder(&hostile_address),
        ],
    })));
    Ok(HostileStatus {
        desk,
        draft,
        plain_path,
        plain_snapshot,
        refused,
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STATUS_CASES))]

    #[test]
    fn test_item_draft_status_property_refuses_folders_not_chosen_here(
        choice in hostile_choice_strategy(),
        planned_files in planned_files_strategy(),
    ) {
        let case_folder = create_case_folder()?;

        let status = ask_status_with_hostile_folder(
            choice,
            case_folder.path(),
            &planned_files,
        )?;

        let expected = describe_refusal(choice, &status.plain_path);
        prop_assert_eq!(status.refused, Err(expected));
    }

    #[test]
    fn test_item_draft_status_property_a_refused_status_keeps_the_draft(
        choice in hostile_choice_strategy(),
        planned_files in planned_files_strategy(),
    ) {
        let case_folder = create_case_folder()?;
        let status = ask_status_with_hostile_folder(
            choice,
            case_folder.path(),
            &planned_files,
        )?;

        let reply = item_draft_status(&status.desk, &status.draft);

        prop_assert!(status.refused.is_err(), "{:?}", status.refused);
        let done = read_success(&reply).map_err(fail)?;
        prop_assert_eq!(&done["state"], "done");
        prop_assert_eq!(&done["problems"], &json!([]));
    }

    #[test]
    fn test_item_draft_status_property_a_refused_folder_stays_untouched(
        choice in hostile_choice_strategy(),
        planned_files in planned_files_strategy(),
    ) {
        let case_folder = create_case_folder()?;

        let status = ask_status_with_hostile_folder(
            choice,
            case_folder.path(),
            &planned_files,
        )?;

        let plain_folder = Path::new(&status.plain_path);
        prop_assert!(!has_own_git(plain_folder));
        prop_assert_eq!(snapshot_folder(plain_folder)?, status.plain_snapshot);
    }
}
