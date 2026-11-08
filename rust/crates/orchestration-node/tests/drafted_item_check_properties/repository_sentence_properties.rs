use orchestration_core::local_folders::normalize_folder_path;
use orchestration_core::repository_address::parse_repository_address;
use orchestration_core::workspace::AgentAccess;
use orchestration_node::item_drafting::{ProjectDraft, RepositoryDraft};
use proptest::prelude::*;

use crate::drafted_item_checks::{
    CHECK_CASES, check_project, count_labelled, is_clear_sentence,
};
use crate::support::drafting_samples::empty_context;
use crate::support::entity_strategies::secret_text_strategy;

const REPOSITORY_FIX: &str = "Ask for changes and give a GitHub address or a \
                              git folder on this computer.";
const REPOSITORY_LABEL: &str = "Repos";
const PROJECT_NAME: &str = "billing";
const GOOD_ADDRESS: &str = "https://github.com/acme/billing";
const HOSTILE_ADDRESS_PATTERN: &str = "[a-zA-Z0-9:@./_ ~-]{0,30}";
const USER_PATTERN: &str = "[a-z]{1,8}";
const CREDENTIAL_FORM_COUNT: usize = 4;
const MOST_BAD_ADDRESSES: usize = 4;
const LOCAL_ADDRESS_PREFIX: &str = "local:";

pub fn github_project(name: &str, addresses: &[String]) -> ProjectDraft {
    let mut repositories = Vec::new();
    for address in addresses {
        repositories.push(RepositoryDraft {
            address: address.clone(),
            default_branch: "main".to_owned(),
        });
    }
    ProjectDraft {
        name: name.to_owned(),
        repositories,
        agent_access: AgentAccess::ReadOnly,
        approval_policy: None,
    }
}

fn spell_credential_address(form: usize, user: &str, secret: &str) -> String {
    match form {
        0 => format!("https://{user}:{secret}@github.com/acme/app"),
        1 => format!("https://{secret}@github.com/acme/app"),
        2 => format!("git@{secret}@github.com:acme/app"),
        _ => format!("{user}:{secret}@github.com/acme/app.git"),
    }
}

fn is_github_like(address: &str) -> bool {
    let is_folder_path = normalize_folder_path(address).is_ok();
    let is_local_address = address.trim().starts_with(LOCAL_ADDRESS_PREFIX);
    !is_folder_path && !is_local_address
}

fn unparseable_address_strategy() -> impl Strategy<Value = String> {
    HOSTILE_ADDRESS_PATTERN.prop_filter("an unparseable address", |address| {
        is_github_like(address) && parse_repository_address(address).is_err()
    })
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(CHECK_CASES))]

    #[test]
    fn test_describe_repository_problem_property_tells_the_core_problem(
        address in HOSTILE_ADDRESS_PATTERN,
    ) {
        prop_assume!(is_github_like(&address));
        let project =
            github_project(PROJECT_NAME, std::slice::from_ref(&address));

        let (checked, problems) = check_project(&empty_context(), &project)?;

        match parse_repository_address(&address) {
            Ok(canonical) => {
                let resolved = checked
                    .repositories
                    .first()
                    .map(|repository| repository.address.clone());
                prop_assert_eq!(resolved, Some(canonical));
                let repository_problems =
                    count_labelled(&problems, REPOSITORY_LABEL);
                prop_assert_eq!(repository_problems, 0);
            }
            Err(problem) => {
                let expected = format!("Repos: {problem}. {REPOSITORY_FIX}");
                prop_assert_eq!(problems, vec![expected]);
                prop_assert!(checked.repositories.is_empty());
            }
        }
    }

    #[test]
    fn test_describe_repository_problem_property_never_echoes_credentials(
        form in 0..CREDENTIAL_FORM_COUNT,
        user in USER_PATTERN,
        secret in secret_text_strategy(),
    ) {
        let address = spell_credential_address(form, &user, &secret);
        let project = github_project(PROJECT_NAME, &[address]);

        let (checked, problems) = check_project(&empty_context(), &project)?;

        prop_assert!(checked.repositories.is_empty());
        prop_assert_eq!(problems.len(), 1);
        for problem in &problems {
            prop_assert!(!problem.contains(&secret), "{}", problem);
            prop_assert!(is_clear_sentence(problem, REPOSITORY_LABEL));
        }
    }

    #[test]
    fn test_describe_repository_problem_property_one_sentence_per_bad_repo(
        bad_addresses in proptest::collection::btree_set(
            unparseable_address_strategy(),
            1..MOST_BAD_ADDRESSES,
        ),
        good_position in any::<prop::sample::Index>(),
    ) {
        let mut addresses: Vec<String> = bad_addresses.into_iter().collect();
        let mut expected = Vec::new();
        for address in &addresses {
            let problem = parse_repository_address(address)
                .err()
                .map(|problem| problem.to_string())
                .unwrap_or_default();
            expected.push(format!("Repos: {problem}. {REPOSITORY_FIX}"));
        }
        let insert_at = good_position.index(addresses.len() + 1);
        addresses.insert(insert_at, GOOD_ADDRESS.to_owned());
        let project = github_project(PROJECT_NAME, &addresses);

        let (checked, problems) = check_project(&empty_context(), &project)?;

        prop_assert_eq!(problems, expected);
        prop_assert_eq!(checked.repositories.len(), 1);
    }
}
