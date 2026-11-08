use orchestration_core::identifiers::RunId;
use orchestration_core::library::{Skill, SkillChange, SkillChangeOrigin};
use orchestration_node::content_sealing::{open_skill, seal_skill};
use proptest::prelude::*;
use proptest::sample::Index;
use uuid::Uuid;

use crate::sealing_samples::{
    SEALING_CASES, foreign_keyring, hostile_text_strategy,
    hostile_texts_strategy, is_hex_only_sealed_text, is_unreadable,
    tamper_sealed_text, workspace_number,
};
use crate::support::entity_strategies::{
    sample_keyring, sample_skill, sample_time,
};
use crate::support::test_device::fail;

fn skill_with_history(instructions: &str, replaced_texts: &[String]) -> Skill {
    let mut skill = sample_skill(instructions);
    for (position, replaced_text) in replaced_texts.iter().enumerate() {
        let run_number = u128::try_from(position).unwrap_or_default();
        skill.history.push(SkillChange {
            origin: SkillChangeOrigin::ApprovedAgentRun {
                run_id: RunId(Uuid::from_u128(run_number + 1)),
            },
            saved_at: sample_time(),
            replaced_instructions: replaced_text.clone(),
        });
    }
    skill
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALING_CASES))]

    #[test]
    fn test_seal_skill_property_keeps_history_order_and_origins(
        instructions in hostile_text_strategy(),
        replaced_texts in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(3)).map_err(fail)?;
        let skill = skill_with_history(&instructions, &replaced_texts);

        let sealed_skill = seal_skill(&workspace_key, &skill).map_err(fail)?;

        prop_assert_eq!(sealed_skill.history.len(), skill.history.len());
        for (sealed, plain) in sealed_skill.history.iter().zip(&skill.history)
        {
            prop_assert_eq!(&sealed.origin, &plain.origin);
            prop_assert_eq!(sealed.saved_at, plain.saved_at);
            prop_assert!(is_hex_only_sealed_text(
                &sealed.replaced_instructions
            ));
        }
        prop_assert!(is_hex_only_sealed_text(&sealed_skill.instructions));
        prop_assert_eq!(&sealed_skill.name, &skill.name);
        prop_assert_eq!(&sealed_skill.summary, &skill.summary);
    }

    #[test]
    fn test_open_skill_property_round_trips_hostile_history(
        instructions in hostile_text_strategy(),
        replaced_texts in hostile_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(3)).map_err(fail)?;
        let skill = skill_with_history(&instructions, &replaced_texts);

        let sealed_skill = seal_skill(&workspace_key, &skill).map_err(fail)?;
        let opened_skill = open_skill(&keyring, &sealed_skill).map_err(fail)?;

        prop_assert_eq!(opened_skill, skill);
    }

    #[test]
    fn test_open_skill_property_detects_a_tampered_history_entry(
        instructions in hostile_text_strategy(),
        replaced_texts in hostile_texts_strategy(),
        entry in any::<Index>(),
        position in any::<Index>(),
        shift in any::<u8>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(3)).map_err(fail)?;
        let skill = skill_with_history(&instructions, &replaced_texts);
        let mut sealed_skill =
            seal_skill(&workspace_key, &skill).map_err(fail)?;
        let entry_position = entry.index(sealed_skill.history.len());
        let tampered_change = &mut sealed_skill.history[entry_position];
        tampered_change.replaced_instructions = tamper_sealed_text(
            &tampered_change.replaced_instructions,
            position,
            shift,
        );

        let outcome = open_skill(&keyring, &sealed_skill);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_skill_property_another_workspace_key_cannot_open(
        instructions in hostile_text_strategy(),
        replaced_texts in hostile_texts_strategy(),
    ) {
        let (workspace_key, _) =
            sample_keyring(workspace_number(3)).map_err(fail)?;
        let other_keyring = foreign_keyring().map_err(fail)?;
        let skill = skill_with_history(&instructions, &replaced_texts);

        let sealed_skill = seal_skill(&workspace_key, &skill).map_err(fail)?;
        let outcome = open_skill(&other_keyring, &sealed_skill);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_open_skill_property_refuses_an_unsealed_history_entry(
        instructions in hostile_text_strategy(),
        replaced_texts in hostile_texts_strategy(),
        entry in any::<Index>(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(3)).map_err(fail)?;
        let skill = skill_with_history(&instructions, &replaced_texts);
        let mut sealed_skill =
            seal_skill(&workspace_key, &skill).map_err(fail)?;
        let entry_position = entry.index(skill.history.len());
        sealed_skill.history[entry_position]
            .replaced_instructions
            .clone_from(&skill.history[entry_position].replaced_instructions);

        let outcome = open_skill(&keyring, &sealed_skill);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }
}
