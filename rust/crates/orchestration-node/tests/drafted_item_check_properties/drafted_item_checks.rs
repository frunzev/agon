use orchestration_node::item_drafting::{
    CheckedDraft, DraftingContext, ItemDraft, ProjectDraft, RuleDraft,
    SkillDraft, WorkDraft, check_item_draft,
};
use proptest::prelude::*;

pub const CHECK_CASES: u32 = 48;
pub const UNICODE_WHITE_SPACE: [char; 25] = [
    '\u{9}', '\u{A}', '\u{B}', '\u{C}', '\u{D}', '\u{20}', '\u{85}', '\u{A0}',
    '\u{1680}', '\u{2000}', '\u{2001}', '\u{2002}', '\u{2003}', '\u{2004}',
    '\u{2005}', '\u{2006}', '\u{2007}', '\u{2008}', '\u{2009}', '\u{200A}',
    '\u{2028}', '\u{2029}', '\u{202F}', '\u{205F}', '\u{3000}',
];
pub const INVISIBLE_NON_SPACE: [char; 4] =
    ['\u{200B}', '\u{FEFF}', '\u{180E}', '\u{2060}'];
const LONGEST_BLANK: usize = 6;
const VISIBLE_TEXT_PATTERN: &str = "[A-Za-z0-9éß漢字🙂.,!?-]{1,24}";
const LABEL_END: &str = ": ";
const SENTENCE_END: char = '.';

pub type WorkWrapper = fn(WorkDraft) -> ItemDraft;

pub fn work_wrapper_strategy() -> impl Strategy<Value = WorkWrapper> {
    let task: WorkWrapper = ItemDraft::Task;
    let job: WorkWrapper = ItemDraft::Job;
    prop_oneof![Just(task), Just(job)]
}

pub fn blank_text_strategy() -> impl Strategy<Value = String> {
    let white_space = proptest::sample::select(UNICODE_WHITE_SPACE.to_vec());
    proptest::collection::vec(white_space, 0..LONGEST_BLANK)
        .prop_map(|characters| characters.into_iter().collect())
}

pub fn kept_text_strategy() -> impl Strategy<Value = String> {
    let invisible = proptest::sample::select(INVISIBLE_NON_SPACE.to_vec());
    let edge = proptest::option::of(invisible);
    (edge.clone(), VISIBLE_TEXT_PATTERN, edge).prop_map(
        |(leading, visible, trailing)| {
            let mut kept = String::new();
            kept.extend(leading);
            kept.push_str(&visible);
            kept.extend(trailing);
            kept
        },
    )
}

pub fn is_unicode_blank(text: &str) -> bool {
    text.chars()
        .all(|character| UNICODE_WHITE_SPACE.contains(&character))
}

pub fn is_clear_sentence(problem: &str, label: &str) -> bool {
    let labelled_start = format!("{label}{LABEL_END}");
    let is_one_line = !problem.chars().any(char::is_control);
    let has_double_end = problem.contains("..");
    problem.starts_with(&labelled_start)
        && problem.ends_with(SENTENCE_END)
        && is_one_line
        && !has_double_end
}

pub fn count_labelled(problems: &[String], label: &str) -> usize {
    let labelled_start = format!("{label}{LABEL_END}");
    let mut count = 0;
    for problem in problems {
        if problem.starts_with(&labelled_start) {
            count += 1;
        }
    }
    count
}

pub fn find_labelled<'problems>(
    problems: &'problems [String],
    label: &str,
) -> Option<&'problems str> {
    let labelled_start = format!("{label}{LABEL_END}");
    problems
        .iter()
        .find(|problem| problem.starts_with(&labelled_start))
        .map(String::as_str)
}

pub fn check_work(
    context: &DraftingContext,
    work: &WorkDraft,
    wrap: WorkWrapper,
) -> Result<(WorkDraft, Vec<String>), TestCaseError> {
    let checked = check_item_draft(context, &wrap(work.clone()));
    match checked.draft {
        ItemDraft::Task(checked_work) | ItemDraft::Job(checked_work) => {
            Ok((checked_work, checked.problems))
        }
        other => Err(TestCaseError::fail(format!("not work: {other:?}"))),
    }
}

pub fn check_skill(
    context: &DraftingContext,
    skill: &SkillDraft,
) -> Result<(SkillDraft, Vec<String>), TestCaseError> {
    let checked = check_item_draft(context, &ItemDraft::Skill(skill.clone()));
    let ItemDraft::Skill(checked_skill) = checked.draft else {
        return Err(TestCaseError::fail("the draft is no skill"));
    };
    Ok((checked_skill, checked.problems))
}

pub fn check_rule(
    context: &DraftingContext,
    rule: &RuleDraft,
) -> Result<(RuleDraft, Vec<String>), TestCaseError> {
    let checked = check_item_draft(context, &ItemDraft::Rule(rule.clone()));
    let ItemDraft::Rule(checked_rule) = checked.draft else {
        return Err(TestCaseError::fail("the draft is no rule"));
    };
    Ok((checked_rule, checked.problems))
}

pub fn check_project(
    context: &DraftingContext,
    project: &ProjectDraft,
) -> Result<(ProjectDraft, Vec<String>), TestCaseError> {
    let drafted = ItemDraft::Project(project.clone());
    let checked = check_item_draft(context, &drafted);
    let ItemDraft::Project(checked_project) = checked.draft else {
        return Err(TestCaseError::fail("the draft is no project"));
    };
    Ok((checked_project, checked.problems))
}

pub fn check_again(
    context: &DraftingContext,
    checked: &CheckedDraft,
) -> CheckedDraft {
    check_item_draft(context, &checked.draft)
}

pub fn read_labelled(problems: &[String], label: &str) -> String {
    find_labelled(problems, label)
        .unwrap_or_default()
        .to_owned()
}
