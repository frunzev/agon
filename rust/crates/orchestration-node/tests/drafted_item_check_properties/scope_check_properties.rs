use orchestration_core::identifiers::{ProjectId, WorkspaceId};
use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};
use orchestration_node::item_drafting::{
    DraftingContext, RuleDraft, SkillDraft,
};
use proptest::prelude::*;

use crate::drafted_item_checks::{CHECK_CASES, check_rule, check_skill};
use crate::support::draft_problem_texts::{join_choices, list_project_names};
use crate::support::drafting_samples::{
    context_strategy, foreign_uuid, valid_rule_draft, valid_skill_draft,
};

const EMPTY_SCOPE: &str =
    "Applies to: it is empty. Ask for changes and say where it applies.";
const FOREIGN_WORKSPACE: &str = "Applies to: the chosen workspace does not \
                                 exist here. Ask for changes and say this \
                                 workspace or everywhere.";
const MOST_LISTED: usize = 5;

#[derive(Clone, Copy, Debug)]
enum Listed {
    Here,
    Foreign,
}

fn listed_strategy() -> impl Strategy<Value = Vec<Listed>> {
    let listed = prop_oneof![Just(Listed::Here), Just(Listed::Foreign)];
    proptest::collection::vec(listed, 0..MOST_LISTED)
}

fn listed_workspaces(
    context: &DraftingContext,
    listed: &[Listed],
) -> WorkspaceScope {
    let mut workspaces = Vec::new();
    for choice in listed {
        workspaces.push(match choice {
            Listed::Here => context.workspace.id,
            Listed::Foreign => WorkspaceId(foreign_uuid()),
        });
    }
    WorkspaceScope::OnlyWorkspaces { workspaces }
}

fn listed_projects(
    context: &DraftingContext,
    listed: &[Listed],
    position: prop::sample::Index,
) -> ProjectScope {
    let mut projects = Vec::new();
    for choice in listed {
        projects.push(match choice {
            Listed::Here => {
                context.projects[position.index(context.projects.len())].id
            }
            Listed::Foreign => ProjectId(foreign_uuid()),
        });
    }
    ProjectScope::OnlyProjects { projects }
}

fn describe_foreign_project(context: &DraftingContext) -> String {
    format!(
        "Applies to: a chosen project is not in {}. Ask for changes and \
         name one of: {}.",
        context.workspace.name,
        join_choices(list_project_names(context), "all projects")
    )
}

fn scope_problems(
    context: &DraftingContext,
    scope: &Scope,
) -> Result<Vec<String>, TestCaseError> {
    let rule = RuleDraft {
        scope: scope.clone(),
        ..valid_rule_draft(context, "words")
    };
    let (_, problems) = check_rule(context, &rule)?;
    Ok(problems)
}

fn varied_scope_strategy() -> impl Strategy<Value = (DraftingContext, Scope)> {
    (
        context_strategy(),
        proptest::option::of(listed_strategy()),
        proptest::option::of(listed_strategy()),
        any::<prop::sample::Index>(),
    )
        .prop_map(|(context, workspaces, projects, position)| {
            let workspaces = match workspaces {
                Some(listed) => listed_workspaces(&context, &listed),
                None => WorkspaceScope::AllWorkspaces,
            };
            let projects = match projects {
                Some(listed) => listed_projects(&context, &listed, position),
                None => ProjectScope::AllProjects,
            };
            (
                context,
                Scope {
                    workspaces,
                    projects,
                },
            )
        })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_find_scope_problems_property_never_repeats_a_sentence(
        (context, scope) in varied_scope_strategy(),
    ) {
        let problems = scope_problems(&context, &scope)?;

        for (index, problem) in problems.iter().enumerate() {
            prop_assert!(!problems[index + 1..].contains(problem));
        }
        prop_assert!(problems.len() <= 2, "{:?}", problems);
    }

    #[test]
    fn test_find_scope_problems_property_workspaces_come_before_projects(
        context in context_strategy(),
        has_foreign_workspace in any::<bool>(),
    ) {
        let workspaces = if has_foreign_workspace {
            listed_workspaces(&context, &[Listed::Foreign])
        } else {
            listed_workspaces(&context, &[])
        };
        let projects = ProjectScope::OnlyProjects {
            projects: vec![ProjectId(foreign_uuid())],
        };

        let scope = Scope { workspaces, projects };
        let problems = scope_problems(&context, &scope)?;

        let workspace_problem = if has_foreign_workspace {
            FOREIGN_WORKSPACE
        } else {
            EMPTY_SCOPE
        };
        let expected = vec![
            workspace_problem.to_owned(),
            describe_foreign_project(&context),
        ];
        prop_assert_eq!(problems, expected);
    }

    #[test]
    fn test_find_scope_problems_property_skills_and_rules_agree(
        (context, scope) in varied_scope_strategy(),
    ) {
        let skill = SkillDraft {
            scope: scope.clone(),
            ..valid_skill_draft(&context, "notes", "words")
        };

        let (_, skill_problems) = check_skill(&context, &skill)?;

        prop_assert_eq!(skill_problems, scope_problems(&context, &scope)?);
    }

    #[test]
    fn test_find_workspace_scope_problem_property_everywhere_is_fine(
        (context, scope) in varied_scope_strategy(),
    ) {
        let everywhere = Scope {
            workspaces: WorkspaceScope::AllWorkspaces,
            ..scope
        };

        let problems = scope_problems(&context, &everywhere)?;

        prop_assert!(!problems.contains(&FOREIGN_WORKSPACE.to_owned()));
        let all_projects = everywhere.projects == ProjectScope::AllProjects;
        prop_assert!(!all_projects || problems.is_empty(), "{:?}", problems);
    }

    #[test]
    fn test_find_workspace_scope_problem_property_any_foreign_one_is_named(
        context in context_strategy(),
        listed in listed_strategy(),
        foreign_position in any::<prop::sample::Index>(),
    ) {
        let mut listed = listed;
        let insert_at = foreign_position.index(listed.len() + 1);
        listed.insert(insert_at, Listed::Foreign);
        let scope = Scope {
            workspaces: listed_workspaces(&context, &listed),
            projects: ProjectScope::AllProjects,
        };

        let problems = scope_problems(&context, &scope)?;

        prop_assert_eq!(problems, vec![FOREIGN_WORKSPACE.to_owned()]);
    }

    #[test]
    fn test_find_workspace_scope_problem_property_repeating_here_is_fine(
        context in context_strategy(),
        repeats in 1..MOST_LISTED,
    ) {
        let listed = vec![Listed::Here; repeats];
        let scope = Scope {
            workspaces: listed_workspaces(&context, &listed),
            projects: ProjectScope::AllProjects,
        };

        let problems = scope_problems(&context, &scope)?;

        prop_assert!(problems.is_empty(), "{:?}", problems);
    }

    #[test]
    fn test_find_project_scope_problem_property_all_projects_is_fine(
        (context, scope) in varied_scope_strategy(),
    ) {
        let all_projects = Scope {
            projects: ProjectScope::AllProjects,
            ..scope
        };

        let problems = scope_problems(&context, &all_projects)?;

        let project_problem = describe_foreign_project(&context);
        prop_assert!(!problems.contains(&project_problem));
    }

    #[test]
    fn test_find_project_scope_problem_property_projects_here_are_fine(
        context in context_strategy(),
        repeats in 1..MOST_LISTED,
        position in any::<prop::sample::Index>(),
    ) {
        let listed = vec![Listed::Here; repeats];
        let scope = Scope {
            workspaces: WorkspaceScope::AllWorkspaces,
            projects: listed_projects(&context, &listed, position),
        };

        let problems = scope_problems(&context, &scope)?;

        prop_assert!(problems.is_empty(), "{:?}", problems);
    }

    #[test]
    fn test_find_project_scope_problem_property_names_every_choice(
        context in context_strategy(),
        listed in listed_strategy(),
        position in any::<prop::sample::Index>(),
    ) {
        let mut listed = listed;
        listed.push(Listed::Foreign);
        let scope = Scope {
            workspaces: WorkspaceScope::AllWorkspaces,
            projects: listed_projects(&context, &listed, position),
        };

        let problems = scope_problems(&context, &scope)?;

        prop_assert_eq!(problems, vec![describe_foreign_project(&context)]);
    }
}
