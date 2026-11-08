use proptest::prelude::*;
use serde_json::json;

use crate::address_spellings::{
    foreign_spelling_strategy, spelling_of, unparseable_address_strategy,
};
use crate::fake_peer_answers::{CONFUSED_ADDRESS, HONEST_ADDRESS};
use crate::fake_runner_peer::shared_fake_runner_peer;
use crate::file_question_steps::{
    FileCommandKind, FileQuestion, PLACE_PATTERN, SAMPLE_PLACE,
    UNIQUE_BRANCH_PATTERN, file_command_kind_strategy, make_branch_unique,
    outside_problem, read_echoed_address, read_refusal,
    remove_repository_command,
};
use crate::support::test_device::fail;

const SPELLING_CASES: u32 = 8;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SPELLING_CASES))]

    #[test]
    fn test_handle_file_command_property_spellings_reach_the_runner_canonical(
        kind in file_command_kind_strategy(),
        spelled in spelling_of(HONEST_ADDRESS.to_owned()),
        branch in UNIQUE_BRANCH_PATTERN,
        place in PLACE_PATTERN,
    ) {
        let peer = shared_fake_runner_peer().map_err(fail)?;
        let question = FileQuestion {
            kind,
            project_id: &peer.prepared.project_id,
            address: &spelled,
            runner_id: &peer.device_id,
            branch: &branch,
            place: &place,
        };

        let reply =
            peer.prepared.device.run(&question.build_command()).map_err(fail)?;

        let echoed = read_echoed_address(kind, &reply);
        prop_assert_eq!(echoed, json!(HONEST_ADDRESS), "{}", reply);
    }

    #[test]
    fn test_handle_file_command_property_unparseable_addresses_match_removal(
        kind in file_command_kind_strategy(),
        address in unparseable_address_strategy(),
        branch in UNIQUE_BRANCH_PATTERN,
    ) {
        let peer = shared_fake_runner_peer().map_err(fail)?;
        let branch = make_branch_unique(&branch);
        let project_id = &peer.prepared.project_id;
        let question = FileQuestion {
            kind,
            project_id,
            address: &address,
            runner_id: &peer.device_id,
            branch: &branch,
            place: SAMPLE_PLACE,
        };

        let asked = peer.ask_counting(&question.build_command(), &branch);
        let removal = remove_repository_command(project_id, &address);
        let removed = peer.prepared.device.run(&removal);

        prop_assert!(asked.reply.is_err(), "{:?}", asked.reply);
        prop_assert_eq!(asked.reply, removed);
        prop_assert_eq!(asked.new_requests, 0);
    }

    #[test]
    fn test_handle_file_command_property_two_spellings_give_one_reply(
        kind in file_command_kind_strategy(),
        first_spelling in spelling_of(HONEST_ADDRESS.to_owned()),
        second_spelling in spelling_of(HONEST_ADDRESS.to_owned()),
        branch in UNIQUE_BRANCH_PATTERN,
        place in PLACE_PATTERN,
    ) {
        let peer = shared_fake_runner_peer().map_err(fail)?;
        let first_question = FileQuestion {
            kind,
            project_id: &peer.prepared.project_id,
            address: &first_spelling,
            runner_id: &peer.device_id,
            branch: &branch,
            place: &place,
        };
        let second_question = FileQuestion {
            address: &second_spelling,
            ..first_question
        };

        let first_command = first_question.build_command();
        let second_command = second_question.build_command();
        let first = peer.prepared.device.run(&first_command);
        let second = peer.prepared.device.run(&second_command);

        prop_assert!(first.is_ok(), "{first:?}");
        prop_assert_eq!(first, second);
    }

    #[test]
    fn test_list_repository_branches_property_every_spelling_finds_the_runner(
        spelled in spelling_of(HONEST_ADDRESS.to_owned()),
    ) {
        let peer = shared_fake_runner_peer().map_err(fail)?;
        let command = json!({
            "command": "list_repository_branches",
            "project_id": peer.prepared.project_id,
            "repository_address": spelled,
        });

        let source = peer.prepared.device.run(&command).map_err(fail)?;

        prop_assert_eq!(&source["kind"], &json!("available"));
        let runner_id = &source["runner"]["device_id"];
        prop_assert_eq!(runner_id, &json!(peer.device_id));
        prop_assert_eq!(&source["branches"], &json!([HONEST_ADDRESS]));
    }

    #[test]
    fn test_list_repository_branches_property_unparseable_match_removal(
        address in unparseable_address_strategy(),
    ) {
        let peer = shared_fake_runner_peer().map_err(fail)?;
        let project_id = &peer.prepared.project_id;
        let question = FileQuestion {
            kind: FileCommandKind::ListBranches,
            project_id,
            address: &address,
            runner_id: &peer.device_id,
            branch: "",
            place: SAMPLE_PLACE,
        };

        let listed = peer.prepared.device.run(&question.build_command());
        let removal = remove_repository_command(project_id, &address);
        let removed = peer.prepared.device.run(&removal);

        prop_assert!(listed.is_err(), "{listed:?}");
        prop_assert_eq!(listed, removed);
    }

    #[test]
    fn test_list_repository_branches_property_foreign_spellings_name_canonical(
        (canonical_address, spelled) in foreign_spelling_strategy(),
    ) {
        prop_assume!(canonical_address != HONEST_ADDRESS);
        prop_assume!(canonical_address != CONFUSED_ADDRESS);
        let peer = shared_fake_runner_peer().map_err(fail)?;
        let question = FileQuestion {
            kind: FileCommandKind::ListBranches,
            project_id: &peer.prepared.project_id,
            address: &spelled,
            runner_id: &peer.device_id,
            branch: "",
            place: SAMPLE_PLACE,
        };

        let refusal =
            read_refusal(peer.prepared.device.run(&question.build_command()));

        prop_assert_eq!(refusal, outside_problem(&canonical_address));
    }
}
