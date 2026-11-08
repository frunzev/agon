use orchestration_core::naming::{convert_to_project_name, validate_name};
use orchestration_core::workspace::AgentAccess;
use orchestration_node::item_drafting::{
    CheckedDraft, ItemDraft, ProjectDraft, RepositoryDraft, check_item_draft,
};
use proptest::prelude::*;

use crate::support::drafting_samples::empty_context;

const NAME_CASES: u32 = 64;
const NAME_LABEL: &str = "Name: ";
const EMPTY_NAME_PROBLEM: &str =
    "Name: a name cannot be empty. Ask for changes and give another name.";
const GIT_SUFFIX: &str = ".git";
const OWNER_PATTERN: &str = "[A-Za-z0-9][A-Za-z0-9_-]{0,10}";
const REPOSITORY_PATTERN: &str = "[A-Za-z0-9_-][A-Za-z0-9_.-]{0,14}";
const NAME_PATTERN: &str = "[a-z0-9-]{1,20}|\\PC{1,20}";
const UNICODE_WHITE_SPACE: [char; 25] = [
    '\u{9}', '\u{A}', '\u{B}', '\u{C}', '\u{D}', '\u{20}', '\u{85}', '\u{A0}',
    '\u{1680}', '\u{2000}', '\u{2001}', '\u{2002}', '\u{2003}', '\u{2004}',
    '\u{2005}', '\u{2006}', '\u{2007}', '\u{2008}', '\u{2009}', '\u{200A}',
    '\u{2028}', '\u{2029}', '\u{202F}', '\u{205F}', '\u{3000}',
];
const MOST_PADDING: usize = 4;

fn white_space_strategy() -> impl Strategy<Value = String> {
    let character = proptest::sample::select(UNICODE_WHITE_SPACE.to_vec());
    proptest::collection::vec(character, 0..MOST_PADDING)
        .prop_map(|characters| characters.into_iter().collect())
}

fn repository_name_strategy() -> impl Strategy<Value = String> {
    REPOSITORY_PATTERN.prop_filter("a plain repository name", |name| {
        !name.ends_with(GIT_SUFFIX) && name != "." && name != ".."
    })
}

fn repository(address: &str) -> RepositoryDraft {
    RepositoryDraft {
        address: address.to_owned(),
        default_branch: "main".to_owned(),
    }
}

fn check_project(name: &str, addresses: &[String]) -> CheckedDraft {
    let mut repositories = Vec::new();
    for address in addresses {
        repositories.push(repository(address));
    }
    let drafted = ItemDraft::Project(ProjectDraft {
        name: name.to_owned(),
        repositories,
        agent_access: AgentAccess::ReadOnly,
        approval_policy: None,
    });
    check_item_draft(&empty_context(), &drafted)
}

fn read_name(checked: &CheckedDraft) -> String {
    match &checked.draft {
        ItemDraft::Project(project) => project.name.clone(),
        _ => String::new(),
    }
}

fn list_name_problems(checked: &CheckedDraft) -> Vec<String> {
    let mut name_problems = Vec::new();
    for problem in &checked.problems {
        if problem.starts_with(NAME_LABEL) {
            name_problems.push(problem.clone());
        }
    }
    name_problems
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(NAME_CASES))]

    #[test]
    fn test_pick_form_project_name_property_keeps_an_answered_name_trimmed(
        name in NAME_PATTERN,
        leading in white_space_strategy(),
        trailing in white_space_strategy(),
        owner in OWNER_PATTERN,
        repository_name in repository_name_strategy(),
    ) {
        let trimmed_name = name.trim();
        prop_assume!(!trimmed_name.is_empty());
        let address = format!("github.com/{owner}/{repository_name}");

        let checked =
            check_project(&format!("{leading}{name}{trailing}"), &[address]);

        prop_assert_eq!(read_name(&checked), trimmed_name);
        let has_name_problem = !list_name_problems(&checked).is_empty();
        let is_invalid = validate_name(trimmed_name).is_err();
        prop_assert_eq!(has_name_problem, is_invalid);
    }

    #[test]
    fn test_pick_form_project_name_property_follows_the_first_resolved_repo(
        blank_name in white_space_strategy(),
        owner in OWNER_PATTERN,
        first_name in repository_name_strategy(),
        second_name in repository_name_strategy(),
    ) {
        let addresses = vec![
            format!("ftp://github.com/{owner}/broken"),
            format!("https://GitHub.com/{owner}/{first_name}.git"),
            format!("git@github.com:{owner}/{second_name}.git"),
        ];

        let checked = check_project(&blank_name, &addresses);

        let expected = convert_to_project_name(&first_name);
        prop_assert_eq!(read_name(&checked), expected);
    }

    #[test]
    fn test_pick_form_project_name_property_a_derived_name_is_always_valid(
        blank_name in white_space_strategy(),
        owner in OWNER_PATTERN,
        repository_name in repository_name_strategy(),
        has_repository in any::<bool>(),
    ) {
        let mut addresses = vec![format!("ftp://example.com/{owner}/x")];
        if has_repository {
            addresses.push(format!("github.com/{owner}/{repository_name}"));
        }

        let checked = check_project(&blank_name, &addresses);

        let name = read_name(&checked);
        let name_problems = list_name_problems(&checked);
        if has_repository {
            prop_assert!(validate_name(&name).is_ok(), "{}", name);
            prop_assert!(name_problems.is_empty(), "{:?}", name_problems);
        } else {
            prop_assert_eq!(name, "");
            let expected = vec![EMPTY_NAME_PROBLEM.to_owned()];
            prop_assert_eq!(name_problems, expected);
        }
    }

    #[test]
    fn test_check_item_draft_property_every_address_form_is_one_canonical(
        owner in OWNER_PATTERN,
        repository_name in repository_name_strategy(),
        uses_upper_host in any::<bool>(),
    ) {
        let host = if uses_upper_host { "GitHub.COM" } else { "github.com" };
        let addresses = vec![
            format!("https://{host}/{owner}/{repository_name}"),
            format!("  https://{host}/{owner}/{repository_name}.git  "),
            format!("git@{host}:{owner}/{repository_name}.git"),
            format!("{host}/{owner}/{repository_name}/"),
        ];

        let checked = check_project("billing", &addresses);

        let ItemDraft::Project(project) = &checked.draft else {
            return Err(TestCaseError::fail("no project draft"));
        };
        let canonical = format!("github.com/{owner}/{repository_name}");
        prop_assert_eq!(&project.repositories, &vec![repository(&canonical)]);
        prop_assert!(checked.problems.is_empty(), "{:?}", checked.problems);
    }
}
