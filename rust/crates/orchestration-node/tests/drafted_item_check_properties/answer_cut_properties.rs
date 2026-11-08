use orchestration_core::identifiers::WorkspaceId;
use orchestration_core::naming::validate_name;
use orchestration_core::scope::{Scope, WorkspaceScope};
use orchestration_core::workflow::Workflow;
use orchestration_node::item_drafting::{
    DraftKind, check_new_workflow_draft, parse_item_answer,
};
use orchestration_node::node_error::NodeError;
use proptest::prelude::*;
use serde_json::{Value, json};
use uuid::Uuid;

use crate::drafted_item_checks::CHECK_CASES;
use crate::support::drafting_samples::{
    context_strategy, describe_kind, kind_strategy, valid_rule_draft,
};
use crate::support::entity_strategies::sample_workflow;

const NO_JSON_OBJECT: &str = "the answer holds no JSON object";
const BEFORE_CLOSE_PATTERN: &str = "[^{]{0,12}\\}[^{]{0,12}";
const AFTER_OPEN_PATTERN: &str = "\\{[^}]{0,12}";
const BRACELESS_PROSE_PATTERN: &str = "[^{}]{0,40}";
const BRACED_TEXT_PATTERN: &str = "[a-z {}]{0,20}";
const ANY_NAME_PATTERN: &str = "\\PC{0,48}";
const VALID_NAME_PATTERN: &str = "[a-z0-9][a-z0-9-]{0,20}";
const WORKSPACE_NUMBER: u128 = 0x51;
const FOREIGN_WORKSPACE_NUMBER: u128 = 0x52;
const UNOFFERED: &str =
    "it must be available in this workspace only or in all workspaces";

fn problem_of(
    parsed: Result<impl std::fmt::Debug, NodeError>,
) -> Result<String, TestCaseError> {
    match parsed {
        Err(NodeError::DraftNotItem { problem, .. }) => Ok(problem),
        other => Err(TestCaseError::fail(format!("not refused: {other:?}"))),
    }
}

fn required_fields(kind: DraftKind) -> &'static [&'static str] {
    match kind {
        DraftKind::Task | DraftKind::Job => &["title"],
        DraftKind::Project => &["repositories"],
        DraftKind::Skill => {
            &["name", "summary", "instructions", "scope", "usage"]
        }
        DraftKind::Rule => &["title", "scope"],
    }
}

fn full_answer(kind: DraftKind) -> Value {
    let mut answer = json!({
        "title": "Ship it",
        "repositories": [],
        "name": "notes",
        "summary": "Keeps notes",
        "instructions": "Write notes",
        "scope": Scope::everywhere(),
        "usage": "when_chosen",
    });
    let required = required_fields(kind);
    if let Some(fields) = answer.as_object_mut() {
        fields.retain(|field, _| required.contains(&field.as_str()));
    }
    answer
}

fn this_workspace() -> WorkspaceId {
    WorkspaceId(Uuid::from_u128(WORKSPACE_NUMBER))
}

fn drafted_workflow(name: &str, availability: WorkspaceScope) -> Workflow {
    Workflow {
        name: name.to_owned(),
        availability,
        ..sample_workflow(&["Plan the work".to_owned()])
    }
}

fn refusal_text(checked: Result<(), NodeError>) -> Option<String> {
    match checked {
        Err(NodeError::DraftNotWorkflow(problem)) => Some(problem),
        _ => None,
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_cut_json_object_property_a_close_before_any_open_is_no_object(
        kind in kind_strategy(),
        before_close in BEFORE_CLOSE_PATTERN,
        after_open in AFTER_OPEN_PATTERN,
    ) {
        let answer = format!("{before_close}{after_open}");

        let problem = problem_of(parse_item_answer(kind, &answer))?;

        prop_assert_eq!(problem, NO_JSON_OBJECT);
    }

    #[test]
    fn test_cut_json_object_property_keeps_braces_inside_strings(
        context in context_strategy(),
        words in BRACED_TEXT_PATTERN,
        prose in (BRACELESS_PROSE_PATTERN, BRACELESS_PROSE_PATTERN),
    ) {
        let rule = valid_rule_draft(&context, &words);
        let answer = serde_json::to_string(&rule).map_err(|error| {
            TestCaseError::fail(error.to_string())
        })?;
        let (before, after) = prose;
        let final_message = format!("{before}{answer}{after}");

        let parsed = parse_item_answer(DraftKind::Rule, &final_message);

        let expected = parse_item_answer(DraftKind::Rule, &answer);
        prop_assert_eq!(format!("{parsed:?}"), format!("{expected:?}"));
        prop_assert!(parsed.is_ok(), "{:?}", parsed);
    }

    #[test]
    fn test_cut_json_object_property_fences_read_like_the_bare_answer(
        kind in kind_strategy(),
        answer in "\\{[^{}]{0,30}\\}",
        prose in (BRACELESS_PROSE_PATTERN, BRACELESS_PROSE_PATTERN),
    ) {
        let (before, after) = prose;
        let fenced = format!("{before}\n```json\n{answer}\n```\n{after}");

        let bare_reply = format!("{:?}", parse_item_answer(kind, &answer));
        let fenced_reply = format!("{:?}", parse_item_answer(kind, &fenced));

        prop_assert_eq!(fenced_reply, bare_reply);
    }

    #[test]
    fn test_read_answer_property_names_a_missing_required_field(
        kind in kind_strategy(),
        position in any::<prop::sample::Index>(),
    ) {
        let fields = required_fields(kind);
        let dropped = fields[position.index(fields.len())];
        let mut answer = full_answer(kind);
        if let Some(object) = answer.as_object_mut() {
            object.remove(dropped);
        }

        let parsed = parse_item_answer(kind, &answer.to_string());
        let problem = problem_of(parsed)?;

        let named_field = format!("missing field `{dropped}`");
        prop_assert!(problem.contains(&named_field), "{}", problem);
    }

    #[test]
    fn test_read_answer_property_a_complete_answer_is_read(
        kind in kind_strategy(),
    ) {
        let answer = full_answer(kind).to_string();

        let parsed = parse_item_answer(kind, &answer);

        prop_assert!(parsed.is_ok(), "{:?}", parsed);
    }

    #[test]
    fn test_read_answer_property_a_refusal_is_one_line_naming_the_kind(
        kind in kind_strategy(),
        broken_value in prop_oneof![
            Just(json!(7)),
            Just(Value::Null),
            Just(json!(true)),
        ],
    ) {
        let mut answer = full_answer(kind);
        let fields = required_fields(kind);
        if let Some(object) = answer.as_object_mut() {
            for field in fields {
                object.insert((*field).to_owned(), broken_value.clone());
            }
        }

        let parsed = parse_item_answer(kind, &answer.to_string());

        let Err(error) = parsed else {
            return Err(TestCaseError::fail("a broken answer was read"));
        };
        let message = error.to_string();
        let expected_start = format!(
            "the drafting agent did not answer with a {}: ",
            describe_kind(kind)
        );
        prop_assert!(message.starts_with(&expected_start), "{}", message);
        prop_assert!(!message.contains('\n'), "{}", message);
    }

    #[test]
    fn test_check_new_workflow_draft_property_names_the_name_rule_problem(
        name in ANY_NAME_PATTERN,
    ) {
        let drafted = drafted_workflow(&name, WorkspaceScope::AllWorkspaces);

        let checked =
            check_new_workflow_draft(&drafted, this_workspace(), &[]);

        let expected = validate_name(&name).err().map(|problem| {
            problem.to_string()
        });
        prop_assert_eq!(refusal_text(checked), expected);
    }

    #[test]
    fn test_check_new_workflow_draft_property_a_taken_name_is_named(
        name in VALID_NAME_PATTERN,
        other_names in proptest::collection::vec(VALID_NAME_PATTERN, 0..4),
    ) {
        let mut taken_names = other_names;
        taken_names.push(name.clone());
        let drafted = drafted_workflow(&name, WorkspaceScope::AllWorkspaces);

        let checked =
            check_new_workflow_draft(&drafted, this_workspace(), &taken_names);

        let expected = format!("another workflow is already named {name}");
        prop_assert_eq!(refusal_text(checked), Some(expected));
    }

    #[test]
    fn test_check_new_workflow_draft_property_refuses_in_field_order(
        is_name_broken in any::<bool>(),
        is_name_taken in any::<bool>(),
    ) {
        let name = if is_name_broken { "Broken Name" } else { "release" };
        let taken_names = if is_name_taken {
            vec![name.to_owned()]
        } else {
            Vec::new()
        };
        let foreign_only = WorkspaceScope::OnlyWorkspaces {
            workspaces: vec![WorkspaceId(Uuid::from_u128(
                FOREIGN_WORKSPACE_NUMBER,
            ))],
        };
        let drafted = drafted_workflow(name, foreign_only);

        let checked =
            check_new_workflow_draft(&drafted, this_workspace(), &taken_names);

        let refusal = refusal_text(checked).unwrap_or_default();
        let expected_start = if is_name_broken {
            "a name can only use"
        } else if is_name_taken {
            "another workflow is already named"
        } else {
            UNOFFERED
        };
        prop_assert!(refusal.starts_with(expected_start), "{}", refusal);
    }
}
