use orchestration_node::identity_store::{IdentityStore, IdentityStoreError};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::store_contract::{
    StoreSnapshot, apply_step, expect_after_step, kind_strategy,
    read_secret_of, read_snapshot, step_strategy,
};
use crate::store_desk::{
    STORE_CASE_COUNT, SecretKind, TEST_SERVICE_NAME, open_file_desk,
    open_keychain_desk,
};

const LONGEST_STEP_RUN: usize = 16;
const LONGEST_PLANTED_SECRET: usize = 160;
const STORE_FAILURE_NAME: &str = "store failure";

type JudgedSecret = Result<Option<Vec<u8>>, String>;

fn judge_stored_secret(
    store: &dyn IdentityStore,
    kind: SecretKind,
) -> JudgedSecret {
    read_secret_of(store, kind).map_err(|problem| describe_kind(&problem))
}

fn describe_kind(problem: &IdentityStoreError) -> String {
    let kind_name = match problem {
        IdentityStoreError::DamagedIdentity => "damaged identity",
        IdentityStoreError::DamagedPeerSecret => "damaged peer secret",
        IdentityStoreError::DamagedAgentCredential => "damaged credential",
        _ => STORE_FAILURE_NAME,
    };
    kind_name.to_owned()
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(STORE_CASE_COUNT))]

    #[test]
    fn test_identity_store_property_file_and_keychain_agree_on_any_steps(
        steps in vec(step_strategy(), 1..LONGEST_STEP_RUN),
    ) {
        let file_desk = open_file_desk()?;
        let keychain_desk = open_keychain_desk(TEST_SERVICE_NAME)?;

        for step in &steps {
            apply_step(&file_desk.store, step)?;
            apply_step(&keychain_desk.store, step)?;

            let file_snapshot = read_snapshot(&file_desk.store)?;
            let keychain_snapshot = read_snapshot(&keychain_desk.store)?;
            prop_assert_eq!(file_snapshot, keychain_snapshot);
        }
    }

    #[test]
    fn test_identity_store_property_both_stores_follow_the_model(
        steps in vec(step_strategy(), 1..LONGEST_STEP_RUN),
    ) {
        let file_desk = open_file_desk()?;
        let keychain_desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        let mut expected = StoreSnapshot::default();

        for step in &steps {
            apply_step(&file_desk.store, step)?;
            apply_step(&keychain_desk.store, step)?;
            expected = expect_after_step(&expected, step);

            prop_assert_eq!(&read_snapshot(&file_desk.store)?, &expected);
            prop_assert_eq!(&read_snapshot(&keychain_desk.store)?, &expected);
        }
    }

    #[test]
    fn test_identity_store_property_file_and_keychain_judge_bytes_alike(
        kind in kind_strategy(),
        planted in vec(any::<u8>(), 0..LONGEST_PLANTED_SECRET),
    ) {
        let file_desk = open_file_desk()?;
        let keychain_desk = open_keychain_desk(TEST_SERVICE_NAME)?;
        file_desk.plant(kind, &planted)?;
        keychain_desk.plant(kind, &planted)?;

        let file_judgement = judge_stored_secret(&file_desk.store, kind);
        let keychain_judgement =
            judge_stored_secret(&keychain_desk.store, kind);

        prop_assert_eq!(&file_judgement, &keychain_judgement);
        let is_store_failure =
            file_judgement.as_ref().is_err_and(|kind_name| {
                kind_name.as_str() == STORE_FAILURE_NAME
            });
        prop_assert!(!is_store_failure);
    }
}
