use orchestration_node::identity_store::{
    IdentityStore, IdentityStoreError, KeychainIdentityStore,
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
    SECRET_KINDS, STORE_CASE_COUNT, SecretKind, TEST_SERVICE_NAME,
    credential_strategy, identity_strategy, open_keychain_desk,
    peer_secret_strategy, service_name_strategy,
};
use crate::support::test_device::fail;

fn check_refused(
    outcome_problem: Option<IdentityStoreError>,
    problem: &str,
) -> Result<(), TestCaseError> {
    let Some(outcome_problem) = outcome_problem else {
        return Err(fail("a refusing keychain call succeeded"));
    };
    let message = read_keychain_message(&outcome_problem).unwrap_or_default();
    prop_assert!(message.contains(problem), "{outcome_problem}");
    Ok(())
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

    #[test]
    fn test_open_entry_property_refused_loads_are_errors_not_absence(
        problem in problem_text_strategy(),
    ) {
        let refusing_keychain = open_refusing_keychain(&problem);
        let store =
            KeychainIdentityStore::new(TEST_SERVICE_NAME, refusing_keychain);

        for kind in SECRET_KINDS {
            check_refused(read_secret_of(&store, kind).err(), &problem)?;
        }
    }

    #[test]
    fn test_open_entry_property_refused_saves_are_errors(
        problem in problem_text_strategy(),
        identity in identity_strategy(),
        peer_secret in peer_secret_strategy(),
        credential in credential_strategy(),
    ) {
        let refusing_keychain = open_refusing_keychain(&problem);
        let store =
            KeychainIdentityStore::new(TEST_SERVICE_NAME, refusing_keychain);

        check_refused(store.save_identity(&identity).err(), &problem)?;
        check_refused(store.save_peer_secret(&peer_secret).err(), &problem)?;
        let credential_outcome = store.save_agent_credential(&credential);
        check_refused(credential_outcome.err(), &problem)?;
    }

    #[test]
    fn test_open_entry_property_refused_forgets_are_errors(
        problem in problem_text_strategy(),
        service_name in service_name_strategy(),
    ) {
        let refusing_keychain = open_refusing_keychain(&problem);
        let store =
            KeychainIdentityStore::new(&service_name, refusing_keychain);

        for kind in SECRET_KINDS {
            check_refused(forget_secret_of(&store, kind).err(), &problem)?;
        }
    }

    #[test]
    fn test_read_secret_property_failure_is_an_error_not_absence(
        secrets in full_snapshot_strategy(),
        kind in kind_strategy(),
        problem in injected_problem_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        fill_every_secret(&desk.store, &secrets)?;
        desk.fail_next_call(kind, problem.to_keychain_error())?;

        let loaded = read_secret_of(&desk.store, kind);

        let message = loaded
            .as_ref()
            .err()
            .and_then(read_keychain_message)
            .map(str::to_owned);
        let expected = problem.to_keychain_error().to_string();
        prop_assert_eq!(message, Some(expected));
    }

    #[test]
    fn test_read_secret_property_failed_read_keeps_the_secret(
        secrets in full_snapshot_strategy(),
        kind in kind_strategy(),
        problem in injected_problem_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        fill_every_secret(&desk.store, &secrets)?;
        desk.fail_next_call(kind, problem.to_keychain_error())?;

        prop_assert!(read_secret_of(&desk.store, kind).is_err());

        prop_assert_eq!(read_snapshot(&desk.store)?, secrets);
    }

    #[test]
    fn test_read_secret_property_untouched_accounts_read_as_absent(
        service_name in service_name_strategy(),
    ) {
        let desk = open_keychain_desk(&service_name)?;

        for kind in SECRET_KINDS {
            let loaded = read_secret_of(&desk.store, kind).map_err(fail)?;
            prop_assert_eq!(loaded, None);
        }
    }

    #[test]
    fn test_write_secret_property_failure_is_reported(
        credential in credential_strategy(),
        problem in injected_problem_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        desk.fail_next_call(
            SecretKind::AgentCredential,
            problem.to_keychain_error(),
        )?;

        let saved = desk.store.save_agent_credential(&credential);

        let message = saved
            .as_ref()
            .err()
            .and_then(read_keychain_message)
            .map(str::to_owned);
        let expected = problem.to_keychain_error().to_string();
        prop_assert_eq!(message, Some(expected));
    }

    #[test]
    fn test_write_secret_property_failed_write_keeps_the_old_secret(
        secrets in full_snapshot_strategy(),
        identity in identity_strategy(),
        problem in injected_problem_strategy(),
    ) {
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        fill_every_secret(&desk.store, &secrets)?;
        let injected = problem.to_keychain_error();
        desk.fail_next_call(SecretKind::Identity, injected)?;

        prop_assert!(desk.store.save_identity(&identity).is_err());

        prop_assert_eq!(read_snapshot(&desk.store)?, secrets);
    }

    #[test]
    fn test_write_secret_property_shorter_secret_replaces_the_whole_one(
        kept_part in credential_strategy(),
        dropped_part in credential_strategy(),
    ) {
        prop_assume!(!dropped_part.is_empty());
        let desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        let mut longer_credential = kept_part.clone();
        longer_credential.extend_from_slice(&dropped_part);

        desk.store.save_agent_credential(&longer_credential).map_err(fail)?;
        desk.store.save_agent_credential(&kept_part).map_err(fail)?;

        let stored = desk.read_planted(SecretKind::AgentCredential)?;
        prop_assert_eq!(stored, Some(kept_part));
    }
}
