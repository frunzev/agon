use std::collections::BTreeMap;

use orchestration_core::approval::ApprovalAction;
use orchestration_core::identifiers::WorkflowId;

const UNLISTED_WORKFLOW_TITLE: &str = "Sign a workflow";

#[must_use]
pub fn describe_approval_action(
    action: &ApprovalAction,
    workflow_names: &BTreeMap<WorkflowId, String>,
) -> String {
    match action {
        ApprovalAction::PushCommits {
            branch, commits, ..
        } => {
            let commit_word = if commits.len() == 1 {
                "commit"
            } else {
                "commits"
            };
            format!("Push {} {commit_word} to {branch}", commits.len())
        }
        ApprovalAction::Deploy { target } => format!("Deploy to {target}"),
        ApprovalAction::DeleteBranchOrFiles { repository, what } => {
            format!("Delete {what} in {repository}")
        }
        ApprovalAction::SignWorkflow { workflow_id } => {
            match workflow_names.get(workflow_id) {
                Some(workflow_name) => {
                    format!("Sign workflow {workflow_name}")
                }
                None => UNLISTED_WORKFLOW_TITLE.to_owned(),
            }
        }
        ApprovalAction::RunCommand { summary, .. } => summary.clone(),
        ApprovalAction::ImproveSkill { summary, .. } => {
            format!("Improve a skill: {summary}")
        }
    }
}
