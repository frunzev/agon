use proptest::prelude::*;
use proptest::test_runner::{Config, TestCaseResult, TestRunner};
use serde_json::{Value, json};
use tempfile::TempDir;

use crate::support::drafting_desk::{DraftingDesk, open_desk_or_panic};
use crate::support::git_folders::create_named_git_folder;
use crate::support::item_drafting_desk::{
    draft_item_command, finish_item_draft, read_device_id, start_item_draft,
};
use crate::support::test_device::fail;

const COMMAND_CASES: u32 = 8;
const OTHER_KINDS: [&str; 4] = ["task", "job", "skill", "rule"];
const ALL_KINDS: [&str; 5] = ["task", "job", "project", "skill", "rule"];
const UNKNOWN_TASK_ID: &str = "00000000-0000-0000-0000-0000deadbeef";
const FOREIGN_DEVICE_ID: &str = "f0f0f0";
const ANY_ADDRESS_PATTERN: &str = "\\PC{0,24}";
const FOLDER_NAME_PATTERN: &str = "[a-z][a-z0-9-]{0,8}";
const MOST_FOLDERS: usize = 3;
const POST_METHOD: &str = "POST";
const TASKS_PATH_END: &str = "/tasks";
const UNSAFE_PARTS: [&str; 3] = ["..", ".", ""];
const CHOSEN_HEADING: &str =
    "Folders the person chose on this computer (repos of this project):";

fn refusal_for(kind: &str) -> String {
    format!("only a project draft takes chosen folders, not a {kind}")
}

fn chosen_folder(address: &str) -> Value {
    json!({ "address": address, "default_branch": "main" })
}

fn status_with_folders(
    desk: &DraftingDesk,
    kind: &str,
    chosen_folders: &[Value],
) -> Result<Value, String> {
    desk.prepared.device.run(&json!({
        "command": "item_draft_status",
        "workspace_id": desk.prepared.workspace_id,
        "task_id": UNKNOWN_TASK_ID,
        "kind": kind,
        "chosen_folders": chosen_folders,
    }))
}

fn project_draft_with(desk: &DraftingDesk, chosen_folders: &[Value]) -> Value {
    let mut command = draft_item_command(&desk.prepared, "project", "Billing");
    command["chosen_folders"] = json!(chosen_folders);
    command
}

fn count_task_posts(desk: &DraftingDesk) -> usize {
    let requests = desk.prepared.server.recorded_requests();
    requests
        .iter()
        .filter(|request| {
            request.method == POST_METHOD
                && request.path.ends_with(TASKS_PATH_END)
        })
        .count()
}

fn this_device_id(desk: &DraftingDesk) -> Result<String, TestCaseError> {
    read_device_id(&desk.prepared.device).map_err(fail)
}

fn run_cases<Input: Strategy>(
    strategy: &Input,
    check_case: impl Fn(Input::Value) -> TestCaseResult,
) {
    let mut runner = TestRunner::new(Config::with_cases(COMMAND_CASES));
    let outcome = runner.run(strategy, check_case);
    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_require_project_folders_property_other_kinds_refuse_any_folder() {
    let desk = open_desk_or_panic();
    let strategy = (
        proptest::sample::select(OTHER_KINDS.to_vec()),
        proptest::collection::vec(ANY_ADDRESS_PATTERN, 1..MOST_FOLDERS),
    );

    run_cases(&strategy, |(kind, addresses)| {
        let mut chosen = Vec::new();
        for address in &addresses {
            chosen.push(chosen_folder(address));
        }

        let refused = status_with_folders(&desk, kind, &chosen);

        prop_assert_eq!(refused, Err(refusal_for(kind)));
        Ok(())
    });
}

#[test]
fn test_require_project_folders_property_no_folders_pass_for_every_kind() {
    let desk = open_desk_or_panic();
    let strategy = proptest::sample::select(ALL_KINDS.to_vec());

    run_cases(&strategy, |kind| {
        let reply = status_with_folders(&desk, kind, &[]);

        let refusal = reply.err().unwrap_or_default();
        prop_assert!(!refusal.is_empty(), "an unknown task is no draft");
        prop_assert_ne!(refusal, refusal_for(kind));
        Ok(())
    });
}

#[test]
fn test_require_project_folders_property_a_project_takes_any_folders() {
    let desk = open_desk_or_panic();
    let strategy =
        proptest::collection::vec(ANY_ADDRESS_PATTERN, 1..MOST_FOLDERS);

    run_cases(&strategy, |addresses| {
        let mut chosen = Vec::new();
        for address in &addresses {
            chosen.push(chosen_folder(address));
        }

        let reply = status_with_folders(&desk, "project", &chosen);

        let refusal = reply.err().unwrap_or_default();
        prop_assert!(!refusal.starts_with("only a project draft"));
        Ok(())
    });
}

#[test]
fn test_require_chosen_folders_property_accepts_git_folders_here() {
    let desk = open_desk_or_panic();
    let strategy =
        proptest::collection::btree_set(FOLDER_NAME_PATTERN, 1..MOST_FOLDERS);

    run_cases(&strategy, |names| {
        let device_id = this_device_id(&desk)?;
        let parent = TempDir::new().map_err(fail)?;
        let mut paths = Vec::new();
        let mut chosen = Vec::new();
        for name in &names {
            let folder = create_named_git_folder(parent.path(), name, "main")
                .map_err(fail)?;
            let path = folder.display().to_string();
            chosen.push(chosen_folder(&format!("local:{device_id}:{path}")));
            paths.push(format!("- {path}"));
        }
        let posts_before = count_task_posts(&desk);

        let command = project_draft_with(&desk, &chosen);
        let draft = start_item_draft(&desk, &command).map_err(fail)?;
        finish_item_draft(&desk, &draft, "{}").map_err(fail)?;

        prop_assert_eq!(count_task_posts(&desk), posts_before + 1);
        let listed = format!("{CHOSEN_HEADING}\n{}\n", paths.join("\n"));
        prop_assert!(draft.details.contains(&listed), "{}", draft.details);
        Ok(())
    });
}

#[test]
fn test_require_chosen_folders_property_refuses_unsafe_or_foreign_folders() {
    let desk = open_desk_or_panic();
    let strategy = (0..UNSAFE_PARTS.len() + 2, FOLDER_NAME_PATTERN);

    run_cases(&strategy, |(choice, name)| {
        let device_id = this_device_id(&desk)?;
        let parent = TempDir::new().map_err(fail)?;
        let folder = create_named_git_folder(parent.path(), &name, "main")
            .map_err(fail)?;
        let path = folder.display().to_string();
        let address = match UNSAFE_PARTS.get(choice) {
            Some(part) => format!("local:{device_id}:{path}/{part}/x"),
            None if choice == UNSAFE_PARTS.len() => {
                format!("local:{FOREIGN_DEVICE_ID}:{path}")
            }
            None => path.clone(),
        };
        let posts_before = count_task_posts(&desk);

        let command = project_draft_with(&desk, &[chosen_folder(&address)]);
        let refused = desk.prepared.device.run(&command);

        prop_assert!(refused.is_err(), "{}: {:?}", address, refused);
        prop_assert_eq!(count_task_posts(&desk), posts_before);
        Ok(())
    });
}

#[test]
fn test_require_chosen_folders_property_one_bad_folder_refuses_all() {
    let desk = open_desk_or_panic();
    let strategy = (
        proptest::collection::btree_set(FOLDER_NAME_PATTERN, 1..MOST_FOLDERS),
        any::<prop::sample::Index>(),
    );

    run_cases(&strategy, |(names, bad_position)| {
        let device_id = this_device_id(&desk)?;
        let parent = TempDir::new().map_err(fail)?;
        let mut chosen = Vec::new();
        for name in &names {
            let folder = create_named_git_folder(parent.path(), name, "main")
                .map_err(fail)?;
            let address = format!("local:{device_id}:{}", folder.display());
            chosen.push(chosen_folder(&address));
        }
        let missing = parent.path().join("missing-folder");
        let missing_address =
            format!("local:{device_id}:{}", missing.display());
        let position = bad_position.index(chosen.len() + 1);
        chosen.insert(position, chosen_folder(&missing_address));
        let posts_before = count_task_posts(&desk);

        let command = project_draft_with(&desk, &chosen);
        let refused = desk.prepared.device.run(&command);

        let expected = format!(
            "the folder {} does not exist or this app cannot open it",
            missing.display()
        );
        prop_assert_eq!(refused, Err(expected));
        prop_assert_eq!(count_task_posts(&desk), posts_before);
        Ok(())
    });
}
