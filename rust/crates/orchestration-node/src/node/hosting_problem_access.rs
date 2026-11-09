use std::sync::{MutexGuard, PoisonError};

use super::Node;
use crate::device_files::DeviceFiles;
use crate::hosting_problem::{
    HostingProblem, HostingProblemKind, describe_failed_start,
};
use crate::node_error::NodeError;

type RecordLoader<Record> =
    fn(&DeviceFiles) -> Result<Option<Record>, NodeError>;

impl Node {
    pub(crate) fn record_hosting_problem(&self, problem: HostingProblem) {
        *self.lock_hosting_problem() = Some(problem);
    }

    pub(crate) fn forget_hosting_problem(&self) {
        *self.lock_hosting_problem() = None;
    }

    pub(crate) fn hosting_problem(&self) -> Option<HostingProblem> {
        self.lock_hosting_problem().clone()
    }

    pub(crate) fn load_record_reporting_damage<Record>(
        &self,
        load_record: RecordLoader<Record>,
    ) -> Result<Option<Record>, NodeError> {
        let problem = match load_record(&self.device_files) {
            Ok(record) => return Ok(record),
            Err(problem) => problem,
        };
        let hosting_problem = describe_failed_start(&problem);
        if hosting_problem.kind != HostingProblemKind::RecordDamaged {
            return Err(problem);
        }
        self.record_hosting_problem(hosting_problem);
        Ok(None)
    }

    fn lock_hosting_problem(&self) -> MutexGuard<'_, Option<HostingProblem>> {
        self.hosting_problem
            .lock()
            .unwrap_or_else(PoisonError::into_inner)
    }
}
