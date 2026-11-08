use std::sync::{MutexGuard, PoisonError};

use super::Node;
use crate::hosting_problem::HostingProblem;

impl Node {
    #[cfg(feature = "app-server")]
    pub(crate) fn record_hosting_problem(&self, problem: HostingProblem) {
        *self.lock_hosting_problem() = Some(problem);
    }

    #[cfg(feature = "app-server")]
    pub(crate) fn forget_hosting_problem(&self) {
        *self.lock_hosting_problem() = None;
    }

    pub(crate) fn hosting_problem(&self) -> Option<HostingProblem> {
        self.lock_hosting_problem().clone()
    }

    fn lock_hosting_problem(&self) -> MutexGuard<'_, Option<HostingProblem>> {
        self.hosting_problem
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
    }
}
