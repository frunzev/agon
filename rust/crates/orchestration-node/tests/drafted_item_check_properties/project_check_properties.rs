use orchestration_core::approval::ApprovalPolicy;
use orchestration_core::naming::validate_name;
use orchestration_core::repository_address::parse_repository_address;
use orchestration_core::workspace::AgentAccess;
use orchestration_node::item_drafting::{
    ItemDraft, ProjectDraft, RepositoryDraft, check_item_draft,
};
use proptest::prelude::*;

use crate::drafted_item_checks::{
    CHECK_CASES, blank_text_strategy, check_again, check_project,
    count_labelled,
};
use crate::repository_sentence_properties::github_project;
use crate::support::drafting_samples::{
    FOREIGN_DEVICE_ID, context_strategy, empty_context, padded,
};

const OWNER_PATTERN: &str = "[A-Za-z0-9][A-Za-z0-9_-]{0,8}";
const REPOSITORY_PATTERN: &str = "[a-z][a-z0-9_-]{0,8}";
const BRANCH_PATTERN: &str = "[a-z][a-z0-9/._-]{0,10}";
const ANY_NAME_PATTERN: &str = "\\PC{1,48}";
const FOLDER_PATH_PATTERN: &str = "(/[a-z][a-z0-9]{0,6}){1,3}";
const NAME_LABEL: &str = "Name";
const NAME_FIX: &str = "Ask for changes and give another name.";
const REPOSITORY_FIX: &str = "Ask for changes and give a GitHub address or a \
                              git folder on this computer.";
const SPELLING_COUNT: usize = 5;
const MOST_REPOSITORIES: usize = 4;

fn spell_address(owner: &str, repository: &str, spelling: usize) -> String {
    match spelling {
        0 => format!("https://github.com/{owner}/{repository}"),
        1 => format!("https://GitHub.com/{owner}/{repository}.git"),
        2 => format!("git@github.com:{owner}/{repository}.git"),
        3 => format!("github.com/{owner}/{repository}/"),
        _ => format!("  https://github.com/{owner}/{repository}  "),
    }
}

fn spelled_addresses_strategy() -> impl Strategy<Value = Vec<String>> {
    let spelled = (OWNER_PATTERN, REPOSITORY_PATTERN, 0..SPELLING_COUNT)
        .prop_map(|(owner, repository, spelling)| {
            spell_address(&owner, &repository, spelling)
        });
    proptest::collection::vec(spelled, 1..MOST_REPOSITORIES)
}

fn policy_strategy() -> impl Strategy<Value = Option<ApprovalPolicy>> {
    proptest::option::of(prop_oneof![
        Just(ApprovalPolicy::AskBeforeRiskyActions),
        Just(ApprovalPolicy::NeverAsk),
    ])
}

fn answered_repository(address: &str, branch: &str) -> RepositoryDraft {
    RepositoryDraft {
        address: address.to_owned(),
        default_branch: branch.to_owned(),
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_check_project_draft_property_is_idempotent(
        context in context_strategy(),
        name in prop_oneof![blank_text_strategy(), ANY_NAME_PATTERN],
        addresses in spelled_addresses_strategy(),
    ) {
        let project = github_project(&name, &addresses);
        let checked = check_item_draft(&context, &ItemDraft::Project(project));

        let checked_again = check_again(&context, &checked);

        prop_assert_eq!(checked_again, checked);
    }

    #[test]
    fn test_check_project_draft_property_each_repo_ends_up_once(
        addresses in spelled_addresses_strategy(),
        repeats in proptest::collection::vec(
            any::<prop::sample::Index>(),
            0..MOST_REPOSITORIES,
        ),
    ) {
        let mut answered = addresses.clone();
        for repeat in &repeats {
            answered.push(addresses[repeat.index(addresses.len())].clone());
        }
        let project = github_project("billing", &answered);

        let (checked, problems) = check_project(&empty_context(), &project)?;

        let mut expected: Vec<String> = Vec::new();
        for address in &answered {
            let canonical =
                parse_repository_address(address).unwrap_or_default();
            if !expected.contains(&canonical) {
                expected.push(canonical);
            }
        }
        let resolved: Vec<String> = checked
            .repositories
            .iter()
            .map(|repository| repository.address.clone())
            .collect();
        prop_assert_eq!(resolved, expected);
        prop_assert!(problems.is_empty(), "{:?}", problems);
    }

    #[test]
    fn test_check_project_draft_property_keeps_access_and_policy(
        context in context_strategy(),
        is_read_only in any::<bool>(),
        approval_policy in policy_strategy(),
    ) {
        let agent_access = if is_read_only {
            AgentAccess::ReadOnly
        } else {
            AgentAccess::PushAfterApproval
        };
        let project = ProjectDraft {
            agent_access,
            approval_policy,
            ..github_project("fresh", &[spell_address("acme", "app", 0)])
        };

        let (checked, _) = check_project(&context, &project)?;

        prop_assert_eq!(checked.agent_access, agent_access);
        prop_assert_eq!(checked.approval_policy, approval_policy);
    }

    #[test]
    fn test_find_project_name_problem_property_tells_the_name_rule_problem(
        name in ANY_NAME_PATTERN,
    ) {
        prop_assume!(!name.trim().is_empty());
        let project = github_project(&name, &[spell_address("a", "b", 0)]);

        let (checked, problems) = check_project(&empty_context(), &project)?;

        let expected = validate_name(name.trim()).err().map(|problem| {
            format!("Name: {problem}. {NAME_FIX}")
        });
        prop_assert_eq!(problems.into_iter().next(), expected);
        prop_assert_eq!(checked.name, name.trim());
    }

    #[test]
    fn test_find_project_name_problem_property_a_padded_taken_name_is_named(
        context in context_strategy(),
        position in any::<prop::sample::Index>(),
    ) {
        let taken = &context.projects[position.index(context.projects.len())];
        let address = spell_address("acme", "other", 0);
        let project = github_project(&padded(&taken.name), &[address]);

        let (_, problems) = check_project(&context, &project)?;

        let expected = format!(
            "Name: a project named {} already exists. {NAME_FIX}",
            taken.name
        );
        prop_assert_eq!(problems, vec![expected]);
    }

    #[test]
    fn test_find_project_name_problem_property_a_derived_name_is_checked(
        context in context_strategy(),
        position in any::<prop::sample::Index>(),
        blank_name in blank_text_strategy(),
    ) {
        let taken = &context.projects[position.index(context.projects.len())];
        let addresses = vec![
            "ftp://github.com/acme/broken".to_owned(),
            spell_address("acme", &taken.name, 2),
        ];
        let project = github_project(&blank_name, &addresses);

        let (checked, problems) = check_project(&context, &project)?;

        prop_assert_eq!(&checked.name, &taken.name);
        prop_assert_eq!(count_labelled(&problems, NAME_LABEL), 1);
        let expected = format!(
            "Name: a project named {} already exists. {NAME_FIX}",
            taken.name
        );
        prop_assert_eq!(problems.first(), Some(&expected));
    }

    #[test]
    fn test_resolve_repository_address_property_gives_the_canonical_address(
        addresses in spelled_addresses_strategy(),
    ) {
        let project = github_project("billing", &addresses[..1]);

        let (checked, _) = check_project(&empty_context(), &project)?;

        let resolved = &checked.repositories[0].address;
        let expected = parse_repository_address(&addresses[0]);
        prop_assert_eq!(Ok(resolved.clone()), expected);
        let reparsed = parse_repository_address(resolved);
        prop_assert_eq!(reparsed, Ok(resolved.clone()));
    }

    #[test]
    fn test_resolve_repository_address_property_a_blank_branch_is_main(
        branch in prop_oneof![
            blank_text_strategy(),
            BRANCH_PATTERN.prop_map(|branch| padded(&branch)),
        ],
    ) {
        let address = spell_address("acme", "app", 0);
        let project = ProjectDraft {
            repositories: vec![answered_repository(&address, &branch)],
            ..github_project("billing", &[])
        };

        let (checked, _) = check_project(&empty_context(), &project)?;

        let trimmed = branch.trim();
        let expected = if trimmed.is_empty() { "main" } else { trimmed };
        prop_assert_eq!(&checked.repositories[0].default_branch, expected);
    }

    #[test]
    fn test_resolve_repository_address_property_refuses_another_computer(
        path in FOLDER_PATH_PATTERN,
    ) {
        let address = format!("local:{FOREIGN_DEVICE_ID}:{path}");
        let project = github_project("billing", &[address]);

        let (checked, problems) = check_project(&empty_context(), &project)?;

        let expected = format!(
            "Repos: the folder {path} is on another computer, so add it \
             there. {REPOSITORY_FIX}"
        );
        prop_assert_eq!(problems, vec![expected]);
        prop_assert!(checked.repositories.is_empty());
    }
}
