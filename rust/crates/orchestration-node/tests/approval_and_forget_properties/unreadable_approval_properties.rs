use proptest::prelude::*;
use serde_json::{Value, json};

use crate::support::test_device::fail;
use crate::unreadable_approval_desk::{
    FIRST_INSTRUCTIONS, SUMMARY, check_listings, count_waiting_views,
    create_asking_skill, find_views_of_skill, list_approvals,
    post_unreadable_proposal, propose_readably, proposed_lines,
    seal_unreadably, unreadable_texts,
};

const DEPLOY_TARGET_PATTERN: &str = "[a-z][a-z0-9-]{0,12}";

fn collect_side(changes: &Value, kept_kind: &str) -> Vec<String> {
    let mut side = Vec::new();
    for change in changes.as_array().cloned().unwrap_or_default() {
        for kind in ["unchanged", kept_kind] {
            if let Some(text) = change[kind].as_str() {
                side.push(text.to_owned());
            }
        }
    }
    side
}

fn split_lines(text: &str) -> Vec<String> {
    text.lines().map(str::to_owned).collect()
}

#[test]
fn test_build_approvals_view_property_an_unreadable_proposal_is_left_out() {
    check_listings(&unreadable_texts(), |claimed, unreadable| {
        let (skill_id, _) = create_asking_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &skill_id, &sealed).map_err(fail)?;

        let listing = list_approvals(claimed).map_err(fail)?;

        prop_assert!(find_views_of_skill(&listing, &skill_id).is_empty());
        Ok(())
    });
}

#[test]
fn test_build_approvals_view_property_readable_approvals_stay_listed() {
    let cases = (unreadable_texts(), proposed_lines());
    check_listings(&cases, |claimed, (unreadable, proposed)| {
        let (hidden_id, _) = create_asking_skill(claimed).map_err(fail)?;
        let (shown_id, _) = create_asking_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &hidden_id, &sealed)
            .map_err(fail)?;
        propose_readably(claimed, &shown_id, &proposed).map_err(fail)?;

        let listing = list_approvals(claimed).map_err(fail)?;

        let shown = find_views_of_skill(&listing, &shown_id);
        prop_assert_eq!(shown.len(), 1);
        prop_assert!(find_views_of_skill(&listing, &hidden_id).is_empty());
        let waiting_count = listing["waiting_count"].as_u64();
        let counted = u64::try_from(count_waiting_views(&listing)).ok();
        prop_assert_eq!(waiting_count, counted);
        Ok(())
    });
}

#[test]
fn test_build_approvals_view_property_the_listing_repeats_unchanged() {
    check_listings(&unreadable_texts(), |claimed, unreadable| {
        let (skill_id, _) = create_asking_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &skill_id, &sealed).map_err(fail)?;

        let first = list_approvals(claimed).map_err(fail)?;
        let second = list_approvals(claimed).map_err(fail)?;

        prop_assert_eq!(first, second);
        Ok(())
    });
}

#[test]
fn test_build_approval_view_property_opens_a_readable_proposal() {
    let cases = (unreadable_texts(), proposed_lines());
    check_listings(&cases, |claimed, (unreadable, proposed)| {
        let (hidden_id, _) = create_asking_skill(claimed).map_err(fail)?;
        let (shown_id, _) = create_asking_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &hidden_id, &sealed)
            .map_err(fail)?;
        propose_readably(claimed, &shown_id, &proposed).map_err(fail)?;

        let listing = list_approvals(claimed).map_err(fail)?;

        let shown = find_views_of_skill(&listing, &shown_id);
        let action = &shown[0]["approval"]["action"];
        prop_assert_eq!(&action["proposed_instructions"], &json!(proposed));
        prop_assert_eq!(&action["summary"], &json!(SUMMARY));
        prop_assert_eq!(&shown[0]["is_waiting"], &json!(true));
        Ok(())
    });
}

#[test]
fn test_build_approval_view_property_describes_the_skill_change() {
    let cases = (unreadable_texts(), proposed_lines());
    check_listings(&cases, |claimed, (unreadable, proposed)| {
        let (hidden_id, _) = create_asking_skill(claimed).map_err(fail)?;
        let (shown_id, shown_name) =
            create_asking_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &hidden_id, &sealed)
            .map_err(fail)?;
        propose_readably(claimed, &shown_id, &proposed).map_err(fail)?;

        let listing = list_approvals(claimed).map_err(fail)?;

        let shown = find_views_of_skill(&listing, &shown_id);
        let skill_change = &shown[0]["skill_change"];
        prop_assert_eq!(&skill_change["skill_name"], &json!(shown_name));
        let changes = &skill_change["changes"];
        prop_assert_eq!(
            collect_side(changes, "removed"),
            split_lines(FIRST_INSTRUCTIONS)
        );
        prop_assert_eq!(
            collect_side(changes, "added"),
            split_lines(&proposed)
        );
        Ok(())
    });
}

#[test]
fn test_build_approval_view_property_keeps_approvals_without_sealed_text() {
    let cases = (unreadable_texts(), DEPLOY_TARGET_PATTERN);
    check_listings(&cases, |claimed, (unreadable, target)| {
        let (hidden_id, _) = create_asking_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &hidden_id, &sealed)
            .map_err(fail)?;
        let created = claimed
            .prepared
            .device
            .run(&json!({
                "command": "create_approval",
                "run_id": null,
                "action": { "kind": "deploy", "target": target },
            }))
            .map_err(fail)?;

        let listing = list_approvals(claimed).map_err(fail)?;

        let views =
            listing["approvals"].as_array().cloned().unwrap_or_default();
        let deploy_view = views
            .iter()
            .find(|view| view["approval"]["id"] == created["id"]);
        let Some(deploy_view) = deploy_view else {
            return Err(TestCaseError::fail("the deploy approval is listed"));
        };
        let description = format!("Deploy to {target}");
        prop_assert_eq!(&deploy_view["description"], &json!(description));
        prop_assert_eq!(&deploy_view["skill_change"], &Value::Null);
        Ok(())
    });
}
