use keyring_core::Error as KeychainError;
use orchestration_node::identity_store::{
    IdentityStoreError, KeychainIdentityStore,
};
use proptest::prelude::*;

use crate::keychain_problems::{
    injected_problem_strategy, open_refusing_keychain, problem_text_strategy,
    read_keychain_message,
};
use crate::store_contract::{
    fill_every_secret, forget_secret_of, full_snapshot_strategy,
    kind_strategy, read_secret_of, read_snapshot,
};
use crate::store_desk::{
    SECRET_KINDS, STORE_CASE_COUNT, TEST_SERVICE_NAME, open_keychain_desk,
    open_mock_keychain, service_name_strategy,
};
use crate::support::test_device::fail;

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

    #[test]
    fn test_delete_secret_property_missing_entries_are_fine(
        service_name in service_name_strategy(),
    ) {
        let desk = open_keychain_desk(&service_name)?;

        for kind in SECRET_KINDS {
            forget_secret_of(&desk.store, kind).map_err(fail)?;
            prop_assert_eq!(desk.read_planted(kind)?, None);
        }
    }

    #[test]
    fn test_delete_secret_property_failure_is_reported_and_keeps_secret(
        secrets in full_snapshot_strategy(),
        kind in kind_strategy(),
        problem in injected_problem_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        fill_every_secret(&desk.store, &secrets)?;
        desk.fail_next_call(kind, problem.to_keychain_error())?;

        let forgotten = forget_secret_of(&desk.store, kind);

        let message = forgotten
            .as_ref()
            .err()
            .and_then(read_keychain_message)
            .map(str::to_owned);
        let expected = problem.to_keychain_error().to_string();
        prop_assert_eq!(message, Some(expected));
        prop_assert_eq!(read_snapshot(&desk.store)?, secrets);
    }

    #[test]
    fn test_delete_secret_property_touches_only_its_own_service(
        first_service in service_name_strategy(),
        second_service in service_name_strategy(),
        secrets in full_snapshot_strategy(),
        kind in kind_strategy(),
    ) {
        prop_assume!(first_service != second_service);
        let credential_store = open_mock_keychain()?;
        let first_store = KeychainIdentityStore::new(
            &first_service,
            credential_store.clone(),
        );
        let second_store =
            KeychainIdentityStore::new(&second_service, credential_store);
        fill_every_secret(&first_store, &secrets)?;
        fill_every_secret(&second_store, &secrets)?;

        forget_secret_of(&first_store, kind).map_err(fail)?;

        prop_assert_eq!(read_snapshot(&second_store)?, secrets.clone());
        let expected_first = secrets.with_secret(kind, None);
        prop_assert_eq!(read_snapshot(&first_store)?, expected_first);
    }

    #[test]
    fn test_describe_keychain_error_property_message_keeps_platform_text(
        kind in kind_strategy(),
        problem in injected_problem_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        desk.fail_next_call(kind, problem.to_keychain_error())?;

        let loaded = read_secret_of(&desk.store, kind);

        let Err(outcome_problem) = loaded else {
            return Err(fail("an injected keychain failure was ignored"));
        };
        let platform_text = problem.to_keychain_error().to_string();
        prop_assert!(outcome_problem.to_string().contains(&platform_text));
    }

    #[test]
    fn test_describe_keychain_error_property_is_always_a_keychain_error(
        problem in problem_text_strategy(),
        kind in kind_strategy(),
    ) {
        let refusing_keychain = open_refusing_keychain(&problem);
        let store =
            KeychainIdentityStore::new(TEST_SERVICE_NAME, refusing_keychain);

        let loaded = read_secret_of(&store, kind);

        let is_keychain_error =
            matches!(loaded, Err(IdentityStoreError::Keychain(_)));
        prop_assert!(is_keychain_error);
        let refusal = KeychainError::NoStorageAccess(problem.into());
        let message = loaded
            .as_ref()
            .err()
            .and_then(read_keychain_message)
            .map(str::to_owned);
        prop_assert_eq!(message, Some(refusal.to_string()));
    }

    #[test]
    fn test_describe_keychain_error_property_distinct_problems_stay_distinct(
        first_problem in problem_text_strategy(),
        second_problem in problem_text_strategy(),
        kind in kind_strategy(),
    ) {
        prop_assume!(first_problem != second_problem);
        let first_store = KeychainIdentityStore::new(
            TEST_SERVICE_NAME,
            open_refusing_keychain(&first_problem),
        );
        let second_store = KeychainIdentityStore::new(
            TEST_SERVICE_NAME,
            open_refusing_keychain(&second_problem),
        );

        let first_message = read_secret_of(&first_store, kind)
            .err()
            .map(|outcome_problem| outcome_problem.to_string());
        let second_message = read_secret_of(&second_store, kind)
            .err()
            .map(|outcome_problem| outcome_problem.to_string());

        prop_assert!(first_message.is_some());
        prop_assert_ne!(first_message, second_message);
    }
}
