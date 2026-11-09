import 'package:agent_orchestration/data/fakes/record_lists.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';
import 'package:agent_orchestration/data/rules/workflow_problems.dart';

const String workflowKind = 'workflow';
const String workflowChangeKind = 'workflow change';
const String _emptyChangeRequestProblem = 'Say what to change';

String identifyWorkflow(Workflow workflow) => workflow.id.value;

String identifyChangedWorkflow(WorkflowChange change) {
  return change.workflowId.value;
}

void refuseWorkflowProblem(Workflow workflow, String? problem) {
  if (problem != null) {
    throw PeopleFacingRefusal(problem);
  }
}

void refuseWorkflowUploadProblem(Workflow workflow) {
  final String? problem =
      describeNameProblem(workflow.name) ?? describeWorkflowProblem(workflow);
  refuseWorkflowProblem(workflow, problem);
}

void refuseDuplicateWorkflowRecords({
  required List<Workflow> workflows,
  required List<WorkflowChange> changes,
}) {
  refuseDuplicateIdentifiers(
    workflows,
    identify: identifyWorkflow,
    kind: workflowKind,
  );
  refuseDuplicateIdentifiers(
    changes,
    identify: identifyChangedWorkflow,
    kind: workflowChangeKind,
  );
}

String requireChangeRequest(String request) {
  final String trimmedRequest = trimUnicodeWhiteSpace(request);
  if (trimmedRequest.isEmpty) {
    throw PeopleFacingRefusal(_emptyChangeRequestProblem);
  }
  return trimmedRequest;
}

String requireWorkflowDescription(String description) {
  final String trimmedDescription = trimUnicodeWhiteSpace(description);
  if (trimmedDescription.isEmpty) {
    throw PeopleFacingRefusal(blankWorkflowDescriptionProblem);
  }
  return trimmedDescription;
}

Workflow findWorkflowIn(List<Workflow> workflows, WorkflowId workflowId) {
  return findRecord(
    workflows,
    matches: (Workflow workflow) => workflow.id == workflowId,
    kind: workflowKind,
    identifier: workflowId.value,
  );
}

WorkflowChange? findChangeOf(
  List<WorkflowChange> changes,
  WorkflowId workflowId,
) {
  for (final WorkflowChange change in changes) {
    if (change.workflowId == workflowId) {
      return change;
    }
  }
  return null;
}

WorkflowChange? findChangeOfListed({
  required List<WorkflowChange> changes,
  required List<Workflow> listedWorkflows,
  required WorkflowId workflowId,
}) {
  final bool isListed = listedWorkflows.any(
    (Workflow listed) => listed.id == workflowId,
  );
  if (!isListed) {
    return null;
  }
  return findChangeOf(changes, workflowId);
}

void refuseMissingChange(WorkflowChange? change, WorkflowId workflowId) {
  if (change == null) {
    throw RecordNotFound(
      kind: workflowChangeKind,
      identifier: workflowId.value,
    );
  }
}
