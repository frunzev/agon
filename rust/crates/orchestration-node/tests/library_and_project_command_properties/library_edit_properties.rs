use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::library_desk::{
    LIBRARY_CASES, SkillFields, create_rule, create_skill, everywhere_scope,
    find_listed, free_text_strategy, list_library, run_command,
    skill_fields_strategy, update_rule, update_skill, worded_title_strategy,
};
use crate::support::folder_checks::prepared_or_panic;
use crate::support::test_device::fail;

const MOST_EDITS: usize = 4;
const MOST_ENTRIES: usize = 4;
const INVALID_NAMES: [&str; 5] = [
    "",
    "Release",
    "release notes",
    "notes_v2",
    "a2345678901234567890123456789012345678901",
];

#[test]
fn test_handle_library_edit_command_property_an_edit_keeps_switch_and_date() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));
    let drawn = (worded_title_strategy(), free_text_strategy());

    let outcome = runner.run(&drawn, |(title, details)| {
        let created = create_rule(&prepared, "Old", "", &everywhere_scope())
            .map_err(fail)?;
        prepared
            .device
            .run(&json!({
                "command": "set_rule_enabled",
                "rule_id": created["id"],
                "enabled": false,
            }))
            .map_err(fail)?;
        let updated = update_rule(&prepared, &created["id"], &title, &details)
            .map_err(fail)?;
        let rules = list_library(&prepared, "list_rules").map_err(fail)?;

        prop_assert_eq!(
            find_listed(&rules, &created["id"]),
            Some(updated.clone())
        );
        prop_assert_eq!(&updated["title"], &json!(title));
        prop_assert_eq!(&updated["details"], &json!(details));
        prop_assert_eq!(&updated["enabled"], &json!(false));
        prop_assert_eq!(&updated["added_at"], &created["added_at"]);
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_handle_library_edit_command_property_delete_rule_removes_only_it() {
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));
    let drawn = (1..=MOST_ENTRIES, any::<prop::sample::Index>());

    let outcome = runner.run(&drawn, |(rule_count, deleted_index)| {
        let prepared = prepared_or_panic();
        let mut rule_ids = Vec::new();
        for _ in 0..rule_count {
            let created =
                create_rule(&prepared, "Ask", "", &everywhere_scope())
                    .map_err(fail)?;
            rule_ids.push(created["id"].clone());
        }
        let deleted_id = rule_ids.remove(deleted_index.index(rule_count));
        let deleted =
            run_command(&prepared, "delete_rule", "rule_id", &deleted_id);
        let rules = list_library(&prepared, "list_rules").map_err(fail)?;

        prop_assert_eq!(deleted, Ok(Value::Null));
        prop_assert!(find_listed(&rules, &deleted_id).is_none());
        prop_assert_eq!(rules.len(), rule_ids.len());
        for kept_id in &rule_ids {
            prop_assert!(find_listed(&rules, kept_id).is_some());
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_handle_library_edit_command_property_a_person_edit_is_not_undone() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));

    let outcome = runner.run(&skill_fields_strategy(), |fields| {
        let created = create_skill(&prepared, &fields, &everywhere_scope())
            .map_err(fail)?;
        let edited_fields = SkillFields {
            instructions: format!("{} and more", fields.instructions),
            ..fields.clone()
        };
        let edited = update_skill(&prepared, &created["id"], &edited_fields)
            .map_err(fail)?;
        let undone = run_command(
            &prepared,
            "undo_skill_change",
            "skill_id",
            &created["id"],
        );
        let skills = list_library(&prepared, "list_skills").map_err(fail)?;

        prop_assert!(undone.is_err(), "{:?}", undone);
        prop_assert_eq!(find_listed(&skills, &created["id"]), Some(edited));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_replace_skill_property_unchanged_instructions_add_no_history() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));
    let drawn = (
        skill_fields_strategy(),
        vec(free_text_strategy(), 1..=MOST_EDITS),
    );

    let outcome = runner.run(&drawn, |(fields, summaries)| {
        let created = create_skill(&prepared, &fields, &everywhere_scope())
            .map_err(fail)?;
        let mut updated = Value::Null;
        for summary in &summaries {
            let edited_fields = SkillFields {
                summary: summary.clone(),
                ..fields.clone()
            };
            updated = update_skill(&prepared, &created["id"], &edited_fields)
                .map_err(fail)?;
        }

        prop_assert_eq!(&updated["history"], &json!([]));
        prop_assert_eq!(&updated["instructions"], &json!(fields.instructions));
        prop_assert_eq!(&updated["summary"], &json!(summaries.last()));
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_replace_skill_property_each_new_instruction_is_remembered() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));
    let drawn = (skill_fields_strategy(), 1..=MOST_EDITS);

    let outcome = runner.run(&drawn, |(fields, edit_count)| {
        let created = create_skill(&prepared, &fields, &everywhere_scope())
            .map_err(fail)?;
        let mut replaced_instructions = vec![fields.instructions.clone()];
        let mut updated = Value::Null;
        for edit_number in 1..=edit_count {
            let instructions =
                format!("{} v{edit_number}", fields.instructions);
            let edited_fields = SkillFields {
                instructions: instructions.clone(),
                ..fields.clone()
            };
            updated = update_skill(&prepared, &created["id"], &edited_fields)
                .map_err(fail)?;
            replaced_instructions.push(instructions);
        }
        let skills = list_library(&prepared, "list_skills").map_err(fail)?;

        let history =
            updated["history"].as_array().cloned().unwrap_or_default();
        prop_assert_eq!(
            find_listed(&skills, &created["id"]),
            Some(updated.clone())
        );
        prop_assert_eq!(history.len(), edit_count);
        for (index, change) in history.iter().enumerate() {
            let replaced = &replaced_instructions[index];
            prop_assert_eq!(
                &change["replaced_instructions"],
                &json!(replaced)
            );
        }
        prop_assert_eq!(
            &updated["instructions"],
            &json!(replaced_instructions.last())
        );
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_replace_skill_property_refuses_invalid_names_and_keeps_the_skill() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));
    let invalid_name = proptest::sample::select(INVALID_NAMES.to_vec());

    let outcome =
        runner.run(&(skill_fields_strategy(), invalid_name), |drawn| {
            let (fields, invalid_name) = drawn;
            let created =
                create_skill(&prepared, &fields, &everywhere_scope())
                    .map_err(fail)?;
            let renamed_fields = SkillFields {
                name: invalid_name.to_owned(),
                instructions: format!("{} changed", fields.instructions),
                ..fields.clone()
            };
            let refused =
                update_skill(&prepared, &created["id"], &renamed_fields);
            let skills =
                list_library(&prepared, "list_skills").map_err(fail)?;

            prop_assert!(refused.is_err(), "{:?}", refused);
            prop_assert_eq!(
                find_listed(&skills, &created["id"]),
                Some(created)
            );
            Ok(())
        });

    assert!(outcome.is_ok(), "{outcome:?}");
}
