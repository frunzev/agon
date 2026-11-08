use proptest::prelude::*;
use serde_json::{Value, json};

use crate::address_spellings::spelling_of;
use crate::fake_peer_answers::CONFUSED_ADDRESS;
use crate::fake_runner_peer::{CountedReply, shared_fake_runner_peer};
use crate::file_question_steps::{
    FileCommandKind, FileQuestion, PLACE_PATTERN, UNEXPECTED_ANSWER_PROBLEM,
    UNIQUE_BRANCH_PATTERN, make_branch_unique, read_refusal,
};
use crate::support::test_device::fail;

const MISMATCH_CASES: u32 = 6;

fn ask_confused_runner(
    kind: FileCommandKind,
    spelled: &str,
    branch: &str,
    place: &str,
) -> Result<CountedReply, TestCaseError> {
    let peer = shared_fake_runner_peer().map_err(fail)?;
    let unique_branch = make_branch_unique(branch);
    let question = FileQuestion {
        kind,
        project_id: &peer.prepared.project_id,
        address: spelled,
        runner_id: &peer.device_id,
        branch: &unique_branch,
        place,
    };
    Ok(peer.ask_counting(&question.build_command(), &unique_branch))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(MISMATCH_CASES))]

    #[test]
    fn test_unexpected_answer_property_another_answer_to_branches_is_refused(
        spelled in spelling_of(CONFUSED_ADDRESS.to_owned()),
        prefers_the_runner in any::<bool>(),
    ) {
        let peer = shared_fake_runner_peer().map_err(fail)?;
        let preferred = if prefers_the_runner {
            json!(peer.device_id)
        } else {
            Value::Null
        };
        let command = json!({
            "command": "list_repository_branches",
            "project_id": peer.prepared.project_id,
            "repository_address": spelled,
            "preferred_runner_id": preferred,
        });

        let refusal = read_refusal(peer.prepared.device.run(&command));

        prop_assert_eq!(refusal, UNEXPECTED_ANSWER_PROBLEM);
    }

    #[test]
    fn test_unexpected_answer_property_another_answer_to_a_folder_is_refused(
        spelled in spelling_of(CONFUSED_ADDRESS.to_owned()),
        branch in UNIQUE_BRANCH_PATTERN,
        folder in PLACE_PATTERN,
    ) {
        let answered = ask_confused_runner(
            FileCommandKind::ListFiles,
            &spelled,
            &branch,
            &folder,
        )?;

        let refusal = read_refusal(answered.reply);
        prop_assert_eq!(refusal, UNEXPECTED_ANSWER_PROBLEM);
        prop_assert_eq!(answered.new_requests, 1);
    }

    #[test]
    fn test_unexpected_answer_property_another_answer_to_a_file_is_refused(
        spelled in spelling_of(CONFUSED_ADDRESS.to_owned()),
        branch in UNIQUE_BRANCH_PATTERN,
        path in PLACE_PATTERN,
    ) {
        let answered = ask_confused_runner(
            FileCommandKind::ReadFile,
            &spelled,
            &branch,
            &path,
        )?;

        let refusal = read_refusal(answered.reply);
        prop_assert_eq!(refusal, UNEXPECTED_ANSWER_PROBLEM);
        prop_assert_eq!(answered.new_requests, 1);
    }
}
