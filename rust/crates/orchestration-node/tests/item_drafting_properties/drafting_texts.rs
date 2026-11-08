use orchestration_node::item_drafting::DraftingContext;
use proptest::prelude::*;

pub const LINE_BREAKS: [char; 7] = [
    '\n', '\r', '\u{0B}', '\u{0C}', '\u{85}', '\u{2028}', '\u{2029}',
];
const SECTION_HEADINGS: [&str; 4] =
    ["Projects:", "Workflows:", "Skills:", "Runners:"];
const HEADER_LINE_COUNT: usize = 2;
const ENTRY_START: &str = "- ";
const WORD_PATTERN: &str = "[A-Za-z][A-Za-z0-9:.-]{0,10}";

pub fn broken_text_strategy() -> impl Strategy<Value = String> {
    let line_break = proptest::sample::select(LINE_BREAKS.to_vec());
    (WORD_PATTERN, line_break, WORD_PATTERN).prop_map(
        |(left, line_break, right)| format!("{left}{line_break}{right}"),
    )
}

pub fn split_lines(text: &str) -> Vec<&str> {
    text.split(LINE_BREAKS).collect()
}

pub fn find_line_with<'text>(
    text: &'text str,
    needle: &str,
) -> Option<&'text str> {
    split_lines(text)
        .into_iter()
        .find(|line| line.contains(needle))
}

pub fn has_line_with_every_part(
    text: &str,
    needle: &str,
    broken: &str,
) -> bool {
    let Some(line) = find_line_with(text, needle) else {
        return false;
    };
    split_lines(broken).iter().all(|part| line.contains(part))
}

pub fn count_expected_context_lines(context: &DraftingContext) -> usize {
    let section_sizes = [
        context.projects.len(),
        context.workflows.len(),
        context.skills.len(),
        context.runners.len(),
    ];
    let mut line_count = HEADER_LINE_COUNT;
    for size in section_sizes {
        line_count += 1 + size.max(1);
    }
    line_count
}

pub fn read_section_entries(rendered: &str, heading: &str) -> Vec<String> {
    let heading_line = format!("{heading}:");
    let mut entries = Vec::new();
    let mut is_inside = false;
    for line in split_lines(rendered) {
        if is_inside {
            let Some(entry) = line.strip_prefix(ENTRY_START) else {
                break;
            };
            entries.push(entry.to_owned());
        } else {
            is_inside = line == heading_line;
        }
    }
    entries
}

pub fn is_section_heading(line: &str) -> bool {
    SECTION_HEADINGS.contains(&line)
}

pub fn break_every_text(
    context: &DraftingContext,
    broken: &str,
) -> DraftingContext {
    let mut hostile = context.clone();
    hostile.workspace.name = format!("{}{broken}", hostile.workspace.name);
    hostile.this_device.name = format!("{}{broken}", hostile.this_device.name);
    for project in &mut hostile.projects {
        project.name = format!("{}{broken}", project.name);
    }
    for workflow in &mut hostile.workflows {
        workflow.name = format!("{}{broken}", workflow.name);
    }
    for skill in &mut hostile.skills {
        skill.name = format!("{}{broken}", skill.name);
        skill.summary = format!("{}{broken}", skill.summary);
    }
    for runner in &mut hostile.runners {
        runner.device.name = format!("{}{broken}", runner.device.name);
        runner.labels.push(broken.to_owned());
    }
    hostile
}
