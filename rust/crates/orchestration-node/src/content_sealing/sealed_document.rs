use std::collections::BTreeMap;

use orchestration_core::workflow_document::{
    QUESTION_LINE_START, STEP_NAME_LINE_START, TASK_LINE_START,
};
use orchestration_core::yaml_text::render_yaml_scalar;
use orchestration_security::sealing::SEALED_TEXT_PREFIX;

use super::workspace_keyring::WorkspaceKeyring;
use crate::node_error::NodeError;

const SEALED_LINE_STARTS: [&str; 2] = [TASK_LINE_START, QUESTION_LINE_START];
const QUOTE: char = '"';
const LINE_END: char = '\n';

pub fn open_sealed_document(
    keyring: &WorkspaceKeyring,
    document: &str,
) -> Result<String, NodeError> {
    let mut opened_document = String::new();
    for line in document.split_inclusive(LINE_END) {
        let opened_line = open_sealed_line(keyring, line)?;
        opened_document.push_str(&opened_line);
    }
    Ok(opened_document)
}

pub(super) fn read_step_sealed_texts(
    document: &str,
) -> BTreeMap<String, String> {
    let mut sealed_texts = BTreeMap::new();
    let mut step_name = None;
    for line in document.lines() {
        if let Some(rendered_name) = line.strip_prefix(STEP_NAME_LINE_START) {
            step_name = Some(rendered_name);
            continue;
        }
        let Some(rendered_name) = step_name else {
            continue;
        };
        if let Some(sealed_text) = find_line_sealed_text(line) {
            sealed_texts
                .insert(rendered_name.to_owned(), sealed_text.to_owned());
        }
    }
    sealed_texts
}

fn find_line_sealed_text(line_text: &str) -> Option<&str> {
    for line_start in SEALED_LINE_STARTS {
        let Some(rendered_value) = line_text.strip_prefix(line_start) else {
            continue;
        };
        if let Ok(Some(sealed_text)) = read_sealed_value(rendered_value) {
            return Some(sealed_text);
        }
    }
    None
}

fn open_sealed_line(
    keyring: &WorkspaceKeyring,
    line: &str,
) -> Result<String, NodeError> {
    let line_text = line.strip_suffix(LINE_END).unwrap_or(line);
    let line_end = &line[line_text.len()..];
    for line_start in SEALED_LINE_STARTS {
        let Some(rendered_value) = line_text.strip_prefix(line_start) else {
            continue;
        };
        let Some(sealed_text) = read_sealed_value(rendered_value)? else {
            continue;
        };
        let plain_text = keyring.open_text(sealed_text)?;
        let rendered_text = render_yaml_scalar(&plain_text);
        return Ok(format!("{line_start}{rendered_text}{line_end}"));
    }
    Ok(line.to_owned())
}

fn read_sealed_value(rendered_value: &str) -> Result<Option<&str>, NodeError> {
    let Some(quoted_text) = rendered_value.strip_prefix(QUOTE) else {
        return Ok(None);
    };
    if !quoted_text.starts_with(SEALED_TEXT_PREFIX) {
        return Ok(None);
    }
    let sealed_text = quoted_text
        .strip_suffix(QUOTE)
        .ok_or(NodeError::UnreadableSealedText)?;
    Ok(Some(sealed_text))
}
