use orchestration_core::device::RunnerTarget;
use orchestration_core::identifiers::{DeviceId, SkillId};
use orchestration_node::item_drafting::{
    DraftingDevice, DraftingRunner, ItemDraft, WorkDraft,
};
use proptest::prelude::*;

use crate::drafted_item_checks::{
    CHECK_CASES, check_work, count_labelled, work_wrapper_strategy,
};
use crate::support::draft_problem_texts::{join_choices, list_skill_names};
use crate::support::drafting_samples::{
    FOREIGN_DEVICE_ID, context_strategy, foreign_uuid, valid_work_draft,
};

const RUNNER_LABEL: &str = "Runs on";
const SKILL_LABEL: &str = "Skills to use";
const LABEL_PATTERN: &str = "\\PC{0,12}";
const MOST_LABELS: usize = 4;
const MOST_SKILLS: usize = 6;
const DEVICE_PATTERN: &str = "[0-9a-f]{6}";

fn skill_choices_strategy() -> impl Strategy<Value = Vec<Option<usize>>> {
    let choice = proptest::option::of(0..MOST_SKILLS);
    proptest::collection::vec(choice, 0..MOST_SKILLS)
}

fn listed_runner(device_id: &str) -> DraftingRunner {
    DraftingRunner {
        device: DraftingDevice {
            id: DeviceId(device_id.to_owned()),
            name: "late-computer".to_owned(),
        },
        is_online: false,
        labels: Vec::new(),
        offers: Vec::new(),
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_find_runner_problem_property_open_targets_never_have_one(
        context in context_strategy(),
        labels in proptest::option::of(
            proptest::collection::vec(LABEL_PATTERN, 0..MOST_LABELS),
        ),
    ) {
        let runs_on = match labels {
            Some(labels) => RunnerTarget::RunnerWithLabels { labels },
            None => RunnerTarget::AnyFreeRunner,
        };
        let work = WorkDraft {
            runs_on,
            ..valid_work_draft(&context, "Ship", "Ship it")
        };

        let (_, problems) = check_work(&context, &work, ItemDraft::Task)?;

        prop_assert_eq!(count_labelled(&problems, RUNNER_LABEL), 0);
    }

    #[test]
    fn test_find_runner_problem_property_problem_iff_not_listed(
        context in context_strategy(),
        device_text in DEVICE_PATTERN,
    ) {
        let work = WorkDraft {
            runs_on: RunnerTarget::SpecificRunner {
                device_id: DeviceId(device_text.clone()),
            },
            ..valid_work_draft(&context, "Ship", "Ship it")
        };

        let (_, problems) = check_work(&context, &work, ItemDraft::Task)?;

        let is_listed = context
            .runners
            .iter()
            .any(|runner| runner.device.id.0 == device_text);
        let has_problem = count_labelled(&problems, RUNNER_LABEL) == 1;
        prop_assert_eq!(has_problem, !is_listed);
    }

    #[test]
    fn test_find_runner_problem_property_listing_an_offline_runner_fixes_it(
        (context, wrap) in (context_strategy(), work_wrapper_strategy()),
    ) {
        let work = WorkDraft {
            runs_on: RunnerTarget::SpecificRunner {
                device_id: DeviceId(FOREIGN_DEVICE_ID.to_owned()),
            },
            ..valid_work_draft(&context, "Ship", "Ship it")
        };
        let mut listing_context = context.clone();
        listing_context.runners.push(listed_runner(FOREIGN_DEVICE_ID));

        let (_, unlisted_problems) = check_work(&context, &work, wrap)?;
        let (_, listed_problems) =
            check_work(&listing_context, &work, wrap)?;

        prop_assert_eq!(count_labelled(&unlisted_problems, RUNNER_LABEL), 1);
        prop_assert!(listed_problems.is_empty(), "{:?}", listed_problems);
    }

    #[test]
    fn test_find_skill_problem_property_problem_iff_a_skill_is_unknown(
        context in context_strategy(),
        choices in skill_choices_strategy(),
    ) {
        let mut skills = Vec::new();
        for choice in &choices {
            let listed = choice.and_then(|index| context.skills.get(index));
            let skill_id = listed.map_or(SkillId(foreign_uuid()), |skill| {
                skill.id
            });
            skills.push(skill_id);
        }
        let work = WorkDraft {
            skills: skills.clone(),
            ..valid_work_draft(&context, "Ship", "Ship it")
        };

        let (_, problems) = check_work(&context, &work, ItemDraft::Task)?;

        let has_unknown = skills.iter().any(|skill_id| {
            !context.skills.iter().any(|skill| skill.id == *skill_id)
        });
        let has_problem = count_labelled(&problems, SKILL_LABEL) == 1;
        prop_assert_eq!(has_problem, has_unknown);
    }

    #[test]
    fn test_find_skill_problem_property_order_and_repeats_do_not_matter(
        context in context_strategy(),
        has_unknown in any::<bool>(),
    ) {
        let mut skills: Vec<SkillId> =
            context.skills.iter().map(|skill| skill.id).collect();
        if has_unknown {
            skills.push(SkillId(foreign_uuid()));
        }
        let mut reordered = skills.clone();
        reordered.reverse();
        reordered.extend(skills.iter().copied());
        let work = valid_work_draft(&context, "Ship", "Ship it");

        let (_, problems) = check_work(
            &context,
            &WorkDraft { skills, ..work.clone() },
            ItemDraft::Task,
        )?;
        let (_, reordered_problems) = check_work(
            &context,
            &WorkDraft { skills: reordered, ..work },
            ItemDraft::Task,
        )?;

        prop_assert_eq!(problems, reordered_problems);
    }

    #[test]
    fn test_find_skill_problem_property_many_unknown_give_one_sentence(
        context in context_strategy(),
        unknown_count in 1..MOST_SKILLS,
    ) {
        let mut skills = Vec::new();
        for _ in 0..unknown_count {
            skills.push(SkillId(foreign_uuid()));
        }
        let work = WorkDraft {
            skills,
            ..valid_work_draft(&context, "Ship", "Ship it")
        };

        let (_, problems) = check_work(&context, &work, ItemDraft::Task)?;

        let expected = format!(
            "Skills to use: a chosen skill does not exist here. Ask for \
             changes and name one of: {}.",
            join_choices(list_skill_names(&context), "none")
        );
        prop_assert_eq!(problems, vec![expected]);
    }
}
