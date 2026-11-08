use orchestration_api::accounts::AccountView;
use tokio::sync::MutexGuard;

use super::{DeviceSession, Node};
use crate::node_error::NodeError;

impl Node {
    pub(crate) async fn lock_account_updates(&self) -> MutexGuard<'_, ()> {
        self.account_updates.lock().await
    }

    pub(crate) async fn refresh_saved_account(
        &self,
        session: &DeviceSession,
    ) -> Result<AccountView, NodeError> {
        let _account_update = self.lock_account_updates().await;
        self.require_current_identity(session)?;
        let fresh_account = session.client().read_account().await?;
        self.device_files.save_account(&fresh_account)?;
        Ok(fresh_account)
    }

    pub(crate) async fn save_known_account(
        &self,
        account: &AccountView,
    ) -> Result<(), NodeError> {
        let _account_update = self.lock_account_updates().await;
        self.device_files.save_account(account)
    }

    pub(super) fn require_current_identity(
        &self,
        session: &DeviceSession,
    ) -> Result<(), NodeError> {
        let session_identity = session.identity.public_identity();
        let current_identity = self.find_identity()?;
        let is_current = current_identity.is_some_and(|identity| {
            identity.public_identity() == session_identity
        });
        if !is_current {
            return Err(NodeError::NoAccount);
        }
        Ok(())
    }
}
