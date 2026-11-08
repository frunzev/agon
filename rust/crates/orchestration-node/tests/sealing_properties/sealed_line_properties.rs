use orchestration_core::workflow_document::{
    QUESTION_LINE_START, TASK_LINE_START,
};
use orchestration_core::yaml_text::render_yaml_scalar;
use orchestration_node::content_sealing::open_sealed_document;
use orchestration_security::sealing::{SEALED_TEXT_PREFIX, seal_text};
use proptest::prelude::*;

use crate::sealing_samples::{
    SEALING_CASES, hostile_text_strategy, hostile_texts_strategy,
    is_unreadable, workspace_number,
};
use crate::support::entity_strategies::sample_keyring;
use crate::support::test_device::fail;

const OTHER_LINE_STARTS: [&str; 4] =
    ["name: ", "  - name: ", "    requires: ", "    outcomes: "];

fn sealed_line_start_strategy() -> impl Strategy<Value = &'static str> {
    prop_oneof![Just(TASK_LINE_START), Just(QUESTION_LINE_START)]
}

fn line_end_strategy() -> impl Strategy<Value = &'static str> {
    prop_oneof![Just(""), Just("\n")]
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(SEALING_CASES))]

    #[test]
    fn test_open_sealed_line_property_opens_task_and_question_lines(
        line_start in sealed_line_start_strategy(),
        plain_text in hostile_text_strategy(),
        line_end in line_end_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(13)).map_err(fail)?;
        let sealed_text =
            seal_text(&workspace_key, &plain_text).map_err(fail)?;
        let rendered_seal = render_yaml_scalar(&sealed_text);
        let document = format!("{line_start}{rendered_seal}{line_end}");

        let opened = open_sealed_document(&keyring, &document).map_err(fail)?;

        let rendered_text = render_yaml_scalar(&plain_text);
        let expected = format!("{line_start}{rendered_text}{line_end}");
        prop_assert_eq!(opened, expected);
    }

    #[test]
    fn test_open_sealed_line_property_other_lines_keep_sealed_looking_text(
        line_position in 0..OTHER_LINE_STARTS.len(),
        plain_text in hostile_text_strategy(),
        line_end in line_end_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(13)).map_err(fail)?;
        let sealed_text =
            seal_text(&workspace_key, &plain_text).map_err(fail)?;
        let line_start = OTHER_LINE_STARTS[line_position];
        let rendered_seal = render_yaml_scalar(&sealed_text);
        let document = format!("{line_start}{rendered_seal}{line_end}");

        let opened = open_sealed_document(&keyring, &document).map_err(fail)?;

        prop_assert_eq!(opened, document);
    }

    #[test]
    fn test_open_sealed_line_property_keeps_the_count_of_lines(
        plain_texts in hostile_texts_strategy(),
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(13)).map_err(fail)?;
        let mut document = String::new();
        for plain_text in &plain_texts {
            let sealed_text =
                seal_text(&workspace_key, plain_text).map_err(fail)?;
            let rendered_seal = render_yaml_scalar(&sealed_text);
            document.push_str(TASK_LINE_START);
            document.push_str(&rendered_seal);
            document.push('\n');
        }

        let opened = open_sealed_document(&keyring, &document).map_err(fail)?;

        prop_assert_eq!(opened.lines().count(), plain_texts.len());
        prop_assert!(opened.ends_with('\n'));
    }

    #[test]
    fn test_read_sealed_value_property_an_unclosed_seal_is_refused(
        line_start in sealed_line_start_strategy(),
        hex_text in "[0-9a-f]{0,40}",
        line_end in line_end_strategy(),
    ) {
        let (_, keyring) = sample_keyring(workspace_number(13)).map_err(fail)?;
        let document =
            format!("{line_start}\"{SEALED_TEXT_PREFIX}{hex_text}{line_end}");

        let outcome = open_sealed_document(&keyring, &document);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }

    #[test]
    fn test_read_sealed_value_property_plain_step_texts_stay_as_they_are(
        line_start in sealed_line_start_strategy(),
        plain_text in hostile_text_strategy(),
        line_end in line_end_strategy(),
    ) {
        prop_assume!(!plain_text.starts_with(SEALED_TEXT_PREFIX));
        let (_, keyring) = sample_keyring(workspace_number(13)).map_err(fail)?;
        let rendered_text = render_yaml_scalar(&plain_text);
        let document = format!("{line_start}{rendered_text}{line_end}");

        let opened = open_sealed_document(&keyring, &document).map_err(fail)?;

        prop_assert_eq!(opened, document);
    }

    #[test]
    fn test_read_sealed_value_property_a_seal_with_stray_text_is_refused(
        line_start in sealed_line_start_strategy(),
        plain_text in hostile_text_strategy(),
        stray_text in "[a-z\"\\\\ ]{1,6}",
    ) {
        let (workspace_key, keyring) =
            sample_keyring(workspace_number(13)).map_err(fail)?;
        let sealed_text =
            seal_text(&workspace_key, &plain_text).map_err(fail)?;
        let document = format!("{line_start}\"{sealed_text}{stray_text}\"");

        let outcome = open_sealed_document(&keyring, &document);

        prop_assert!(is_unreadable(&outcome), "{:?}", outcome);
    }
}
