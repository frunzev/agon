use std::path::Path;

use proptest::prelude::*;

use crate::program_runs::{fail, hold_program_runs, run_script};

const PROGRAM_CASES: u32 = 12;
const BOTH_STREAMS_SCRIPT: &str = "printf '%s' \"$1\"; printf '%s' \"$1\" >&2";
const BYTE_SCRIPT: &str = "printf \"$1\"";
const READABLE_PATTERN: &str =
    "[a-zA-Z0-9 \u{e9}\u{fc}\u{4e16}\u{754c}]{0,30}";
const REPLACEMENT_CHARACTER: char = '\u{fffd}';
const BROKEN_BYTE_ESCAPE: &str = "\\377";

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROGRAM_CASES))]

    #[test]
    fn test_read_text_lossily_property_readable_text_comes_back_unchanged(
        text in READABLE_PATTERN,
    ) {
        let _held = hold_program_runs();

        let outcome = run_script(
            BOTH_STREAMS_SCRIPT,
            std::slice::from_ref(&text),
            Path::new("/"),
        )
        .map_err(fail)?;

        prop_assert_eq!(&outcome.output, &text);
        prop_assert_eq!(&outcome.errors, &text);
    }

    #[test]
    fn test_read_text_lossily_property_keeps_readable_text_around_damage(
        before in "[a-z]{0,10}",
        after in "[a-z]{0,10}",
    ) {
        let _held = hold_program_runs();
        let format = format!("{before}{BROKEN_BYTE_ESCAPE}{after}");

        let outcome = run_script(BYTE_SCRIPT, &[format], Path::new("/"))
            .map_err(fail)?;

        let expected = format!("{before}{REPLACEMENT_CHARACTER}{after}");
        prop_assert_eq!(outcome.output, expected);
    }

    #[test]
    fn test_read_text_lossily_property_marks_each_broken_byte(
        broken_count in 1_usize..6,
    ) {
        let _held = hold_program_runs();
        let format = BROKEN_BYTE_ESCAPE.repeat(broken_count);

        let outcome = run_script(BYTE_SCRIPT, &[format], Path::new("/"))
            .map_err(fail)?;

        let mut marks = 0;
        for character in outcome.output.chars() {
            if character == REPLACEMENT_CHARACTER {
                marks += 1;
            }
        }
        prop_assert_eq!(marks, broken_count);
        prop_assert!(outcome.has_succeeded());
    }
}
