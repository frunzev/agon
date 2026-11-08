use orchestration_core::identifiers::ApprovalId;

pub(super) fn log_left_out_approval(approval_id: ApprovalId) {
    eprintln!(
        "approval {} is left out of the list: its sealed text cannot be \
         opened with any workspace key",
        approval_id.0
    );
}
