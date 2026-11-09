import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';

import '../support/held_save_repositories.dart';

final class HeldWorkflowRepository implements WorkflowRepository {
  HeldWorkflowRepository({required this.stored, required this.saveHold});

  final WorkflowRepository stored;
  final SaveHold saveHold;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Workflow> listWorkflows() => stored.listWorkflows();

  @override
  Workflow findWorkflow(WorkflowId workflowId) {
    return stored.findWorkflow(workflowId);
  }

  @override
  WorkflowChange? findPendingChange(WorkflowId workflowId) {
    return stored.findPendingChange(workflowId);
  }

  @override
  Future<Workflow> createWorkflow(Workflow unsavedWorkflow) {
    return saveHold.waitThenSave(() => stored.createWorkflow(unsavedWorkflow));
  }

  @override
  Future<Workflow> saveWorkflow(Workflow workflow) {
    return saveHold.waitThenSave(() => stored.saveWorkflow(workflow));
  }

  @override
  Future<Workflow> signWorkflow(WorkflowId workflowId) {
    return saveHold.waitThenSave(() => stored.signWorkflow(workflowId));
  }

  @override
  Future<Workflow> discardChange(WorkflowId workflowId) {
    return saveHold.waitThenSave(() => stored.discardChange(workflowId));
  }

  @override
  Future<void> deleteWorkflow(WorkflowId workflowId) {
    return stored.deleteWorkflow(workflowId);
  }

  @override
  Stream<WorkflowDraftProgress> draftWorkflow(WorkflowDraft draft) {
    return stored.draftWorkflow(draft);
  }

  @override
  Future<void> stopDrafting(WorkflowDraft draft) {
    return stored.stopDrafting(draft);
  }

  @override
  Future<Workflow> changeWorkflow(
    WorkflowId workflowId,
    String request,
    AgentKind agent,
  ) {
    return stored.changeWorkflow(workflowId, request, agent);
  }

  @override
  Future<Workflow> fillAgentSettings(
    WorkflowId workflowId,
    WorkflowAgentId agentId,
  ) {
    return stored.fillAgentSettings(workflowId, agentId);
  }
}
