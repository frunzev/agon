use orchestration_api::work::ForgottenWork;
use orchestration_core::identifiers::TaskId;
use orchestration_core::run::ChatAuthor;
use orchestration_runner::runner_server::RunnerServer;
use proptest::prelude::*;
use uuid::Uuid;

use crate::server_desk::{
    DETAILS_PATTERN, NO_ACCOUNT, SERVER_CASES, chat_event,
    missing_claim_reason, open_accountless_runner, read_chat_texts,
    server_desk,
};
use crate::support::runner_access::sample_heartbeat;
use crate::support::test_device::fail;

const MOST_MESSAGES: usize = 4;
const ADDRESS_PATTERN: &str = "local\\.test/[a-z]{1,8}/[a-z]{1,8}";

fn unique_text(generated: &str) -> String {
    format!("{} {generated}", Uuid::new_v4())
}

fn task_id_of(number: u128) -> TaskId {
    TaskId(Uuid::from_u128(number))
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SERVER_CASES))]

    #[test]
    fn test_post_run_events_property_a_refused_post_writes_nothing(
        details in DETAILS_PATTERN,
    ) {
        let desk = server_desk().map_err(fail)?;
        let claiming = desk.open_runner().map_err(fail)?;
        let stranger = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&claiming, &details).map_err(fail)?;
        let run_id = assignment.run.id;
        let text = unique_text(&details);

        let posted = desk.post(
            &stranger,
            run_id,
            vec![chat_event(ChatAuthor::Agent, &text)],
        );
        let run = desk.show_run(run_id).map_err(fail)?;

        let reason = posted.map_err(|problem| problem.reason);
        prop_assert_eq!(reason, Err(missing_claim_reason(run_id)));
        prop_assert!(!read_chat_texts(&run).contains(&text));
    }

    #[test]
    fn test_post_run_events_property_agent_chat_reaches_the_history(
        generated in "\\PC{0,40}",
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&runner, "chat history").map_err(fail)?;
        let text = unique_text(&generated);
        let event = chat_event(ChatAuthor::Agent, &text);

        desk.post(&runner, assignment.run.id, vec![event]).map_err(fail)?;
        let run = desk.show_run(assignment.run.id).map_err(fail)?;

        prop_assert!(read_chat_texts(&run).contains(&text), "{}", run);
    }

    #[test]
    fn test_post_sealed_property_batches_keep_their_order(
        batches in prop::collection::vec(
            prop::collection::vec("[a-z]{1,12}", 1..MOST_MESSAGES),
            1..MOST_MESSAGES,
        ),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&runner, "ordered posts").map_err(fail)?;
        let mut expected = Vec::new();
        for batch in &batches {
            let mut events = Vec::new();
            for generated in batch {
                let text = unique_text(generated);
                events.push(chat_event(ChatAuthor::Agent, &text));
                expected.push(text);
            }
            desk.post(&runner, assignment.run.id, events).map_err(fail)?;
        }

        let run = desk.show_run(assignment.run.id).map_err(fail)?;

        prop_assert_eq!(read_chat_texts(&run), expected);
    }

    #[test]
    fn test_post_sealed_property_the_server_stores_no_plain_text(
        generated in "[a-z]{4,20}",
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&runner, "sealed posts").map_err(fail)?;
        let text = unique_text(&generated);
        let event = chat_event(ChatAuthor::Agent, &text);

        desk.post(&runner, assignment.run.id, vec![event]).map_err(fail)?;
        let stored = desk.prepared.server.read_stored_state().map_err(fail)?;

        prop_assert!(!stored.contains(&text));
    }

    #[test]
    fn test_post_sealed_property_an_empty_batch_changes_nothing(
        repeat_count in 1_usize..4,
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&runner, "empty posts").map_err(fail)?;
        let before = desk.show_run(assignment.run.id).map_err(fail)?;

        for _ in 0..repeat_count {
            desk.post(&runner, assignment.run.id, Vec::new())
                .map_err(fail)?;
        }
        let after = desk.show_run(assignment.run.id).map_err(fail)?;

        prop_assert_eq!(&after["chat"], &before["chat"]);
        prop_assert_eq!(&after["steps"], &before["steps"]);
    }

    #[test]
    fn test_send_heartbeat_property_forgets_only_unknown_held_tasks(
        numbers in prop::collection::vec(any::<u128>(), 0..4),
        details in DETAILS_PATTERN,
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let assignment =
            desk.claim_fresh_run(&runner, &details).map_err(fail)?;
        let unknown_tasks: Vec<TaskId> =
            numbers.into_iter().map(task_id_of).collect();
        let mut heartbeat = sample_heartbeat();
        heartbeat.held_tasks = unknown_tasks.clone();
        heartbeat.held_tasks.push(assignment.task.id);

        let forgotten =
            desk.wait(runner.send_heartbeat(&heartbeat)).map_err(fail)?;

        prop_assert_eq!(forgotten.forgotten_tasks, unknown_tasks);
    }

    #[test]
    fn test_announce_property_repeating_it_answers_alike(
        numbers in prop::collection::vec(any::<u128>(), 0..4),
        addresses in prop::collection::vec(ADDRESS_PATTERN, 0..3),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let mut heartbeat = sample_heartbeat();
        heartbeat.held_tasks = numbers.into_iter().map(task_id_of).collect();
        heartbeat.cached_repositories = addresses;

        let first: ForgottenWork =
            desk.wait(runner.send_heartbeat(&heartbeat)).map_err(fail)?;
        let second: ForgottenWork =
            desk.wait(runner.send_heartbeat(&heartbeat)).map_err(fail)?;

        prop_assert_eq!(first, second);
    }

    #[test]
    fn test_announce_property_a_device_without_account_is_refused(
        repeat_count in 1_usize..3,
    ) {
        let (_device, runner) = open_accountless_runner().map_err(fail)?;
        let desk = server_desk().map_err(fail)?;
        let heartbeat = sample_heartbeat();

        for _ in 0..repeat_count {
            let announced = desk.wait(runner.send_heartbeat(&heartbeat));
            let reason = announced.map_err(|problem| problem.reason);
            prop_assert_eq!(reason, Err(NO_ACCOUNT.to_owned()));
        }
    }

    #[test]
    fn test_announce_property_names_cached_copies_no_project_uses(
        addresses in prop::collection::vec(ADDRESS_PATTERN, 0..4),
    ) {
        let desk = server_desk().map_err(fail)?;
        let runner = desk.open_runner().map_err(fail)?;
        let mut heartbeat = sample_heartbeat();
        heartbeat.cached_repositories = addresses.clone();

        let forgotten =
            desk.wait(runner.send_heartbeat(&heartbeat)).map_err(fail)?;

        prop_assert_eq!(forgotten.unused_repositories, addresses);
        prop_assert_eq!(forgotten.forgotten_tasks, Vec::new());
    }
}
