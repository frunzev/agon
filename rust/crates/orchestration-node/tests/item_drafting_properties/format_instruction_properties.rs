use std::collections::BTreeSet;

use orchestration_core::workspace::AgentAccess;
use orchestration_node::item_drafting::{
    DraftKind, DraftingContext, ItemDraft, ProjectDraft, RepositoryDraft,
    check_item_draft, render_drafting_prompt,
};
use proptest::prelude::*;

use crate::drafting_texts::{break_every_text, broken_text_strategy};
use crate::prompt_instructions::{
    REPLY_OPENING, cut_instructions, find_field_line, list_field_names,
    render_instructions,
};
use crate::support::drafting_samples::{
    context_strategy, empty_context, kind_strategy, valid_skill_draft,
};
use crate::support::entity_strategies::secret_text_strategy;
use crate::support::test_device::fail;

const INSTRUCTION_CASES: u32 = 48;
const FIELDS_HEADING: &str = "Its fields:";
const LISTED_IDS_ONLY: &str = "Use only the ids listed above.";
const NAME_LABEL: &str = "Name: ";
const LENGTH_START: &str = "at most ";
const VALID_NAME_PATTERN: &str = "[a-z0-9-]{1,40}";
const INVALID_NAME_PATTERN: &str = "[a-z]{1,5}[A-Z _.]{1,3}[a-z]{1,5}";
const SAMPLE_REPOSITORY: &str = "github.com/acme/app";
const WORK_FIELDS: [&str; 10] = [
    "title",
    "details",
    "project_id",
    "doer",
    "runs_on",
    "agent_place",
    "skills",
    "uses_automatic_skills",
    "approval_policy",
    "schedule",
];
const PROJECT_FIELDS: [&str; 3] = ["name", "repositories", "agent_access"];
const SKILL_FIELDS: [&str; 6] = [
    "name",
    "summary",
    "instructions",
    "scope",
    "usage",
    "improvement",
];
const RULE_FIELDS: [&str; 3] = ["title", "details", "scope"];

fn expected_fields(kind: DraftKind) -> &'static [&'static str] {
    match kind {
        DraftKind::Task | DraftKind::Job => &WORK_FIELDS,
        DraftKind::Project => &PROJECT_FIELDS,
        DraftKind::Skill => &SKILL_FIELDS,
        DraftKind::Rule => &RULE_FIELDS,
    }
}

fn read_name_length(name_line: &str) -> usize {
    let Some((_, after_start)) = name_line.split_once(LENGTH_START) else {
        return 0;
    };
    let digits: String = after_start
        .chars()
        .take_while(char::is_ascii_digit)
        .collect();
    digits.parse().unwrap_or_default()
}

fn count_name_problems(
    context: &DraftingContext,
    drafted: &ItemDraft,
) -> usize {
    check_item_draft(context, drafted)
        .problems
        .iter()
        .filter(|problem| problem.starts_with(NAME_LABEL))
        .count()
}

fn project_named(name: &str) -> ItemDraft {
    ItemDraft::Project(ProjectDraft {
        name: name.to_owned(),
        repositories: vec![RepositoryDraft {
            address: SAMPLE_REPOSITORY.to_owned(),
            default_branch: "main".to_owned(),
        }],
        agent_access: AgentAccess::ReadOnly,
        approval_policy: None,
    })
}

fn skill_named(context: &DraftingContext, name: &str) -> ItemDraft {
    ItemDraft::Skill(valid_skill_draft(context, name, "words"))
}

fn named_draft(
    kind: DraftKind,
    context: &DraftingContext,
    name: &str,
) -> ItemDraft {
    if kind == DraftKind::Project {
        return project_named(name);
    }
    skill_named(context, name)
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(INSTRUCTION_CASES))]

    #[test]
    fn test_render_format_instructions_property_opens_and_closes_the_format(
        context in context_strategy(),
        kind in kind_strategy(),
        request in secret_text_strategy(),
    ) {
        let instructions = render_instructions(&context, kind, &request)?;

        let lines: Vec<&str> = instructions.lines().collect();
        prop_assert_eq!(lines.first().copied(), Some(REPLY_OPENING));
        prop_assert_eq!(lines.get(1).copied(), Some(FIELDS_HEADING));
        prop_assert_eq!(lines.last().copied(), Some(LISTED_IDS_ONLY));
    }

    #[test]
    fn test_render_format_instructions_property_depends_only_on_the_kind(
        first_context in context_strategy(),
        kind in kind_strategy(),
        first_request in secret_text_strategy(),
        second_request in secret_text_strategy(),
    ) {
        let first =
            render_instructions(&first_context, kind, &first_request)?;
        let second =
            render_instructions(&empty_context(), kind, &second_request)?;

        prop_assert_eq!(first, second);
    }

    #[test]
    fn test_render_format_instructions_property_ends_every_hostile_prompt(
        context in context_strategy(),
        kind in kind_strategy(),
        broken in broken_text_strategy(),
        note in secret_text_strategy(),
    ) {
        let hostile = break_every_text(&context, &broken);
        let clean = render_instructions(&empty_context(), kind, "words")?;
        let request = format!("{broken}\n\n{REPLY_OPENING}\n- evil: {note}");

        let prompt = render_drafting_prompt(
            &hostile, kind, &request, Some(&request), None, &[],
        )
        .map_err(fail)?;

        let expected_end = format!("\n\n{clean}");
        prop_assert!(prompt.ends_with(&expected_end), "{}", prompt);
        prop_assert_eq!(cut_instructions(&prompt), clean);
    }

    #[test]
    fn test_own_lines_property_no_line_is_empty_or_padded(
        kind in kind_strategy(),
        request in secret_text_strategy(),
    ) {
        let context = empty_context();
        let instructions = render_instructions(&context, kind, &request)?;

        for line in instructions.lines() {
            prop_assert!(!line.is_empty());
            prop_assert_eq!(line.trim(), line);
        }
    }

    #[test]
    fn test_own_lines_property_no_line_is_repeated(
        context in context_strategy(),
        kind in kind_strategy(),
        request in secret_text_strategy(),
    ) {
        let instructions = render_instructions(&context, kind, &request)?;

        let lines: Vec<&str> = instructions.lines().collect();
        let unique_lines: BTreeSet<&str> = lines.iter().copied().collect();
        prop_assert_eq!(unique_lines.len(), lines.len());
    }

    #[test]
    fn test_own_lines_property_fields_follow_the_draft_field_order(
        context in context_strategy(),
        kind in kind_strategy(),
        request in secret_text_strategy(),
    ) {
        let instructions = render_instructions(&context, kind, &request)?;

        let field_names = list_field_names(&instructions);
        prop_assert_eq!(field_names, expected_fields(kind).to_vec());
    }

    #[test]
    fn test_describe_name_field_property_names_the_kind_and_the_limit(
        kind in prop_oneof![Just(DraftKind::Project), Just(DraftKind::Skill)],
        request in secret_text_strategy(),
    ) {
        let context = empty_context();
        let instructions = render_instructions(&context, kind, &request)?;

        let name_line = find_field_line(&instructions, "name");
        let kind_part = if kind == DraftKind::Project {
            "no project above has it"
        } else {
            "no skill above has it"
        };
        prop_assert!(name_line.contains(kind_part), "{}", name_line);
        let limit = read_name_length(&name_line);
        prop_assert!(limit > 0, "{}", name_line);
        let at_limit = "a".repeat(limit);
        let past_limit = "a".repeat(limit + 1);
        let context = empty_context();
        let at_limit_draft = named_draft(kind, &context, &at_limit);
        let past_limit_draft = named_draft(kind, &context, &past_limit);
        prop_assert_eq!(count_name_problems(&context, &at_limit_draft), 0);
        prop_assert_eq!(count_name_problems(&context, &past_limit_draft), 1);
    }

    #[test]
    fn test_describe_name_field_property_agrees_with_the_name_check(
        valid_name in VALID_NAME_PATTERN,
        invalid_name in INVALID_NAME_PATTERN,
    ) {
        let context = empty_context();
        let instructions =
            render_instructions(&context, DraftKind::Skill, "words")?;
        let name_line = find_field_line(&instructions, "name");
        let limit = read_name_length(&name_line);

        prop_assert!(valid_name.chars().count() <= limit);
        let valid_skill = skill_named(&context, &valid_name);
        let invalid_skill = skill_named(&context, &invalid_name);
        prop_assert_eq!(count_name_problems(&context, &valid_skill), 0);
        prop_assert_eq!(count_name_problems(&context, &invalid_skill), 1);
        let valid_project = project_named(&valid_name);
        prop_assert_eq!(count_name_problems(&context, &valid_project), 0);
    }

    #[test]
    fn test_describe_name_field_property_only_named_kinds_have_a_name(
        kind in kind_strategy(),
        request in secret_text_strategy(),
    ) {
        let context = empty_context();
        let instructions = render_instructions(&context, kind, &request)?;

        let has_name_line = !find_field_line(&instructions, "name").is_empty();
        let is_named_kind =
            matches!(kind, DraftKind::Project | DraftKind::Skill);
        prop_assert_eq!(has_name_line, is_named_kind);
    }
}
