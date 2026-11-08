use orchestration_node::item_drafting::{
    DraftKind, DraftingContext, render_drafting_prompt,
};
use proptest::test_runner::TestCaseError;

use crate::support::test_device::fail;

pub const REPLY_OPENING: &str = "Reply with one JSON object and nothing else.";
pub const ALL_KINDS: [DraftKind; 5] = [
    DraftKind::Task,
    DraftKind::Job,
    DraftKind::Project,
    DraftKind::Skill,
    DraftKind::Rule,
];
const FIELD_LINE_START: &str = "- ";
const FIELD_NAME_END: char = ':';
const INSTRUCTIONS_GAP: &str = "\n\n";

pub fn render_plain_prompt(
    context: &DraftingContext,
    kind: DraftKind,
    request: &str,
) -> Result<String, TestCaseError> {
    render_drafting_prompt(context, kind, request, None, None, &[])
        .map_err(fail)
}

pub fn cut_instructions(prompt: &str) -> String {
    let opening = format!("{INSTRUCTIONS_GAP}{REPLY_OPENING}");
    let Some(start) = prompt.rfind(&opening) else {
        return String::new();
    };
    prompt[start + INSTRUCTIONS_GAP.len()..].to_owned()
}

pub fn render_instructions(
    context: &DraftingContext,
    kind: DraftKind,
    request: &str,
) -> Result<String, TestCaseError> {
    let prompt = render_plain_prompt(context, kind, request)?;
    Ok(cut_instructions(&prompt))
}

pub fn list_field_names(instructions: &str) -> Vec<String> {
    let mut field_names = Vec::new();
    for line in instructions.lines() {
        let Some(field_text) = line.strip_prefix(FIELD_LINE_START) else {
            continue;
        };
        let Some((field_name, _)) = field_text.split_once(FIELD_NAME_END)
        else {
            continue;
        };
        field_names.push(field_name.to_owned());
    }
    field_names
}

pub fn find_field_line(instructions: &str, field_name: &str) -> String {
    let line_start = format!("{FIELD_LINE_START}{field_name}{FIELD_NAME_END}");
    instructions
        .lines()
        .find(|line| line.starts_with(&line_start))
        .unwrap_or_default()
        .to_owned()
}
