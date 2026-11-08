use orchestration_core::workspace::{AgentAccess, Repository};
use orchestration_node::item_drafting::{
    DraftingContext, render_drafting_context,
};
use proptest::prelude::*;

use crate::drafting_texts::{
    break_every_text, broken_text_strategy, count_expected_context_lines,
    find_line_with, is_section_heading, read_section_entries, split_lines,
};
use crate::support::drafting_samples::context_strategy;

const CONTEXT_CASES: u32 = 48;
const SECTION_HEADINGS: [&str; 4] =
    ["Projects", "Workflows", "Skills", "Runners"];
const EMPTY_ENTRY: &str = "none";
const ADDRESS_PATTERN: &str = "github\\.com/[a-z]{2,6}/[a-z][a-z0-9-]{0,8}";
const MOST_ADDRESSES: usize = 4;
const LIST_SEPARATOR: &str = ", ";

fn section_size(context: &DraftingContext, heading: &str) -> usize {
    match heading {
        "Projects" => context.projects.len(),
        "Workflows" => context.workflows.len(),
        "Skills" => context.skills.len(),
        _ => context.runners.len(),
    }
}

fn empty_chosen_sections(
    context: &DraftingContext,
    emptied: &[bool],
) -> DraftingContext {
    let mut emptied_context = context.clone();
    if emptied[0] {
        emptied_context.projects.clear();
    }
    if emptied[1] {
        emptied_context.workflows.clear();
    }
    if emptied[2] {
        emptied_context.skills.clear();
    }
    if emptied[3] {
        emptied_context.runners.clear();
    }
    emptied_context
}

fn sample_repository(address: &str) -> Repository {
    Repository {
        address: address.to_owned(),
        default_branch: "main".to_owned(),
        agent_access: AgentAccess::ReadOnly,
    }
}

fn find_id_line(rendered: &str, id_text: &str) -> String {
    let marker = format!("(id {id_text})");
    find_line_with(rendered, &marker)
        .unwrap_or_default()
        .to_owned()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CONTEXT_CASES))]

    #[test]
    fn test_render_section_property_each_heading_holds_one_line_per_entry(
        context in context_strategy(),
    ) {
        let rendered = render_drafting_context(&context);

        for heading in SECTION_HEADINGS {
            let entries = read_section_entries(&rendered, heading);
            let expected_count = section_size(&context, heading).max(1);
            prop_assert_eq!(entries.len(), expected_count, "{}", rendered);
        }
        let heading_count = split_lines(&rendered)
            .into_iter()
            .filter(|line| is_section_heading(line))
            .count();
        prop_assert_eq!(heading_count, SECTION_HEADINGS.len());
    }

    #[test]
    fn test_render_section_property_an_empty_section_says_none_once(
        context in context_strategy(),
        emptied in proptest::collection::vec(any::<bool>(), 4),
    ) {
        let emptied_context = empty_chosen_sections(&context, &emptied);

        let rendered = render_drafting_context(&emptied_context);

        for heading in SECTION_HEADINGS {
            let entries = read_section_entries(&rendered, heading);
            let says_none = entries == vec![EMPTY_ENTRY.to_owned()];
            let is_empty = section_size(&emptied_context, heading) == 0;
            prop_assert_eq!(says_none, is_empty, "{}", rendered);
        }
    }

    #[test]
    fn test_render_section_property_line_breaks_stay_inside_their_entry(
        context in context_strategy(),
        broken in broken_text_strategy(),
    ) {
        let hostile = break_every_text(&context, &broken);

        let rendered = render_drafting_context(&hostile);

        let lines = split_lines(&rendered);
        prop_assert_eq!(
            lines.len(),
            count_expected_context_lines(&hostile),
            "{:?}",
            rendered
        );
        let heading_count = lines
            .into_iter()
            .filter(|line| is_section_heading(line))
            .count();
        prop_assert_eq!(heading_count, SECTION_HEADINGS.len());
    }

    #[test]
    fn test_describe_project_property_names_the_project_and_its_address(
        context in context_strategy(),
    ) {
        let rendered = render_drafting_context(&context);

        let entries = read_section_entries(&rendered, "Projects");
        prop_assert_eq!(entries.len(), context.projects.len());
        for (entry, project) in entries.iter().zip(&context.projects) {
            let address = &project.repositories[0].address;
            let expected =
                format!("{} (id {}): {address}", project.name, project.id.0);
            prop_assert_eq!(entry, &expected);
        }
    }

    #[test]
    fn test_describe_project_property_lists_every_address_in_order(
        context in context_strategy(),
        addresses in proptest::collection::vec(
            ADDRESS_PATTERN,
            1..MOST_ADDRESSES,
        ),
    ) {
        let mut context = context;
        let mut repositories = Vec::new();
        for address in &addresses {
            repositories.push(sample_repository(address));
        }
        context.projects[0].repositories = repositories;

        let rendered = render_drafting_context(&context);

        let project_id = context.projects[0].id.0.to_string();
        let line = find_id_line(&rendered, &project_id);
        let expected_end = format!(": {}", addresses.join(LIST_SEPARATOR));
        prop_assert!(line.ends_with(&expected_end), "{}", line);
    }

    #[test]
    fn test_describe_project_property_without_repos_has_no_address_part(
        context in context_strategy(),
    ) {
        let mut context = context;
        context.projects[0].repositories.clear();

        let rendered = render_drafting_context(&context);

        let project = &context.projects[0];
        let expected = format!("- {} (id {})", project.name, project.id.0);
        let line = find_id_line(&rendered, &project.id.0.to_string());
        prop_assert_eq!(line, expected);
    }

    #[test]
    fn test_describe_workflow_property_states_whether_it_is_signed(
        context in context_strategy(),
        signatures in proptest::collection::vec(any::<bool>(), 4),
    ) {
        let mut context = context;
        for (workflow, is_signed) in
            context.workflows.iter_mut().zip(&signatures)
        {
            workflow.is_signed = *is_signed;
        }

        let rendered = render_drafting_context(&context);

        let entries = read_section_entries(&rendered, "Workflows");
        prop_assert_eq!(entries.len(), context.workflows.len().max(1));
        for (entry, workflow) in entries.iter().zip(&context.workflows) {
            let state = if workflow.is_signed {
                "signed"
            } else {
                "not signed yet"
            };
            let expected =
                format!("{} (id {}), {state}", workflow.name, workflow.id.0);
            prop_assert_eq!(entry, &expected);
        }
    }

    #[test]
    fn test_describe_workflow_property_signing_changes_only_the_state(
        context in context_strategy(),
    ) {
        let mut unsigned = context.clone();
        for workflow in &mut unsigned.workflows {
            workflow.is_signed = false;
        }

        let signed_text = render_drafting_context(&context);
        let unsigned_text = render_drafting_context(&unsigned);

        let resigned = unsigned_text.replace(", not signed yet", ", signed");
        prop_assert_eq!(resigned, signed_text);
    }

    #[test]
    fn test_describe_workflow_property_a_broken_name_stays_on_its_line(
        context in context_strategy(),
        broken in broken_text_strategy(),
    ) {
        let hostile = break_every_text(&context, &broken);

        let rendered = render_drafting_context(&hostile);

        for workflow in &hostile.workflows {
            let line = find_id_line(&rendered, &workflow.id.0.to_string());
            for part in split_lines(&workflow.name) {
                prop_assert!(line.contains(part), "{:?}", rendered);
            }
            prop_assert!(line.ends_with(", signed"), "{:?}", line);
        }
    }
}
