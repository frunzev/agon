use orchestration_core::protected_files::DEFAULT_PROTECTED_PATTERNS;
use proptest::collection::btree_set;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::support::command_builders::PreparedWorkspace;
use crate::support::folder_checks::prepared_or_panic;
use crate::support::test_device::fail;

const PROTECTED_CASES: u32 = 6;
const MOST_PATTERNS: usize = 6;
const PATTERN_TEXT: &str = "[a-z]{1,8}/[a-z]{1,6}\\.[a-z]{2,3}";
const INVALID_PATTERNS: [&str; 3] = ["", " secrets.txt", "keys.pem "];

fn pattern_list_strategy() -> impl Strategy<Value = Vec<String>> {
    btree_set(PATTERN_TEXT, 1..=MOST_PATTERNS)
        .prop_map(|patterns| patterns.into_iter().collect())
}

fn listed_patterns(prepared: &PreparedWorkspace) -> Result<Value, String> {
    let views = prepared
        .device
        .run(&json!({ "command": "list_workspaces" }))?;
    for view in views.as_array().cloned().unwrap_or_default() {
        let workspace = &view["workspace"];
        if workspace["id"] == json!(prepared.workspace_id) {
            return Ok(workspace["protected_files"]["patterns"].clone());
        }
    }
    Err("the workspace is not listed".to_owned())
}

fn set_patterns(
    prepared: &PreparedWorkspace,
    patterns: &[String],
) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "set_protected_files",
        "workspace_id": prepared.workspace_id,
        "patterns": patterns,
    }))
}

fn reset_patterns(prepared: &PreparedWorkspace) -> Result<Value, String> {
    prepared.device.run(&json!({
        "command": "reset_protected_files",
        "workspace_id": prepared.workspace_id,
    }))
}

#[test]
fn test_handle_protected_files_command_property_set_patterns_are_kept() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PROTECTED_CASES));

    let outcome = runner.run(&pattern_list_strategy(), |patterns| {
        let first = set_patterns(&prepared, &patterns).map_err(fail)?;
        let second = set_patterns(&prepared, &patterns).map_err(fail)?;
        let listed = listed_patterns(&prepared).map_err(fail)?;

        let replied = &first["protected_files"]["patterns"];
        prop_assert_eq!(replied, &json!(patterns));
        prop_assert_eq!(&listed, &json!(patterns));
        prop_assert_eq!(&first["id"], &json!(prepared.workspace_id));
        prop_assert_eq!(first, second);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_handle_protected_files_command_property_reset_brings_defaults() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PROTECTED_CASES));

    let outcome = runner.run(&pattern_list_strategy(), |patterns| {
        set_patterns(&prepared, &patterns).map_err(fail)?;
        let reset = reset_patterns(&prepared).map_err(fail)?;
        let listed = listed_patterns(&prepared).map_err(fail)?;

        let defaults = json!(DEFAULT_PROTECTED_PATTERNS.to_vec());
        prop_assert_eq!(&reset["protected_files"]["patterns"], &defaults);
        prop_assert_eq!(&listed, &defaults);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_handle_protected_files_command_property_a_refusal_changes_nothing() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(PROTECTED_CASES));
    let invalid_pattern = proptest::sample::select(INVALID_PATTERNS.to_vec());
    let drawn = (pattern_list_strategy(), invalid_pattern, any::<bool>());

    let outcome = runner.run(&drawn, |(patterns, invalid, is_duplicate)| {
        set_patterns(&prepared, &patterns).map_err(fail)?;
        let mut refused_patterns = patterns.clone();
        if is_duplicate {
            refused_patterns.push(patterns[0].clone());
        } else {
            refused_patterns.push(invalid.to_owned());
        }
        let refused = set_patterns(&prepared, &refused_patterns);
        let listed = listed_patterns(&prepared).map_err(fail)?;

        prop_assert!(refused.is_err(), "{:?}", refused);
        prop_assert_eq!(&listed, &json!(patterns));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
