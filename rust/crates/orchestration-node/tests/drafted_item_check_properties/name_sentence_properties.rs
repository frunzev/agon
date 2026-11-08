use orchestration_core::identifiers::ProjectId;
use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};
use orchestration_node::item_drafting::{DraftingContext, SkillDraft};
use proptest::prelude::*;
use uuid::Uuid;

use crate::drafted_item_checks::{
    CHECK_CASES, blank_text_strategy, check_project, check_skill,
    count_labelled, find_labelled, is_clear_sentence, read_labelled,
};
use crate::repository_sentence_properties::github_project;
use crate::support::draft_problem_texts::{
    join_choices, list_project_names, list_skill_names,
};
use crate::support::drafting_samples::{
    context_strategy, foreign_uuid, valid_skill_draft,
};

const NAME_LABEL: &str = "Name";
const SCOPE_LABEL: &str = "Applies to";
const GOOD_ADDRESS: &str = "https://github.com/acme/billing";
const ANY_NAME_PATTERN: &str = "\\PC{1,48}";
const VALID_NAME_PATTERN: &str = "[a-z0-9][a-z0-9-]{0,38}";
const NAME_VARIANT_COUNT: usize = 3;
const MOST_FOREIGN: usize = 4;

fn vary_name(name: &str, variant: usize) -> String {
    match variant {
        0 => name.to_owned(),
        1 => format!("{name}-x"),
        _ => format!("x-{name}"),
    }
}

fn pad(leading: &str, name: &str, trailing: &str) -> String {
    format!("{leading}{name}{trailing}")
}

fn project_name_problems(
    context: &DraftingContext,
    name: &str,
) -> Result<Vec<String>, TestCaseError> {
    let project = github_project(name, &[GOOD_ADDRESS.to_owned()]);
    let (_, problems) = check_project(context, &project)?;
    Ok(problems)
}

fn skill_name_problems(
    context: &DraftingContext,
    name: &str,
) -> Result<Vec<String>, TestCaseError> {
    let skill = SkillDraft {
        name: name.to_owned(),
        ..valid_skill_draft(context, "notes", "words")
    };
    let (_, problems) = check_skill(context, &skill)?;
    Ok(problems)
}

fn foreign_scope(context: &DraftingContext, foreign_count: usize) -> Scope {
    let mut projects = vec![context.projects[0].id];
    for number in 0..foreign_count {
        let offset = u128::try_from(number).unwrap_or_default();
        projects.push(ProjectId(Uuid::from_u128(
            foreign_uuid().as_u128() + offset,
        )));
    }
    Scope {
        workspaces: WorkspaceScope::AllWorkspaces,
        projects: ProjectScope::OnlyProjects { projects },
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_describe_taken_project_name_property_only_the_same_name_is_taken(
        context in context_strategy(),
        variant in 0..NAME_VARIANT_COUNT,
    ) {
        let taken = context.projects[0].name.clone();
        let name = vary_name(&taken, variant);

        let problems = project_name_problems(&context, &name)?;

        let is_listed = list_project_names(&context).contains(&name);
        let name_problems = count_labelled(&problems, NAME_LABEL);
        prop_assert_eq!(name_problems, usize::from(is_listed));
    }

    #[test]
    fn test_describe_taken_project_name_property_is_one_clear_sentence(
        context in context_strategy(),
        edges in (blank_text_strategy(), blank_text_strategy()),
    ) {
        let (leading, trailing) = edges;
        let taken = &context.projects[0].name;

        let problems =
            project_name_problems(&context, &pad(&leading, taken, &trailing))?;

        let problem = read_labelled(&problems, NAME_LABEL);
        let is_clear = is_clear_sentence(&problem, NAME_LABEL);
        prop_assert!(is_clear, "{}", problem);
        prop_assert!(problem.contains(&format!(" {taken} ")), "{}", problem);
    }

    #[test]
    fn test_describe_taken_project_name_property_a_skill_does_not_take_it(
        context in context_strategy(),
    ) {
        prop_assume!(!context.skills.is_empty());
        let skill_name = context.skills[0].name.clone();

        let problems = project_name_problems(&context, &skill_name)?;

        prop_assert_eq!(count_labelled(&problems, NAME_LABEL), 0);
    }

    #[test]
    fn test_describe_taken_skill_name_property_only_the_same_name_is_taken(
        context in context_strategy(),
        variant in 0..NAME_VARIANT_COUNT,
    ) {
        prop_assume!(!context.skills.is_empty());
        let name = vary_name(&context.skills[0].name, variant);

        let problems = skill_name_problems(&context, &name)?;

        let is_listed = context.skills.iter().any(|skill| skill.name == name);
        let name_problems = count_labelled(&problems, NAME_LABEL);
        prop_assert_eq!(name_problems, usize::from(is_listed));
    }

    #[test]
    fn test_describe_taken_skill_name_property_is_one_clear_sentence(
        context in context_strategy(),
        edges in (blank_text_strategy(), blank_text_strategy()),
    ) {
        prop_assume!(!context.skills.is_empty());
        let (leading, trailing) = edges;
        let taken = &context.skills[0].name;

        let problems =
            skill_name_problems(&context, &pad(&leading, taken, &trailing))?;

        let problem = read_labelled(&problems, NAME_LABEL);
        let is_clear = is_clear_sentence(&problem, NAME_LABEL);
        prop_assert!(is_clear, "{}", problem);
        prop_assert!(problem.contains(&format!(" {taken} ")), "{}", problem);
    }

    #[test]
    fn test_describe_taken_skill_name_property_a_project_does_not_take_it(
        context in context_strategy(),
    ) {
        let project_name = context.projects[0].name.clone();

        let problems = skill_name_problems(&context, &project_name)?;

        prop_assert_eq!(count_labelled(&problems, NAME_LABEL), 0);
    }

    #[test]
    fn test_find_name_problem_property_projects_and_skills_share_the_rule(
        context in context_strategy(),
        name in ANY_NAME_PATTERN,
    ) {
        prop_assume!(!name.trim().is_empty());

        let project_problems = project_name_problems(&context, &name)?;
        let skill_problems = skill_name_problems(&context, &name)?;

        let trimmed_name = name.trim().to_owned();
        let is_project_name =
            list_project_names(&context).contains(&trimmed_name);
        let is_skill_name =
            list_skill_names(&context).contains(&trimmed_name);
        let is_taken = is_project_name || is_skill_name;
        prop_assume!(!is_taken);
        prop_assert_eq!(
            find_labelled(&project_problems, NAME_LABEL),
            find_labelled(&skill_problems, NAME_LABEL)
        );
    }

    #[test]
    fn test_find_name_problem_property_is_one_clear_sentence(
        context in context_strategy(),
        name in ANY_NAME_PATTERN,
    ) {
        let problems = skill_name_problems(&context, &name)?;

        for problem in &problems {
            let is_clear = is_clear_sentence(problem, NAME_LABEL);
            prop_assert!(is_clear, "{}", problem);
        }
    }

    #[test]
    fn test_find_name_problem_property_a_rule_name_has_no_name_problem(
        context in context_strategy(),
        name in VALID_NAME_PATTERN,
        edges in (blank_text_strategy(), blank_text_strategy()),
    ) {
        let (leading, trailing) = edges;
        let padded_name = format!("{leading}{name}{trailing}");
        let is_taken = list_project_names(&context).contains(&name)
            || context.skills.iter().any(|skill| skill.name == name);
        prop_assume!(!is_taken);

        let project_problems = project_name_problems(&context, &padded_name)?;
        let skill_problems = skill_name_problems(&context, &padded_name)?;

        prop_assert!(project_problems.is_empty(), "{:?}", project_problems);
        prop_assert!(skill_problems.is_empty(), "{:?}", skill_problems);
    }

    #[test]
    fn test_describe_foreign_scope_project_property_offers_all_projects(
        context in context_strategy(),
        foreign_count in 1..MOST_FOREIGN,
    ) {
        let skill = SkillDraft {
            scope: foreign_scope(&context, foreign_count),
            ..valid_skill_draft(&context, "notes", "words")
        };

        let (_, problems) = check_skill(&context, &skill)?;

        let expected = format!(
            "Applies to: a chosen project is not in {}. Ask for changes and \
             name one of: {}.",
            context.workspace.name,
            join_choices(list_project_names(&context), "all projects")
        );
        prop_assert_eq!(problems, vec![expected]);
    }

    #[test]
    fn test_describe_foreign_scope_project_property_never_shows_an_id(
        context in context_strategy(),
        foreign_count in 1..MOST_FOREIGN,
    ) {
        let scope = foreign_scope(&context, foreign_count);
        let skill = SkillDraft {
            scope: scope.clone(),
            ..valid_skill_draft(&context, "notes", "words")
        };

        let (_, problems) = check_skill(&context, &skill)?;

        let ProjectScope::OnlyProjects { projects } = scope.projects else {
            return Err(TestCaseError::fail("the scope lists no projects"));
        };
        let problem = read_labelled(&problems, SCOPE_LABEL);
        for project_id in projects {
            prop_assert!(!problem.contains(&project_id.0.to_string()));
            let simple_id = project_id.0.simple().to_string();
            prop_assert!(!problem.contains(&simple_id));
        }
    }

    #[test]
    fn test_describe_foreign_scope_project_property_is_one_clear_sentence(
        context in context_strategy(),
        foreign_count in 1..MOST_FOREIGN,
    ) {
        let skill = SkillDraft {
            scope: foreign_scope(&context, foreign_count),
            ..valid_skill_draft(&context, "notes", "words")
        };

        let (_, problems) = check_skill(&context, &skill)?;

        prop_assert_eq!(count_labelled(&problems, SCOPE_LABEL), 1);
        let problem = read_labelled(&problems, SCOPE_LABEL);
        let is_clear = is_clear_sentence(&problem, SCOPE_LABEL);
        prop_assert!(is_clear, "{}", problem);
    }
}
