use orchestration_node::item_drafting::{
    DraftingContext, render_drafting_context,
};
use proptest::prelude::*;

use crate::drafting_texts::LINE_BREAKS;
use crate::support::drafting_samples::empty_context;

const FLATTENING_CASES: u32 = 96;
const WORKSPACE_START: &str = "Workspace: ";
const LINE_BREAK_REPLACEMENT: char = ' ';
const MOST_CHARACTERS: usize = 24;
const PLAIN_TEXT_PATTERN: &str = "[^\\p{Cc}\u{2028}\u{2029}]{0,24}";
const KEPT_CHARACTERS: [char; 6] = [
    '\u{A0}',
    '\u{200B}',
    '\u{FEFF}',
    '\u{3000}',
    '\u{1F600}',
    '\u{E9}',
];

fn any_text_strategy() -> impl Strategy<Value = String> {
    proptest::collection::vec(any::<char>(), 0..MOST_CHARACTERS)
        .prop_map(|characters| characters.into_iter().collect())
}

fn control_character_strategy() -> impl Strategy<Value = char> {
    prop_oneof![
        proptest::char::range('\u{0}', '\u{1F}'),
        proptest::char::range('\u{7F}', '\u{9F}'),
    ]
}

fn render_workspace_name(name: &str) -> String {
    let mut context: DraftingContext = empty_context();
    name.clone_into(&mut context.workspace.name);
    let rendered = render_drafting_context(&context);
    let first_line = rendered.split('\n').next().unwrap_or_default();
    let id_part = format!(" (id {})", context.workspace.id.0);
    first_line
        .strip_prefix(WORKSPACE_START)
        .and_then(|rest| rest.strip_suffix(&id_part))
        .unwrap_or_default()
        .to_owned()
}

fn is_line_breaking(character: char) -> bool {
    character.is_control() || LINE_BREAKS.contains(&character)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(FLATTENING_CASES))]

    #[test]
    fn test_keep_on_one_line_property_replaces_only_breaking_characters(
        name in any_text_strategy(),
    ) {
        let rendered = render_workspace_name(&name);

        let rendered_characters: Vec<char> = rendered.chars().collect();
        let name_characters: Vec<char> = name.chars().collect();
        prop_assert_eq!(rendered_characters.len(), name_characters.len());
        let pairs = rendered_characters.iter().zip(&name_characters);
        for (shown, original) in pairs {
            let expected = if is_line_breaking(*original) {
                LINE_BREAK_REPLACEMENT
            } else {
                *original
            };
            prop_assert_eq!(*shown, expected);
        }
    }

    #[test]
    fn test_keep_on_one_line_property_leaves_plain_text_alone(
        name in PLAIN_TEXT_PATTERN,
    ) {
        let rendered = render_workspace_name(&name);

        prop_assert_eq!(rendered, name);
    }

    #[test]
    fn test_keep_on_one_line_property_flattening_twice_changes_nothing(
        name in any_text_strategy(),
    ) {
        let once = render_workspace_name(&name);

        let twice = render_workspace_name(&once);

        prop_assert_eq!(twice, once);
    }

    #[test]
    fn test_breaks_line_property_every_line_break_becomes_a_space(
        left in PLAIN_TEXT_PATTERN,
        line_break in proptest::sample::select(LINE_BREAKS.to_vec()),
        right in PLAIN_TEXT_PATTERN,
    ) {
        let name = format!("{left}{line_break}{right}");

        let rendered = render_workspace_name(&name);

        let expected = format!("{left}{LINE_BREAK_REPLACEMENT}{right}");
        prop_assert_eq!(rendered, expected);
    }

    #[test]
    fn test_breaks_line_property_control_characters_become_spaces(
        left in PLAIN_TEXT_PATTERN,
        control in control_character_strategy(),
        right in PLAIN_TEXT_PATTERN,
    ) {
        let name = format!("{left}{control}{right}");

        let rendered = render_workspace_name(&name);

        let expected = format!("{left}{LINE_BREAK_REPLACEMENT}{right}");
        prop_assert_eq!(rendered, expected);
    }

    #[test]
    fn test_breaks_line_property_visible_and_spacing_characters_stay(
        left in PLAIN_TEXT_PATTERN,
        kept in proptest::sample::select(KEPT_CHARACTERS.to_vec()),
        right in PLAIN_TEXT_PATTERN,
    ) {
        let name = format!("{left}{kept}{right}");

        let rendered = render_workspace_name(&name);

        prop_assert_eq!(rendered, name);
    }
}
