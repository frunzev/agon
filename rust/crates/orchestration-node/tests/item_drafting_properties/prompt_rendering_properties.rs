use orchestration_node::item_drafting::{
    DraftChange, DraftKind, RepositoryDraft, render_drafting_context,
    render_drafting_prompt,
};
use proptest::prelude::*;
use serde_json::{Value, json};

use crate::drafting_texts::{break_every_text, broken_text_strategy};
use crate::prompt_instructions::render_plain_prompt;
use crate::support::drafting_samples::{
    THIS_DEVICE_ID, context_strategy, empty_context, kind_strategy,
};
use crate::support::test_device::fail;

const PROMPT_CASES: u32 = 32;
const HUGE_REQUEST_PATTERN: &str = "\\PC{4000,8000}";
const NOTE_PATTERN: &str = "\\PC{0,30}";
const FOLDER_PART_PATTERN: &str = "[A-Za-z0-9_ -]{0,6}[A-Za-z0-9_-]";
const MOST_FOLDER_PARTS: usize = 4;
const TRAILING_NOISE_PATTERN: &str = "[/ ]{0,3}";
const UNSAFE_PATHS: [&str; 6] = [
    "relative/app",
    "/a/../b",
    "/a/./b",
    "/a//b",
    "/a/\u{7}b",
    "",
];
const CHOSEN_HEADING: &str =
    "Folders the person chose on this computer (repos of this project):";

fn json_value_strategy() -> impl Strategy<Value = Value> {
    let leaf = prop_oneof![
        Just(Value::Null),
        any::<bool>().prop_map(Value::from),
        any::<i64>().prop_map(Value::from),
        "\\PC{0,12}".prop_map(Value::from),
    ];
    leaf.prop_recursive(3, 16, 4, |inner| {
        let items = proptest::collection::vec(inner.clone(), 0..4);
        let fields =
            proptest::collection::btree_map("[a-z]{1,6}", inner, 0..4);
        prop_oneof![
            items.prop_map(Value::from),
            fields.prop_map(|fields| Value::Object(
                fields.into_iter().collect()
            )),
        ]
    })
}

fn folder_parts_strategy() -> impl Strategy<Value = Vec<String>> {
    proptest::collection::vec(FOLDER_PART_PATTERN, 1..MOST_FOLDER_PARTS)
}

fn chosen_folder(path: &str) -> RepositoryDraft {
    RepositoryDraft {
        address: format!("local:{THIS_DEVICE_ID}:{path}"),
        default_branch: "main".to_owned(),
    }
}

fn read_change(change_json: &Value) -> Option<DraftChange> {
    serde_json::from_value(change_json.clone()).ok()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(PROMPT_CASES))]

    #[test]
    fn test_render_drafting_context_property_opens_with_place_lines(
        context in context_strategy(),
        broken in broken_text_strategy(),
    ) {
        let hostile = break_every_text(&context, &broken);

        let rendered = render_drafting_context(&hostile);

        let lines: Vec<&str> = rendered.split('\n').collect();
        let workspace_start = "Workspace: ";
        let workspace_end = format!(" (id {})", hostile.workspace.id.0);
        prop_assert!(lines[0].starts_with(workspace_start), "{:?}", lines);
        prop_assert!(lines[0].ends_with(&workspace_end), "{:?}", lines);
        let device_end = format!(" (id {})", hostile.this_device.id.0);
        prop_assert!(lines[1].starts_with("This computer: "));
        prop_assert!(lines[1].ends_with(&device_end), "{:?}", lines);
        prop_assert_eq!(lines[2], "Projects:");
    }

    #[test]
    fn test_render_drafting_context_property_is_the_prompt_context_part(
        context in context_strategy(),
        kind in kind_strategy(),
        request in "\\PC{1,40}",
    ) {
        let rendered = render_drafting_context(&context);

        let prompt = render_plain_prompt(&context, kind, &request)?;

        let mut prompt_lines = prompt.split('\n').skip(2);
        for context_line in rendered.split('\n') {
            prop_assert_eq!(prompt_lines.next(), Some(context_line));
        }
        prop_assert_eq!(prompt_lines.next(), Some("What the person wants:"));
    }

    #[test]
    fn test_render_drafting_prompt_property_keeps_a_huge_request_whole(
        kind in kind_strategy(),
        request in HUGE_REQUEST_PATTERN,
    ) {
        let prompt = render_plain_prompt(&empty_context(), kind, &request)?;

        let wanted = format!("\nWhat the person wants:\n{request}\n\n");
        prop_assert!(prompt.contains(&wanted));
        prop_assert!(prompt.len() > request.len());
    }

    #[test]
    fn test_draft_change_deserialize_property_keeps_any_draft_and_note(
        draft in json_value_strategy(),
        note in NOTE_PATTERN,
    ) {
        let change_json = json!({"draft": draft, "note": note});

        let change = read_change(&change_json);

        let expected = DraftChange { draft, note };
        prop_assert_eq!(change, Some(expected));
    }

    #[test]
    fn test_draft_change_deserialize_property_refuses_unknown_fields(
        draft in json_value_strategy(),
        note in NOTE_PATTERN,
        extra_name in "[a-z_]{1,10}",
        extra in json_value_strategy(),
    ) {
        prop_assume!(extra_name != "draft" && extra_name != "note");
        let mut change_json = json!({"draft": draft, "note": note});
        change_json[extra_name.as_str()] = extra;

        prop_assert_eq!(read_change(&change_json), None);
    }

    #[test]
    fn test_draft_change_deserialize_property_needs_a_draft_and_a_text_note(
        draft in json_value_strategy(),
        note in json_value_strategy(),
    ) {
        let without_note = json!({"draft": draft});
        let without_draft = json!({"note": "change it"});
        let with_any_note = json!({"draft": draft, "note": note});

        prop_assert_eq!(read_change(&without_note), None);
        prop_assert_eq!(read_change(&without_draft), None);
        let is_read = read_change(&with_any_note).is_some();
        prop_assert_eq!(is_read, note.is_string());
    }

    #[test]
    fn test_list_folder_paths_property_lists_each_normalized_path_in_order(
        folders in proptest::collection::vec(
            folder_parts_strategy(),
            1..MOST_FOLDER_PARTS,
        ),
        trailing in TRAILING_NOISE_PATTERN,
    ) {
        let mut paths = Vec::new();
        let mut chosen = Vec::new();
        for parts in &folders {
            let path = format!("/{}", parts.join("/"));
            chosen.push(chosen_folder(&format!("{path}{trailing}")));
            paths.push(path);
        }

        let prompt = render_drafting_prompt(
            &empty_context(), DraftKind::Project, "words", None, None, &chosen,
        )
        .map_err(fail)?;

        let listed: Vec<String> =
            paths.iter().map(|path| format!("- {path}")).collect();
        let expected = format!("{CHOSEN_HEADING}\n{}\n\n", listed.join("\n"));
        prop_assert!(prompt.contains(&expected), "{}", prompt);
    }

    #[test]
    fn test_list_folder_paths_property_refuses_a_non_local_address(
        address in "(https://)?github\\.com/[a-z]{1,6}/[a-z]{1,6}|/[a-z]{1,6}",
    ) {
        let chosen = vec![RepositoryDraft {
            address,
            default_branch: "main".to_owned(),
        }];

        let rendered = render_drafting_prompt(
            &empty_context(), DraftKind::Project, "words", None, None, &chosen,
        );

        prop_assert!(rendered.is_err(), "{:?}", rendered);
    }

    #[test]
    fn test_list_folder_paths_property_refuses_an_unsafe_path(
        index in 0..UNSAFE_PATHS.len(),
        safe_first in any::<bool>(),
    ) {
        let mut chosen = vec![chosen_folder(UNSAFE_PATHS[index])];
        if safe_first {
            chosen.insert(0, chosen_folder("/safe/app"));
        }

        let rendered = render_drafting_prompt(
            &empty_context(), DraftKind::Project, "words", None, None, &chosen,
        );

        prop_assert!(rendered.is_err(), "{:?}", rendered);
    }
}
