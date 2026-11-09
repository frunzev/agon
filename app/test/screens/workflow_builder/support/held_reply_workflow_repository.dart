import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';

final class HeldReplyWorkflowRepository implements WorkflowRepository {
  HeldReplyWorkflowRepository({required this.stored});

  final WorkflowRepository stored;
  final List<Completer<void>> _heldReplies = <Completer<void>>[];
  final List<Workflow> sentWorkflows = <Workflow>[];
  int savesInFlight = 0;
  int mostSavesInFlight = 0;

  int get heldReplyCount => _heldReplies.length;

  void releaseNextReply() {
    _heldReplies.removeAt(0).complete();
  }

  void refuseNextReply(Object problem) {
    _heldReplies.removeAt(0).completeError(problem);
  }

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
    return stored.createWorkflow(unsavedWorkflow);
  }

  @override
  Future<Workflow> saveWorkflow(Workflow workflow) async {
    sentWorkflows.add(workflow);
    savesInFlight += 1;
    if (savesInFlight > mostSavesInFlight) {
      mostSavesInFlight = savesInFlight;
    }

    final Completer<void> reply = Completer<void>();
    _heldReplies.add(reply);
    try {
      await reply.future;
    } finally {
      savesInFlight -= 1;
    }
    return stored.saveWorkflow(workflow);
  }

  @override
  Future<Workflow> signWorkflow(WorkflowId workflowId) {
    return stored.signWorkflow(workflowId);
  }

  @override
  Future<Workflow> discardChange(WorkflowId workflowId) {
    return stored.discardChange(workflowId);
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
