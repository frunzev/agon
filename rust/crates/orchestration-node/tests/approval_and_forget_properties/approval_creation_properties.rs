use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::command_builders::{PreparedWorkspace, prepare_workspace};
use crate::support::test_device::fail;

const CREATION_CASES: u32 = 4;
const SUMMARY_PATTERN: &str = "[0-9] lines? (added|removed)";
const INSTRUCTIONS_PATTERN: &str =
    "(sealed-v1:[0-9a-f]{0,16})?[a-z .\n]{0,30}";
const TARGET_PATTERN: &str = "[a-z][a-z0-9-]{0,12}";
const SKILL_PROPOSAL_REFUSAL: &str =
    "a skill improvement is proposed through its skill, not as an approval";
const APPROVALS_PATH: &str = "/approvals";
const POST_METHOD: &str = "POST";

fn skill_proposal_command(
    skill_id: &str,
    summary: &str,
    instructions: &str,
) -> Value {
    json!({
        "command": "create_approval",
        "run_id": null,
        "action": {
            "kind": "improve_skill",
            "skill_id": skill_id,
            "summary": summary,
            "proposed_instructions": instructions,
        },
    })
}

fn count_approval_posts(prepared: &PreparedWorkspace) -> usize {
    let mut count = 0;
    for request in prepared.server.recorded_requests() {
        if request.method == POST_METHOD && request.path == APPROVALS_PATH {
            count += 1;
        }
    }
    count
}

fn list_approvals(prepared: &PreparedWorkspace) -> Result<Value, String> {
    prepared.device.run(&json!({ "command": "list_approvals" }))
}

fn skill_id_text(skill_number: u128) -> String {
    uuid::Uuid::from_u128(skill_number).to_string()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CREATION_CASES))]

    #[test]
    fn test_handle_approval_command_property_a_skill_proposal_stays_local(
        skill_number in any::<u128>(),
        summary in SUMMARY_PATTERN,
        instructions in INSTRUCTIONS_PATTERN,
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let command = skill_proposal_command(
            &skill_id_text(skill_number),
            &summary,
            &instructions,
        );

        let created = prepared.device.run(&command);

        prop_assert_eq!(created, Err(SKILL_PROPOSAL_REFUSAL.to_owned()));
        prop_assert_eq!(count_approval_posts(&prepared), 0);
    }

    #[test]
    fn test_handle_approval_command_property_a_refused_proposal_lists_nothing(
        skill_number in any::<u128>(),
        summary in SUMMARY_PATTERN,
        instructions in INSTRUCTIONS_PATTERN,
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let listed_before = list_approvals(&prepared).map_err(fail)?;
        let command = skill_proposal_command(
            &skill_id_text(skill_number),
            &summary,
            &instructions,
        );

        let created = prepared.device.run(&command);

        prop_assert!(created.is_err());
        let listed_after = list_approvals(&prepared).map_err(fail)?;
        prop_assert_eq!(&listed_after, &listed_before);
        prop_assert_eq!(&listed_after["waiting_count"], &json!(0));
    }

    #[test]
    fn test_handle_approval_command_property_other_kinds_reach_the_server(
        target in TARGET_PATTERN,
        skill_number in any::<u128>(),
        summary in SUMMARY_PATTERN,
    ) {
        let prepared = prepare_workspace().map_err(fail)?;
        let proposal =
            skill_proposal_command(&skill_id_text(skill_number), &summary, "");
        let deploy = json!({
            "command": "create_approval",
            "run_id": null,
            "action": { "kind": "deploy", "target": target },
        });

        let refused = prepared.device.run(&proposal);
        let created = prepared.device.run(&deploy).map_err(fail)?;

        prop_assert!(refused.is_err());
        prop_assert_eq!(&created["action"]["target"], &json!(target));
        prop_assert_eq!(count_approval_posts(&prepared), 1);
        let listed = list_approvals(&prepared).map_err(fail)?;
        prop_assert_eq!(&listed["waiting_count"], &json!(1));
    }
}
