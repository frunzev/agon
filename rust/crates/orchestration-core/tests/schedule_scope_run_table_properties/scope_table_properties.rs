use orchestration_core::identifiers::{ProjectId, WorkspaceId};
use orchestration_core::scope::{ProjectScope, Scope, WorkspaceScope};
use orchestration_core::scope_rules::{applies_to, workspace_scope_includes};
use proptest::prelude::*;
use proptest::sample::Index;
use serde::Deserialize;

const SHARED_SCOPE_TABLE: &str =
    include_str!("../fixtures/scope_rule_cases.json");

#[derive(Debug, Deserialize)]
struct SharedScopeTable {
    scope_rules: Vec<SharedScopeCase>,
}

#[derive(Debug, Deserialize)]
struct SharedScopeCase {
    scope: Scope,
    workspace_id: WorkspaceId,
    project_id: ProjectId,
    includes_workspace: bool,
    includes_project: bool,
    applies: bool,
}

fn read_shared_scope_cases() -> Result<Vec<SharedScopeCase>, serde_json::Error>
{
    let table: SharedScopeTable = serde_json::from_str(SHARED_SCOPE_TABLE)?;
    Ok(table.scope_rules)
}

fn includes_project(projects: &ProjectScope, project_id: ProjectId) -> bool {
    let only_projects = Scope {
        workspaces: WorkspaceScope::AllWorkspaces,
        projects: projects.clone(),
    };
    let any_workspace = WorkspaceId(uuid::Uuid::nil());
    applies_to(&only_projects, any_workspace, project_id)
}

#[test]
fn test_applies_to_property_matches_the_shared_scope_table()
-> Result<(), serde_json::Error> {
    let cases = read_shared_scope_cases()?;

    assert!(!cases.is_empty());
    for case in cases {
        let applies =
            applies_to(&case.scope, case.workspace_id, case.project_id);

        assert_eq!(applies, case.applies, "{case:?}");
    }
    Ok(())
}

#[test]
fn test_workspace_scope_includes_property_matches_the_shared_scope_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_scope_cases()? {
        let includes = workspace_scope_includes(
            &case.scope.workspaces,
            case.workspace_id,
        );

        assert_eq!(includes, case.includes_workspace, "{case:?}");
    }
    Ok(())
}

#[test]
fn test_project_scope_includes_property_matches_the_shared_scope_table()
-> Result<(), serde_json::Error> {
    for case in read_shared_scope_cases()? {
        let includes = includes_project(&case.scope.projects, case.project_id);

        assert_eq!(includes, case.includes_project, "{case:?}");
    }
    Ok(())
}

proptest! {
    #[test]
    fn test_applies_to_property_shared_answers_need_both_halves(
        picked in any::<Index>(),
    ) {
        let cases = read_shared_scope_cases()?;
        let case = picked.get(&cases);

        let both = case.includes_workspace && case.includes_project;
        prop_assert_eq!(case.applies, both, "{:?}", case);
    }
}
