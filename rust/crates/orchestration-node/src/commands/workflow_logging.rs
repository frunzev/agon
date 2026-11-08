use orchestration_core::identifiers::WorkflowId;

pub(super) fn log_left_out_workflow(workflow_id: WorkflowId) {
    eprintln!(
        "workflow {} is left out of the list: its sealed text cannot be \
         opened with any workspace key",
        workflow_id.0
    );
}
