use orchestration_node::identity_store::{IdentityStore, IdentityStoreError};
use orchestration_security::identity::{
    DeviceIdentity, IDENTITY_SECRET_LENGTH,
};
use proptest::collection::vec;
use proptest::prelude::*;

use crate::store_desk::{
    PeerSecretBytes, SECRET_KINDS, SecretKind, credential_strategy,
    peer_secret_strategy,
};
use crate::support::test_device::fail;

#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct StoreSnapshot {
    pub identity: Option<Vec<u8>>,
    pub peer_secret: Option<Vec<u8>>,
    pub agent_credential: Option<Vec<u8>>,
}

impl StoreSnapshot {
    pub fn with_secret(
        &self,
        kind: SecretKind,
        stored_secret: Option<Vec<u8>>,
    ) -> Self {
        let mut changed = self.clone();
        match kind {
            SecretKind::Identity => changed.identity = stored_secret,
            SecretKind::PeerSecret => changed.peer_secret = stored_secret,
            SecretKind::AgentCredential => {
                changed.agent_credential = stored_secret;
            }
        }
        changed
    }
}

#[derive(Clone, Debug)]
pub enum StoreStep {
    Save(SecretKind, Vec<u8>),
    Forget(SecretKind),
}

pub fn read_identity_secret(
    store: &dyn IdentityStore,
) -> Result<Option<Vec<u8>>, IdentityStoreError> {
    let loaded = store.load_identity()?;
    Ok(loaded.map(|identity| identity.secret_bytes().to_vec()))
}

pub fn read_peer_secret(
    store: &dyn IdentityStore,
) -> Result<Option<Vec<u8>>, IdentityStoreError> {
    let loaded = store.load_peer_secret()?;
    Ok(loaded.map(|peer_secret| peer_secret.to_vec()))
}

pub fn read_agent_credential(
    store: &dyn IdentityStore,
) -> Result<Option<Vec<u8>>, IdentityStoreError> {
    let loaded = store.load_agent_credential()?;
    Ok(loaded.map(|credential| credential.to_vec()))
}

pub fn read_secret_of(
    store: &dyn IdentityStore,
    kind: SecretKind,
) -> Result<Option<Vec<u8>>, IdentityStoreError> {
    match kind {
        SecretKind::Identity => read_identity_secret(store),
        SecretKind::PeerSecret => read_peer_secret(store),
        SecretKind::AgentCredential => read_agent_credential(store),
    }
}

pub fn read_snapshot(
    store: &dyn IdentityStore,
) -> Result<StoreSnapshot, TestCaseError> {
    Ok(StoreSnapshot {
        identity: read_identity_secret(store).map_err(fail)?,
        peer_secret: read_peer_secret(store).map_err(fail)?,
        agent_credential: read_agent_credential(store).map_err(fail)?,
    })
}

pub fn save_secret_of(
    store: &dyn IdentityStore,
    kind: SecretKind,
    secret: &[u8],
) -> Result<(), TestCaseError> {
    match kind {
        SecretKind::Identity => {
            let identity =
                DeviceIdentity::from_secret_bytes(secret).map_err(fail)?;
            store.save_identity(&identity).map_err(fail)
        }
        SecretKind::PeerSecret => {
            let peer_secret: PeerSecretBytes =
                secret.try_into().map_err(fail)?;
            store.save_peer_secret(&peer_secret).map_err(fail)
        }
        SecretKind::AgentCredential => {
            store.save_agent_credential(secret).map_err(fail)
        }
    }
}

pub fn forget_secret_of(
    store: &dyn IdentityStore,
    kind: SecretKind,
) -> Result<(), IdentityStoreError> {
    match kind {
        SecretKind::Identity => store.forget_identity(),
        SecretKind::PeerSecret => store.forget_peer_secret(),
        SecretKind::AgentCredential => store.forget_agent_credential(),
    }
}

pub fn apply_step(
    store: &dyn IdentityStore,
    step: &StoreStep,
) -> Result<(), TestCaseError> {
    match step {
        StoreStep::Save(kind, secret) => save_secret_of(store, *kind, secret),
        StoreStep::Forget(kind) => {
            forget_secret_of(store, *kind).map_err(fail)
        }
    }
}

pub fn expect_after_step(
    expected: &StoreSnapshot,
    step: &StoreStep,
) -> StoreSnapshot {
    match step {
        StoreStep::Save(kind, secret) => {
            expected.with_secret(*kind, Some(secret.clone()))
        }
        StoreStep::Forget(kind) => expected.with_secret(*kind, None),
    }
}

pub fn fill_every_secret(
    store: &dyn IdentityStore,
    secrets: &StoreSnapshot,
) -> Result<(), TestCaseError> {
    for kind in SECRET_KINDS {
        let Some(secret) = secret_in(secrets, kind) else {
            continue;
        };
        save_secret_of(store, kind, &secret)?;
    }
    Ok(())
}

pub fn secret_in(
    snapshot: &StoreSnapshot,
    kind: SecretKind,
) -> Option<Vec<u8>> {
    match kind {
        SecretKind::Identity => snapshot.identity.clone(),
        SecretKind::PeerSecret => snapshot.peer_secret.clone(),
        SecretKind::AgentCredential => snapshot.agent_credential.clone(),
    }
}

pub fn secret_strategy_of(kind: SecretKind) -> BoxedStrategy<Vec<u8>> {
    match kind {
        SecretKind::Identity => {
            vec(any::<u8>(), IDENTITY_SECRET_LENGTH).boxed()
        }
        SecretKind::PeerSecret => {
            peer_secret_strategy().prop_map(Vec::from).boxed()
        }
        SecretKind::AgentCredential => credential_strategy().boxed(),
    }
}

pub fn kind_strategy() -> impl Strategy<Value = SecretKind> {
    proptest::sample::select(SECRET_KINDS.to_vec())
}

pub fn kind_and_secret_strategy()
-> impl Strategy<Value = (SecretKind, Vec<u8>)> {
    kind_strategy()
        .prop_flat_map(|kind| (Just(kind), secret_strategy_of(kind)))
}

pub fn full_snapshot_strategy() -> impl Strategy<Value = StoreSnapshot> {
    (
        secret_strategy_of(SecretKind::Identity),
        secret_strategy_of(SecretKind::PeerSecret),
        secret_strategy_of(SecretKind::AgentCredential),
    )
        .prop_map(|(identity, peer_secret, agent_credential)| {
            StoreSnapshot {
                identity: Some(identity),
                peer_secret: Some(peer_secret),
                agent_credential: Some(agent_credential),
            }
        })
}

pub fn step_strategy() -> impl Strategy<Value = StoreStep> {
    let save_step = kind_and_secret_strategy()
        .prop_map(|(kind, secret)| StoreStep::Save(kind, secret));
    let forget_step = kind_strategy().prop_map(StoreStep::Forget);
    prop_oneof![save_step, forget_step]
}
