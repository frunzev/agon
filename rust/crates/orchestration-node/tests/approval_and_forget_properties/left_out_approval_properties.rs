use orchestration_core::approval::{ApprovalAction, ApprovalRequest};
use proptest::prelude::*;
use serde_json::Value;

use crate::support::runner_access::ClaimedRun;
use crate::support::server_access::use_server_at;
use crate::support::test_device::fail;
use crate::unreadable_approval_desk::{
    check_listings, create_asking_skill, list_approvals,
    post_unreadable_proposal, seal_unreadably, unreadable_texts,
};

const LISTING_FIELDS: [&str; 2] = ["approvals", "waiting_count"];
const VIEW_FIELDS: [&str; 4] =
    ["approval", "description", "is_waiting", "skill_change"];
const MOST_REPEATED_PROPOSALS: usize = 3;

fn sorted_keys(value: &Value) -> Vec<String> {
    let mut keys = Vec::new();
    if let Some(fields) = value.as_object() {
        for key in fields.keys() {
            keys.push(key.clone());
        }
    }
    keys.sort();
    keys
}

fn owned_texts(texts: &[&str]) -> Vec<String> {
    texts.iter().map(|text| (*text).to_owned()).collect()
}

fn read_server_approvals(
    claimed: &ClaimedRun,
) -> Result<Vec<ApprovalRequest>, String> {
    let identity = claimed.prepared.device.load_identity()?;
    use_server_at(&claimed.prepared.server.address, async |server| {
        server.signed(&identity).list_approvals().await
    })
}

fn is_proposal_for(approval: &ApprovalRequest, skill_id: &str) -> bool {
    let ApprovalAction::ImproveSkill {
        skill_id: wanted, ..
    } = &approval.action
    else {
        return false;
    };
    wanted.0.to_string() == skill_id
}

#[test]
fn test_log_left_out_approval_property_the_reply_keeps_its_shape() {
    check_listings(&unreadable_texts(), |claimed, unreadable| {
        let (skill_id, _) = create_asking_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &skill_id, &sealed).map_err(fail)?;

        let listing = list_approvals(claimed).map_err(fail)?;

        prop_assert_eq!(sorted_keys(&listing), owned_texts(&LISTING_FIELDS));
        let views =
            listing["approvals"].as_array().cloned().unwrap_or_default();
        for view in &views {
            prop_assert_eq!(sorted_keys(view), owned_texts(&VIEW_FIELDS));
        }
        Ok(())
    });
}

#[test]
fn test_log_left_out_approval_property_every_listing_still_answers() {
    let cases = proptest::collection::vec(
        unreadable_texts(),
        1..=MOST_REPEATED_PROPOSALS,
    );
    check_listings(&cases, |claimed, unreadable_texts| {
        for unreadable in &unreadable_texts {
            let (skill_id, _) = create_asking_skill(claimed).map_err(fail)?;
            let sealed = seal_unreadably(unreadable).map_err(fail)?;
            post_unreadable_proposal(claimed, &skill_id, &sealed)
                .map_err(fail)?;

            let listing = list_approvals(claimed);

            prop_assert!(listing.is_ok(), "{:?}", listing);
        }
        Ok(())
    });
}

#[test]
fn test_log_left_out_approval_property_the_server_keeps_the_approval() {
    check_listings(&unreadable_texts(), |claimed, unreadable| {
        let (skill_id, _) = create_asking_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &skill_id, &sealed).map_err(fail)?;

        list_approvals(claimed).map_err(fail)?;

        let kept = read_server_approvals(claimed).map_err(fail)?;
        let proposals: Vec<&ApprovalRequest> = kept
            .iter()
            .filter(|approval| is_proposal_for(approval, &skill_id))
            .collect();
        prop_assert_eq!(proposals.len(), 1);
        prop_assert!(proposals[0].decision.is_none());
        Ok(())
    });
}
