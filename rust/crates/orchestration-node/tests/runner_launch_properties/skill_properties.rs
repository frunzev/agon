use orchestration_api::catalog::ImproveSkillRequest;
use orchestration_api::work::RunAssignment;
use orchestration_core::identifiers::SkillId;
use orchestration_node::runner_bridge::NodeRunnerServer;
use orchestration_runner::runner_server::{RunnerServer, ServerError};
use proptest::prelude::*;
use serde_json::{Value, json};
use uuid::Uuid;

use crate::server_desk::{SERVER_CASES, ServerDesk, server_desk};
use crate::support::test_device::fail;

const FIRST_WORDS: &str = "first words";
const SUMMARY: &str = "1 line added";
const NAME_TAIL_LENGTH: usize = 12;
const WORDS_PATTERN: &str = "[a-z]{1,10}( [a-z]{1,10}){0,4}";

#[derive(Debug)]
struct Proposal {
    runner: NodeRunnerServer,
    assignment: RunAssignment,
    skill_id: SkillId,
    instructions: String,
    outcome: Result<(), ServerError>,
}

fn unique_tail() -> String {
    Uuid::new_v4().simple().to_string()
}

fn unique_name_tail() -> String {
    let tail = unique_tail();
    tail[..NAME_TAIL_LENGTH].to_owned()
}

fn propose(
    desk: &ServerDesk,
    improvement: &str,
    generated: &str,
) -> Result<Proposal, String> {
    let runner = desk.open_runner()?;
    let skill_id = desk.create_skill(&unique_name_tail(), improvement)?;
    let assignment = desk.claim_fresh_run(&runner, "improve a skill")?;
    let instructions = format!("{} {generated}", unique_tail());
    let request = ImproveSkillRequest {
        run_id: assignment.run.id,
        summary: SUMMARY.to_owned(),
        instructions: instructions.clone(),
    };
    let outcome =
        desk.wait(runner.propose_skill_improvement(skill_id, &request));
    Ok(Proposal {
        runner,
        assignment,
        skill_id,
        instructions,
        outcome,
    })
}

fn find_proposal_approval(
    desk: &ServerDesk,
    instructions: &str,
) -> Result<Option<Value>, String> {
    let listed = desk.device().run(&json!({ "command": "list_approvals" }))?;
    let approvals = listed["approvals"].as_array().cloned();
    let found = approvals.unwrap_or_default().into_iter().find(|entry| {
        entry["approval"]["action"]["proposed_instructions"] == instructions
    });
    Ok(found)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SERVER_CASES))]

    #[test]
    fn test_propose_skill_improvement_property_auto_saves_the_words(
        generated in WORDS_PATTERN,
    ) {
        let desk = server_desk().map_err(fail)?;
        let proposal = propose(desk, "auto", &generated).map_err(fail)?;

        let skill = desk.find_skill(proposal.skill_id).map_err(fail)?;

        prop_assert!(proposal.outcome.is_ok(), "{:?}", proposal.outcome);
        prop_assert_eq!(&skill["instructions"], &json!(proposal.instructions));
    }

    #[test]
    fn test_propose_skill_improvement_property_never_keeps_the_skill(
        generated in WORDS_PATTERN,
    ) {
        let desk = server_desk().map_err(fail)?;
        let proposal = propose(desk, "never", &generated).map_err(fail)?;

        let skill = desk.find_skill(proposal.skill_id).map_err(fail)?;

        prop_assert!(proposal.outcome.is_err());
        prop_assert_eq!(&skill["instructions"], &json!(FIRST_WORDS));
        prop_assert_eq!(&skill["history"], &json!([]));
    }

    #[test]
    fn test_propose_skill_improvement_property_an_unknown_skill_is_refused(
        number in any::<u128>(),
        generated in WORDS_PATTERN,
    ) {
        let desk = server_desk().map_err(fail)?;
        let proposal = propose(desk, "auto", &generated).map_err(fail)?;
        let unknown_skill = SkillId(Uuid::from_u128(number));
        prop_assume!(unknown_skill != proposal.skill_id);
        let request = ImproveSkillRequest {
            run_id: proposal.assignment.run.id,
            summary: SUMMARY.to_owned(),
            instructions: generated,
        };

        let proposed = desk.wait(
            proposal
                .runner
                .propose_skill_improvement(unknown_skill, &request),
        );

        prop_assert!(proposed.is_err(), "{:?}", proposed);
    }

    #[test]
    fn test_hand_over_sealed_improvement_property_stores_no_plain_words(
        generated in "[a-z]{4,16}",
    ) {
        let desk = server_desk().map_err(fail)?;
        let proposal = propose(desk, "auto", &generated).map_err(fail)?;

        let stored = desk.prepared.server.read_stored_state().map_err(fail)?;

        prop_assert!(proposal.outcome.is_ok(), "{:?}", proposal.outcome);
        prop_assert!(!stored.contains(&proposal.instructions));
    }

    #[test]
    fn test_hand_over_sealed_improvement_property_keeps_the_run(
        generated in WORDS_PATTERN,
    ) {
        let desk = server_desk().map_err(fail)?;
        let proposal = propose(desk, "auto", &generated).map_err(fail)?;

        let skill = desk.find_skill(proposal.skill_id).map_err(fail)?;

        let run_text = proposal.assignment.run.id.0.to_string();
        let origin = &skill["history"][0]["origin"];
        prop_assert_eq!(&origin["run_id"], &json!(run_text));
        prop_assert_eq!(
            &skill["history"][0]["replaced_instructions"],
            &json!(FIRST_WORDS)
        );
    }

    #[test]
    fn test_hand_over_sealed_improvement_property_ask_me_shows_the_words(
        generated in WORDS_PATTERN,
    ) {
        let desk = server_desk().map_err(fail)?;
        let proposal = propose(desk, "ask_me", &generated).map_err(fail)?;

        let shown = find_proposal_approval(desk, &proposal.instructions)
            .map_err(fail)?;

        prop_assert!(proposal.outcome.is_ok(), "{:?}", proposal.outcome);
        let Some(shown) = shown else {
            return Err(fail("the proposal is not listed"));
        };
        prop_assert_eq!(&shown["approval"]["action"]["summary"], SUMMARY);
        let skill = desk.find_skill(proposal.skill_id).map_err(fail)?;
        prop_assert_eq!(&skill["instructions"], &json!(FIRST_WORDS));
    }
}
