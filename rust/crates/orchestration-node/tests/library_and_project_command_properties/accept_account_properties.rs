use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::approver_desk::{
    APPROVED_STATE, open_desk_or_panic, read_approver_words,
    read_joiner_status,
};
use crate::library_desk::everywhere_scope;
use crate::support::test_device::{TestDevice, fail, read_text};

const JOIN_CASES: u32 = 2;
const SHARED_RULE_TITLE: &str = "Shared between devices";

fn read_device_id(device: &TestDevice) -> Result<Value, String> {
    let status = device.run(&json!({ "command": "status" }))?;
    Ok(status["device_id"].clone())
}

#[test]
fn test_accept_account_property_the_account_belongs_to_the_joiner() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));

    let outcome = runner.run(&Just(()), |()| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        read_approver_words(&desk.approver, &code).map_err(fail)?;
        desk.approve(&desk.approver, &code).map_err(fail)?;
        let approved = read_joiner_status(&joined.joiner).map_err(fail)?;
        let status = joined.joiner.run(&json!({ "command": "status" }));

        let status = status.map_err(fail)?;
        let own_device_id = read_device_id(&joined.joiner).map_err(fail)?;
        prop_assert_eq!(&approved["device"]["id"], &own_device_id);
        prop_assert_eq!(&status["account"]["device"], &approved["device"]);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_accept_account_property_the_approved_workspace_keys_open() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));

    let outcome = runner.run(&"[a-z ]{1,20}", |details| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        read_approver_words(&desk.approver, &code).map_err(fail)?;
        desk.approve(&desk.approver, &code).map_err(fail)?;
        let approved = read_joiner_status(&joined.joiner).map_err(fail)?;
        let workspace_id =
            read_text(&approved, "/workspaces/0/id").map_err(fail)?;
        let joiner_rule = joined.joiner.run(&json!({
            "command": "create_rule",
            "workspace_id": workspace_id,
            "title": SHARED_RULE_TITLE,
            "details": details,
            "scope": everywhere_scope(),
        }));
        let approver_rules = desk.approver.run(&json!({
            "command": "list_rules",
            "workspace_id": workspace_id,
        }));

        let joiner_rule = joiner_rule.map_err(fail)?;
        let approver_rules = approver_rules.map_err(fail)?;
        let listed = approver_rules.as_array().cloned().unwrap_or_default();
        prop_assert!(listed.contains(&joiner_rule), "{:?}", listed);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_accept_account_property_unshared_workspaces_stay_closed() {
    let desk = open_desk_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(JOIN_CASES));

    let outcome = runner.run(&Just(()), |()| {
        let joined = desk.start_and_join().map_err(fail)?;
        let code = joined.session["code"].clone();
        read_approver_words(&desk.approver, &code).map_err(fail)?;
        desk.approver
            .run(&json!({
                "command": "approve_pairing",
                "code": code,
                "workspace_ids": [],
            }))
            .map_err(fail)?;
        let approved = read_joiner_status(&joined.joiner).map_err(fail)?;
        let refused = joined.joiner.run(&json!({
            "command": "create_rule",
            "workspace_id": desk.account["workspaces"][0]["id"],
            "title": SHARED_RULE_TITLE,
            "details": "",
            "scope": everywhere_scope(),
        }));

        prop_assert_eq!(&approved["state"], &json!(APPROVED_STATE));
        prop_assert_eq!(&approved["workspaces"], &json!([]));
        prop_assert!(refused.is_err(), "{:?}", refused);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
