use orchestration_node::identity_store::IdentityStore;
use proptest::prelude::*;

use crate::store_contract::{
    StoreSnapshot, fill_every_secret, forget_secret_of, read_snapshot,
    secret_in,
};
use crate::store_desk::SecretKind;
use crate::support::test_device::fail;

pub const LONGEST_FORGET_RUN: usize = 4;

pub fn check_forget_removes_only_its_secret(
    store: &dyn IdentityStore,
    kind: SecretKind,
    secrets: &StoreSnapshot,
) -> Result<(), TestCaseError> {
    fill_every_secret(store, secrets)?;

    forget_secret_of(store, kind).map_err(fail)?;

    prop_assert_eq!(read_snapshot(store)?, secrets.with_secret(kind, None));
    Ok(())
}

pub fn check_forget_is_idempotent(
    store: &dyn IdentityStore,
    kind: SecretKind,
    secrets: &StoreSnapshot,
    forget_count: usize,
) -> Result<(), TestCaseError> {
    fill_every_secret(store, secrets)?;
    forget_secret_of(store, kind).map_err(fail)?;
    let after_first_forget = read_snapshot(store)?;

    for _ in 0..forget_count {
        forget_secret_of(store, kind).map_err(fail)?;
    }

    prop_assert_eq!(read_snapshot(store)?, after_first_forget);
    Ok(())
}

pub fn check_save_after_forget_restores(
    store: &dyn IdentityStore,
    kind: SecretKind,
    secrets: &StoreSnapshot,
) -> Result<(), TestCaseError> {
    forget_secret_of(store, kind).map_err(fail)?;
    fill_every_secret(store, secrets)?;
    forget_secret_of(store, kind).map_err(fail)?;

    let only_this_kind =
        StoreSnapshot::default().with_secret(kind, secret_in(secrets, kind));
    fill_every_secret(store, &only_this_kind)?;

    prop_assert_eq!(read_snapshot(store)?, secrets.clone());
    Ok(())
}
