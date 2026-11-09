import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/workflow_repository.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart'
    as workflow_edits;
import 'package:agent_orchestration/data/rules/workflow_graph.dart';

final class WorkflowDiagramEditor extends ChangeNotifier {
  WorkflowDiagramEditor({
    required WorkflowRepository workflowRepository,
    required WorkflowId workflowId,
  }) : _workflowRepository = workflowRepository,
       _workflowId = workflowId;

  final WorkflowRepository _workflowRepository;
  final WorkflowId _workflowId;
  Workflow? _unsavedWorkflow;
  bool _isSaving = false;
  bool _isDisposed = false;

  Workflow readLatestWorkflow() {
    return _unsavedWorkflow ?? _workflowRepository.findWorkflow(_workflowId);
  }

  Future<void> addStep(WorkflowAgent blank) {
    final Workflow edited = workflow_edits.addAgent(
      readLatestWorkflow(),
      blank,
    );
    return _saveInOrder(edited);
  }

  Future<void> changeAgent(WorkflowAgent agent) {
    final Workflow edited = workflow_edits.replaceAgent(
      readLatestWorkflow(),
      agent,
    );
    return _saveInOrder(edited);
  }

  Future<void> moveAgent(WorkflowAgentId agentId, CanvasPosition position) {
    final Workflow workflow = readLatestWorkflow();
    final WorkflowAgent moved = workflow
        .findAgent(agentId)
        .copyWith(position: position);
    final Workflow edited = workflow_edits.replaceAgent(workflow, moved);
    return _saveInOrder(edited);
  }

  Future<void> connect(AgentConnection connection) {
    final Workflow edited = connectAgents(readLatestWorkflow(), connection);
    return _saveInOrder(edited);
  }

  Future<void> changeConnection(AgentConnection connection) {
    final Workflow edited = workflow_edits.replaceConnection(
      readLatestWorkflow(),
      connection,
    );
    return _saveInOrder(edited);
  }

  Future<void> removeConnection(AgentConnection connection) {
    final Workflow edited = workflow_edits.removeConnection(
      readLatestWorkflow(),
      connection,
    );
    return _saveInOrder(edited);
  }

  Future<void> removeAgent(WorkflowAgentId agentId) {
    final Workflow edited = workflow_edits.removeAgent(
      readLatestWorkflow(),
      agentId,
    );
    return _saveInOrder(edited);
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> _saveInOrder(Workflow edited) async {
    _showUnsaved(edited);
    if (_isSaving) {
      return;
    }

    _isSaving = true;
    try {
      await _sendUntilLatestIsSaved();
    } finally {
      _isSaving = false;
      _showUnsaved(null);
    }
  }

  Future<void> _sendUntilLatestIsSaved() async {
    Workflow? unsent = _unsavedWorkflow;
    while (unsent != null) {
      final Workflow sent = unsent;
      await _workflowRepository.saveWorkflow(sent);

      final bool isLatestSaved = identical(_unsavedWorkflow, sent);
      unsent = isLatestSaved ? null : _unsavedWorkflow;
    }
  }

  void _showUnsaved(Workflow? unsaved) {
    _unsavedWorkflow = unsaved;
    if (!_isDisposed) {
      notifyListeners();
    }
  }
}
