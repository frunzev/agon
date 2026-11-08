use proptest::prelude::*;

use crate::support::test_device::fail;
use crate::unreadable_approval_desk::{
    FIRST_INSTRUCTIONS, check_listings, post_unreadable_proposal,
    propose_readably, proposed_lines, seal_unreadably, unreadable_texts,
};
use crate::unreadable_skill_desk::{
    create_automatic_skill, find_listed_skill, list_skills, read_stored_skill,
};

const MOST_UNREADABLE_SKILLS: usize = 3;

#[test]
fn test_list_usable_skills_property_an_unreadable_skill_is_left_out() {
    check_listings(&unreadable_texts(), |claimed, unreadable| {
        let skill = create_automatic_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &skill.id, &sealed).map_err(fail)?;

        let listed = list_skills(claimed);

        let listed = listed.map_err(fail)?;
        prop_assert!(find_listed_skill(&listed, &skill.id).is_none());
        Ok(())
    });
}

#[test]
fn test_list_usable_skills_property_readable_skills_stay_listed() {
    let cases = (unreadable_texts(), proposed_lines());
    check_listings(&cases, |claimed, (unreadable, readable_lines)| {
        let broken = create_automatic_skill(claimed).map_err(fail)?;
        let improved = create_automatic_skill(claimed).map_err(fail)?;
        let untouched = create_automatic_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &broken.id, &sealed)
            .map_err(fail)?;
        propose_readably(claimed, &improved.id, &readable_lines)
            .map_err(fail)?;

        let listed = list_skills(claimed).map_err(fail)?;

        let improved_view = find_listed_skill(&listed, &improved.id);
        let improved_view = improved_view.ok_or_else(|| fail("improved"))?;
        prop_assert_eq!(&improved_view["instructions"], &readable_lines);
        let untouched_view = find_listed_skill(&listed, &untouched.id);
        let untouched_view =
            untouched_view.ok_or_else(|| fail("untouched"))?;
        prop_assert_eq!(&untouched_view["instructions"], FIRST_INSTRUCTIONS);
        prop_assert!(find_listed_skill(&listed, &broken.id).is_none());
        Ok(())
    });
}

#[test]
fn test_list_usable_skills_property_every_listing_still_answers() {
    let cases = proptest::collection::vec(
        unreadable_texts(),
        1..=MOST_UNREADABLE_SKILLS,
    );
    check_listings(&cases, |claimed, unreadable_texts| {
        for unreadable in &unreadable_texts {
            let skill = create_automatic_skill(claimed).map_err(fail)?;
            let sealed = seal_unreadably(unreadable).map_err(fail)?;
            post_unreadable_proposal(claimed, &skill.id, &sealed)
                .map_err(fail)?;

            let listed = list_skills(claimed);

            prop_assert!(listed.is_ok(), "{:?}", listed);
        }
        Ok(())
    });
}

#[test]
fn test_log_left_out_skill_property_the_server_keeps_the_skill() {
    check_listings(&unreadable_texts(), |claimed, unreadable| {
        let skill = create_automatic_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &skill.id, &sealed).map_err(fail)?;

        list_skills(claimed).map_err(fail)?;

        let stored = read_stored_skill(claimed, &skill.id).map_err(fail)?;
        let stored = stored.ok_or_else(|| fail("the skill is kept"))?;
        prop_assert_eq!(stored.instructions, sealed);
        prop_assert_eq!(stored.history.len(), 1);
        Ok(())
    });
}

#[test]
fn test_log_left_out_skill_property_listing_twice_answers_the_same() {
    check_listings(&unreadable_texts(), |claimed, unreadable| {
        let skill = create_automatic_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &skill.id, &sealed).map_err(fail)?;

        let first = list_skills(claimed).map_err(fail)?;
        let second = list_skills(claimed).map_err(fail)?;

        prop_assert_eq!(first, second);
        Ok(())
    });
}

#[test]
fn test_log_left_out_skill_property_listed_skills_are_all_readable() {
    check_listings(&unreadable_texts(), |claimed, unreadable| {
        let skill = create_automatic_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &skill.id, &sealed).map_err(fail)?;

        let listed = list_skills(claimed).map_err(fail)?;

        for listed_skill in &listed {
            let instructions =
                listed_skill["instructions"].as_str().unwrap_or_default();
            prop_assert!(!instructions.starts_with("sealed-v1:"));
        }
        Ok(())
    });
}
