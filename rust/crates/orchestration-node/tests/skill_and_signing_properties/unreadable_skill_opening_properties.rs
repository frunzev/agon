use proptest::prelude::*;

use crate::support::test_device::fail;
use crate::unreadable_approval_desk::{
    FIRST_INSTRUCTIONS, check_listings, post_unreadable_proposal,
    proposed_lines, seal_unreadably, unreadable_texts,
};
use crate::unreadable_skill_desk::{
    UNREADABLE_PROBLEM, create_automatic_skill, find_listed_skill,
    list_skills, read_stored_skill, undo_skill_change, update_skill,
};

#[test]
fn test_open_skill_property_editing_an_unreadable_skill_fails_clearly() {
    let cases = (unreadable_texts(), proposed_lines());
    check_listings(&cases, |claimed, (unreadable, edited_lines)| {
        let skill = create_automatic_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &skill.id, &sealed).map_err(fail)?;

        let edited = update_skill(claimed, &skill, &edited_lines);

        prop_assert_eq!(edited, Err(UNREADABLE_PROBLEM.to_owned()));
        let stored = read_stored_skill(claimed, &skill.id).map_err(fail)?;
        let stored = stored.ok_or_else(|| fail("the skill is kept"))?;
        prop_assert_eq!(stored.instructions, sealed);
        Ok(())
    });
}

#[test]
fn test_open_skill_property_undoing_the_agent_change_brings_it_back() {
    check_listings(&unreadable_texts(), |claimed, unreadable| {
        let skill = create_automatic_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &skill.id, &sealed).map_err(fail)?;

        let restored = undo_skill_change(claimed, &skill.id).map_err(fail)?;

        prop_assert_eq!(&restored["instructions"], FIRST_INSTRUCTIONS);
        let listed = list_skills(claimed).map_err(fail)?;
        let listed_skill = find_listed_skill(&listed, &skill.id);
        let listed_skill = listed_skill.ok_or_else(|| fail("listed again"))?;
        prop_assert_eq!(&listed_skill["instructions"], FIRST_INSTRUCTIONS);
        Ok(())
    });
}

#[test]
fn test_open_skill_property_a_failed_edit_leaves_the_listing_alone() {
    let cases = (unreadable_texts(), proposed_lines());
    check_listings(&cases, |claimed, (unreadable, edited_lines)| {
        let skill = create_automatic_skill(claimed).map_err(fail)?;
        let sealed = seal_unreadably(&unreadable).map_err(fail)?;
        post_unreadable_proposal(claimed, &skill.id, &sealed).map_err(fail)?;
        let before = list_skills(claimed).map_err(fail)?;

        let _refused = update_skill(claimed, &skill, &edited_lines);

        let after = list_skills(claimed).map_err(fail)?;
        prop_assert_eq!(after, before);
        Ok(())
    });
}
