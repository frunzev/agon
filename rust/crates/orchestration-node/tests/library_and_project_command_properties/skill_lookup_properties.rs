use proptest::collection::vec;
use proptest::prelude::*;
use proptest::test_runner::{Config, TestRunner};
use serde_json::{Value, json};

use crate::library_desk::{
    LIBRARY_CASES, SkillFields, create_skill, everywhere_scope, find_listed,
    list_library, run_command, skill_fields_strategy, update_skill,
};
use crate::support::folder_checks::prepared_or_panic;
use crate::support::test_device::fail;

const MOST_SKILLS: usize = 4;
const UNKNOWN_SKILL_ID: &str = "00000000-0000-0000-0000-00000000a5c1";

fn skill_id_strategy() -> impl Strategy<Value = String> {
    "[0-9a-f]{8}"
        .prop_map(|tail| format!("00000000-0000-4000-8000-0000{tail}"))
}

#[test]
fn test_find_stored_skill_property_an_unknown_skill_is_not_found() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));

    let outcome =
        runner.run(&(skill_fields_strategy(), skill_id_strategy()), |drawn| {
            let (fields, skill_id) = drawn;
            create_skill(&prepared, &fields, &everywhere_scope())
                .map_err(fail)?;
            let refused = update_skill(&prepared, &json!(skill_id), &fields);

            let expected = format!("skill {skill_id} was not found");
            prop_assert_eq!(refused, Err(expected));
            Ok(())
        });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_find_stored_skill_property_a_deleted_skill_is_not_found() {
    let prepared = prepared_or_panic();
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));

    let outcome = runner.run(&skill_fields_strategy(), |fields| {
        let created = create_skill(&prepared, &fields, &everywhere_scope())
            .map_err(fail)?;
        let skill_id = created["id"].clone();
        let deleted =
            run_command(&prepared, "delete_skill", "skill_id", &skill_id);
        let refused = update_skill(&prepared, &skill_id, &fields);

        let identifier = skill_id.as_str().unwrap_or(UNKNOWN_SKILL_ID);
        prop_assert_eq!(deleted, Ok(Value::Null));
        prop_assert_eq!(
            refused,
            Err(format!("skill {identifier} was not found"))
        );
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}

#[test]
fn test_find_stored_skill_property_only_the_chosen_skill_changes() {
    let mut runner = TestRunner::new(Config::with_cases(LIBRARY_CASES));
    let drawn = (
        vec(skill_fields_strategy(), 1..=MOST_SKILLS),
        any::<prop::sample::Index>(),
    );

    let outcome = runner.run(&drawn, |(all_fields, chosen_index)| {
        let prepared = prepared_or_panic();
        let mut created_skills = Vec::new();
        for fields in &all_fields {
            let created = create_skill(&prepared, fields, &everywhere_scope())
                .map_err(fail)?;
            created_skills.push(created);
        }
        let chosen = chosen_index.index(all_fields.len());
        let chosen_fields = SkillFields {
            summary: "chosen".to_owned(),
            ..all_fields[chosen].clone()
        };
        let chosen_id = created_skills[chosen]["id"].clone();
        let updated = update_skill(&prepared, &chosen_id, &chosen_fields)
            .map_err(fail)?;
        let skills = list_library(&prepared, "list_skills").map_err(fail)?;

        for (index, created) in created_skills.iter().enumerate() {
            let listed = find_listed(&skills, &created["id"]);
            let expected = if index == chosen { &updated } else { created };
            prop_assert_eq!(listed.as_ref(), Some(expected));
        }
        Ok(())
    });

    assert!(outcome.is_ok(), "{outcome:?}");
}
