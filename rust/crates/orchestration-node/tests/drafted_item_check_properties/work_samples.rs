use orchestration_core::identifiers::ProjectId;
use orchestration_core::task::Schedule;
use orchestration_node::item_drafting::{DraftingContext, WorkDraft};
use proptest::prelude::*;

use crate::drafted_item_checks::{blank_text_strategy, kept_text_strategy};
use crate::support::drafting_samples::{
    context_strategy, foreign_uuid, valid_work_draft,
};

pub const INVALID_MINUTE: u32 = 60;
pub const JOB_WITHOUT_SCHEDULE: &str = "Repeats: a job needs a schedule. Ask \
                                        for changes and say how often it \
                                        repeats.";
pub const EMPTY_WORK_TITLE: &str = "What should be done: it is empty. Ask \
                                    for changes and say what should be \
                                    done.";
pub const WORK_LABELS: [&str; 6] = [
    "What should be done",
    "Project",
    "Who does it",
    "Runs on",
    "Skills to use",
    "Repeats",
];
const CHOICE_LIST_START: &str = "name one of: ";
const CHOICE_SEPARATOR: &str = ", ";
const SENTENCE_END: char = '.';
const CHOICE_COUNT: usize = 3;

pub type VariedWork = (DraftingContext, WorkDraft);

pub fn title_strategy() -> impl Strategy<Value = String> {
    prop_oneof![blank_text_strategy(), kept_text_strategy()]
}

pub fn varied_work_strategy() -> impl Strategy<Value = VariedWork> {
    (
        context_strategy(),
        title_strategy(),
        0..CHOICE_COUNT,
        0..CHOICE_COUNT,
    )
        .prop_map(|(context, title, project_choice, schedule_choice)| {
            let mut work = valid_work_draft(&context, &title, "Details");
            work.project_id = match project_choice {
                0 => work.project_id,
                1 => None,
                _ => Some(ProjectId(foreign_uuid())),
            };
            work.schedule = match schedule_choice {
                0 => work.schedule,
                1 => None,
                _ => Some(Schedule::Hour {
                    minute: INVALID_MINUTE,
                }),
            };
            (context, work)
        })
}

pub fn read_choices(problem: &str) -> Vec<String> {
    let Some((_, choice_text)) = problem.split_once(CHOICE_LIST_START) else {
        return Vec::new();
    };
    let without_end = choice_text.trim_end_matches(SENTENCE_END);
    let mut choices = Vec::new();
    for choice in without_end.split(CHOICE_SEPARATOR) {
        choices.push(choice.to_owned());
    }
    choices
}
