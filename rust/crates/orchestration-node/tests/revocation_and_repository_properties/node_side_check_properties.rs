use proptest::prelude::*;

use crate::address_spellings::{
    foreign_address_strategy, foreign_spelling_strategy,
};
use crate::fake_peer_answers::{CONFUSED_ADDRESS, HONEST_ADDRESS};
use crate::fake_runner_peer::shared_fake_runner_peer;
use crate::file_question_steps::{
    FILE_COMMAND_KINDS, FileCommandKind, FileQuestion, PLACE_PATTERN,
    SAMPLE_PLACE, UNIQUE_BRANCH_PATTERN, file_command_kind_strategy,
    make_branch_unique, outside_problem, read_refusal,
    runner_command_kind_strategy, unknown_project_problem,
    unknown_project_strategy,
};
use crate::support::test_device::fail;

const CHECK_CASES: u32 = 8;

fn is_listed(canonical_address: &str) -> bool {
    canonical_address == HONEST_ADDRESS
        || canonical_address == CONFUSED_ADDRESS
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_ask_runner_property_an_unknown_project_never_reaches_the_runner(
        kind in runner_command_kind_strategy(),
        project_id in unknown_project_strategy(),
        branch in UNIQUE_BRANCH_PATTERN,
        place in PLACE_PATTERN,
    ) {
        let peer = shared_fake_runner_peer().map_err(fail)?;
        let branch = make_branch_unique(&branch);
        let question = FileQuestion {
            kind,
            project_id: &project_id,
            address: HONEST_ADDRESS,
            runner_id: &peer.device_id,
            branch: &branch,
            place: &place,
        };

        let asked = peer.ask_counting(&question.build_command(), &branch);

        let refusal = read_refusal(asked.reply);
        prop_assert_eq!(refusal, unknown_project_problem(&project_id));
        prop_assert_eq!(asked.new_requests, 0);
    }

    #[test]
    fn test_ask_runner_property_a_foreign_repository_never_reaches_the_runner(
        kind in runner_command_kind_strategy(),
        address in foreign_address_strategy(),
        branch in UNIQUE_BRANCH_PATTERN,
        place in PLACE_PATTERN,
    ) {
        prop_assume!(!is_listed(&address));
        let peer = shared_fake_runner_peer().map_err(fail)?;
        let branch = make_branch_unique(&branch);
        let question = FileQuestion {
            kind,
            project_id: &peer.prepared.project_id,
            address: &address,
            runner_id: &peer.device_id,
            branch: &branch,
            place: &place,
        };

        let asked = peer.ask_counting(&question.build_command(), &branch);

        prop_assert_eq!(read_refusal(asked.reply), outside_problem(&address));
        prop_assert_eq!(asked.new_requests, 0);
    }

    #[test]
    fn test_ask_runner_property_a_listed_repository_is_asked_exactly_once(
        kind in runner_command_kind_strategy(),
        branch in UNIQUE_BRANCH_PATTERN,
        place in PLACE_PATTERN,
    ) {
        let peer = shared_fake_runner_peer().map_err(fail)?;
        let branch = make_branch_unique(&branch);
        let question = FileQuestion {
            kind,
            project_id: &peer.prepared.project_id,
            address: HONEST_ADDRESS,
            runner_id: &peer.device_id,
            branch: &branch,
            place: &place,
        };

        let asked = peer.ask_counting(&question.build_command(), &branch);

        prop_assert!(asked.reply.is_ok(), "{:?}", asked.reply);
        prop_assert_eq!(asked.new_requests, 1);
    }

    #[test]
    fn test_require_project_repository_property_reads_refuse_like_branches(
        kind in runner_command_kind_strategy(),
        address in foreign_address_strategy(),
        branch in UNIQUE_BRANCH_PATTERN,
    ) {
        prop_assume!(!is_listed(&address));
        let peer = shared_fake_runner_peer().map_err(fail)?;
        let file_question = FileQuestion {
            kind,
            project_id: &peer.prepared.project_id,
            address: &address,
            runner_id: &peer.device_id,
            branch: &branch,
            place: SAMPLE_PLACE,
        };
        let branch_question = FileQuestion {
            kind: FileCommandKind::ListBranches,
            ..file_question
        };

        let file_command = file_question.build_command();
        let branch_command = branch_question.build_command();
        let file_refusal = peer.prepared.device.run(&file_command);
        let branch_refusal = peer.prepared.device.run(&branch_command);

        prop_assert!(file_refusal.is_err(), "{file_refusal:?}");
        prop_assert_eq!(file_refusal, branch_refusal);
    }

    #[test]
    fn test_require_project_repository_property_unknown_projects_refuse_alike(
        project_id in unknown_project_strategy(),
        branch in UNIQUE_BRANCH_PATTERN,
    ) {
        let peer = shared_fake_runner_peer().map_err(fail)?;
        let expected = unknown_project_problem(&project_id);

        for kind in FILE_COMMAND_KINDS {
            let question = FileQuestion {
                kind,
                project_id: &project_id,
                address: HONEST_ADDRESS,
                runner_id: &peer.device_id,
                branch: &branch,
                place: SAMPLE_PLACE,
            };
            let reply = peer.prepared.device.run(&question.build_command());
            prop_assert_eq!(&read_refusal(reply), &expected);
        }
    }

    #[test]
    fn test_require_project_repository_property_refusals_name_the_canonical(
        kind in file_command_kind_strategy(),
        (canonical_address, spelled) in foreign_spelling_strategy(),
        branch in UNIQUE_BRANCH_PATTERN,
    ) {
        prop_assume!(!is_listed(&canonical_address));
        let peer = shared_fake_runner_peer().map_err(fail)?;
        let branch = make_branch_unique(&branch);
        let question = FileQuestion {
            kind,
            project_id: &peer.prepared.project_id,
            address: &spelled,
            runner_id: &peer.device_id,
            branch: &branch,
            place: SAMPLE_PLACE,
        };

        let asked = peer.ask_counting(&question.build_command(), &branch);

        let refusal = read_refusal(asked.reply);
        prop_assert_eq!(refusal, outside_problem(&canonical_address));
        prop_assert_eq!(asked.new_requests, 0);
    }
}
