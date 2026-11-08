use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::library_desk::{
    FOREIGN_WORKSPACE_ID, LIBRARY_CASES, create_rule, create_skill,
    everywhere_scope, find_listed, free_text_strategy, list_library,
    skill_fields_strategy, worded_title_strategy, workspace_scope,
};
use crate::support::folder_checks::prepared_or_panic;
use crate::support::test_device::fail;

const MOST_SWITCHES: usize = 5;
const MOST_RULES: usize = 4;
const CREATED_SOURCE: &str = "created";
const SHORTEST_SECRET: usize = 8;
const RULE_TITLE_START: &str = "Rule number ";

fn choose_scope(workspace_id: &str, is_own: bool) -> Value {
    if is_own {
        return workspace_scope(workspace_id);
    }
    workspace_scope(FOREIGN_WORKSPACE_ID)
}

#[test]
fn test_handle_library_command_property_a_created_skill_is_listed_as_sent() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));

    let outcome = runner.run(&skill_fields_strategy(), |fields| {
        let scope = everywhere_scope();
        let created =
            create_skill(&prepared, &fields, &scope).map_err(fail)?;
        let skills = list_library(&prepared, "list_skills").map_err(fail)?;
        let listed = find_listed(&skills, &created["id"]);

        prop_assert_eq!(listed, Some(created.clone()));
        prop_assert_eq!(&created["name"], &json!(fields.name));
        prop_assert_eq!(&created["summary"], &json!(fields.summary));
        prop_assert_eq!(&created["instructions"], &json!(fields.instructions));
        prop_assert_eq!(&created["usage"], &json!(fields.usage));
        prop_assert_eq!(&created["improvement"], &json!(fields.improvement));
        prop_assert_eq!(&created["scope"], &scope);
        prop_assert_eq!(&created["source"], &json!(CREATED_SOURCE));
        prop_assert_eq!(&created["history"], &json!([]));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_handle_library_command_property_the_last_rule_switch_is_kept() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));
    let switch_sequences = vec(any::<bool>(), 1..=MOST_SWITCHES);

    let outcome = runner.run(&switch_sequences, |switches| {
        let created =
            create_rule(&prepared, "Keep it", "", &everywhere_scope())
                .map_err(fail)?;
        for enabled in &switches {
            let switch_reply = prepared.device.run(&json!({
                "command": "set_rule_enabled",
                "rule_id": created["id"],
                "enabled": enabled,
            }));
            prop_assert_eq!(switch_reply, Ok(Value::Null));
        }
        let rules = list_library(&prepared, "list_rules").map_err(fail)?;
        let listed = find_listed(&rules, &created["id"]);

        let last_switch = switches.last().copied();
        let listed_switch = listed.and_then(|rule| rule["enabled"].as_bool());
        prop_assert_eq!(listed_switch, last_switch);
        prop_assert_eq!(&created["enabled"], &json!(true));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_handle_library_command_property_foreign_skills_stay_hidden() {
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));
    let scopes = vec(any::<bool>(), 1..=MOST_RULES);

    let outcome = runner.run(&(skill_fields_strategy(), scopes), |drawn| {
        let (fields, own_scopes) = drawn;
        let prepared = prepared_or_panic();
        let mut own_ids = Vec::new();
        for is_own in &own_scopes {
            let scope = choose_scope(&prepared.workspace_id, *is_own);
            let created =
                create_skill(&prepared, &fields, &scope).map_err(fail)?;
            if *is_own {
                own_ids.push(created["id"].clone());
            }
        }
        let skills = list_library(&prepared, "list_skills").map_err(fail)?;

        let mut listed_ids = Vec::new();
        for skill in &skills {
            listed_ids.push(skill["id"].clone());
        }
        prop_assert_eq!(listed_ids.len(), own_ids.len());
        for own_id in &own_ids {
            prop_assert!(listed_ids.contains(own_id), "{:?}", listed_ids);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_list_rules_in_property_lists_exactly_the_rules_in_scope() {
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));
    let scopes = vec(any::<bool>(), 1..=MOST_RULES);

    let outcome = runner.run(&scopes, |own_scopes| {
        let prepared = prepared_or_panic();
        let mut own_ids = Vec::new();
        for is_own in &own_scopes {
            let scope = choose_scope(&prepared.workspace_id, *is_own);
            let created = create_rule(&prepared, "Ask first", "", &scope)
                .map_err(fail)?;
            if *is_own {
                own_ids.push(created["id"].clone());
            }
        }
        let rules = list_library(&prepared, "list_rules").map_err(fail)?;

        prop_assert_eq!(rules.len(), own_ids.len());
        for own_id in &own_ids {
            prop_assert!(find_listed(&rules, own_id).is_some(), "{:?}", rules);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_list_rules_in_property_details_survive_sealing() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));
    let drawn = (worded_title_strategy(), free_text_strategy());

    let outcome = runner.run(&drawn, |(title, details)| {
        let scope = everywhere_scope();
        let created =
            create_rule(&prepared, &title, &details, &scope).map_err(fail)?;
        let rules = list_library(&prepared, "list_rules").map_err(fail)?;
        let listed = find_listed(&rules, &created["id"]);

        prop_assert_eq!(listed, Some(created.clone()));
        prop_assert_eq!(&created["title"], &json!(title));
        prop_assert_eq!(&created["details"], &json!(details));
        let stored = prepared.server.read_stored_state().map_err(fail)?;
        let is_worded = details.chars().any(char::is_alphanumeric);
        if details.chars().count() > SHORTEST_SECRET && is_worded {
            prop_assert!(!stored.contains(&details), "{}", details);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_list_rules_in_property_markdown_shows_only_listed_rules() {
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));
    let scopes = vec(any::<bool>(), 1..=MOST_RULES);

    let outcome = runner.run(&scopes, |drawn_rules| {
        let prepared = prepared_or_panic();
        for (index, is_own) in drawn_rules.iter().enumerate() {
            let title = format!("{RULE_TITLE_START}{index}");
            let scope = choose_scope(&prepared.workspace_id, *is_own);
            create_rule(&prepared, &title, "", &scope).map_err(fail)?;
        }
        let shown = prepared
            .device
            .run(&json!({
                "command": "show_agents_markdown",
                "workspace_id": prepared.workspace_id,
                "project_id": prepared.project_id,
            }))
            .map_err(fail)?;

        let markdown = shown["markdown"].as_str().unwrap_or_default();
        for (index, is_own) in drawn_rules.iter().enumerate() {
            let title = format!("{RULE_TITLE_START}{index}");
            let rule_line = format!("- {title}.");
            let is_shown = markdown.lines().any(|line| line == rule_line);
            prop_assert_eq!(is_shown, *is_own, "{}", markdown);
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
