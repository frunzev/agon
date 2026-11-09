import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/data/rules/workflow_graph.dart';
import 'package:agent_orchestration/screens/workflow_builder/workflow_diagram_editor.dart';

import '../../../support/random_inputs.dart';
import '../../../support/workflow_repositories.dart';
import 'held_reply_workflow_repository.dart';

typedef EditorEdit = Future<void> Function(WorkflowDiagramEditor editor);

const WorkflowId _editedWorkflowId = GalleryWorkflowIds.featurePipeline;
const double _largestCanvasOffset = 2000;
const int _editKindCount = 5;

final class QueuedEditorPair {
  QueuedEditorPair()
    : _instantRepository = buildGalleryWorkflowRepository(),
      held = HeldReplyWorkflowRepository(
        stored: buildGalleryWorkflowRepository(),
      ) {
    sequential = WorkflowDiagramEditor(
      workflowRepository: _instantRepository,
      workflowId: _editedWorkflowId,
    );
    queued = WorkflowDiagramEditor(
      workflowRepository: held,
      workflowId: _editedWorkflowId,
    );
  }

  final FakeWorkflowRepository _instantRepository;
  final HeldReplyWorkflowRepository held;
  late final WorkflowDiagramEditor sequential;
  late final WorkflowDiagramEditor queued;
  final List<Future<void>> queuedSaves = <Future<void>>[];

  Workflow readExpected() => sequential.readLatestWorkflow();

  Workflow readSaved() => held.findWorkflow(_editedWorkflowId);

  Future<void> apply(EditorEdit edit) async {
    await edit(sequential);
    queuedSaves.add(edit(queued));
  }

  Future<void> releaseOneReply() async {
    held.releaseNextReply();
    await pumpEventQueue();
  }

  Future<void> releaseEveryReply() async {
    await pumpEventQueue();
    while (held.heldReplyCount > 0) {
      await releaseOneReply();
    }
    await Future.wait(queuedSaves);
  }
}

void expectSameDesign(Workflow actual, Workflow expected) {
  expect(actual.agents, expected.agents);
  expect(actual.connections, expected.connections);
}

CanvasPosition _randomEditorPosition(Random random) {
  return CanvasPosition(
    horizontal: random.nextDouble() * _largestCanvasOffset,
    vertical: random.nextDouble() * _largestCanvasOffset,
  );
}

EditorEdit randomMoveEdit(Random random, Workflow latest) {
  final WorkflowAgentId agentId = pickOne(random, latest.agents).id;
  final CanvasPosition position = _randomEditorPosition(random);
  return (WorkflowDiagramEditor editor) => editor.moveAgent(agentId, position);
}

EditorEdit randomTaskEdit(Random random, Workflow latest) {
  final WorkflowAgent agent = pickOne(random, latest.agents);
  final WorkflowAgent changed = agent.copyWith(
    task: randomText(random),
    kind: pickOne(random, AgentKind.values),
  );
  return (WorkflowDiagramEditor editor) => editor.changeAgent(changed);
}

EditorEdit addStepEdit(Workflow latest) {
  final WorkflowAgent blank = buildBlankAgent(latest);
  return (WorkflowDiagramEditor editor) => editor.addStep(blank);
}

AgentConnection? _findFreeForwardConnection(Random random, Workflow latest) {
  final List<AgentConnection> candidates = <AgentConnection>[];
  for (final WorkflowAgent from in latest.agents) {
    for (final WorkflowAgent to in latest.agents) {
      final AgentConnection candidate = AgentConnection(
        from: from.id,
        to: to.id,
        condition: null,
        roundLimit: null,
      );
      final bool isFree = findConnectionProblem(latest, candidate) == null;
      if (isFree && !pointsBack(latest, candidate)) {
        candidates.add(candidate);
      }
    }
  }
  if (candidates.isEmpty) {
    return null;
  }
  return pickOne(random, candidates);
}

EditorEdit _randomConnectionEdit(Random random, Workflow latest) {
  final AgentConnection? free = _findFreeForwardConnection(random, latest);
  if (free == null) {
    return addStepEdit(latest);
  }
  return (WorkflowDiagramEditor editor) => editor.connect(free);
}

EditorEdit _randomRemovalEdit(Random random, Workflow latest) {
  if (latest.connections.isNotEmpty && random.nextBool()) {
    final AgentConnection removed = pickOne(random, latest.connections);
    return (WorkflowDiagramEditor editor) => editor.removeConnection(removed);
  }
  if (latest.agents.length > 1) {
    final WorkflowAgentId agentId = pickOne(random, latest.agents).id;
    return (WorkflowDiagramEditor editor) => editor.removeAgent(agentId);
  }
  return addStepEdit(latest);
}

EditorEdit randomEditorEdit(Random random, Workflow latest) {
  switch (random.nextInt(_editKindCount)) {
    case 0:
      return randomMoveEdit(random, latest);
    case 1:
      return randomTaskEdit(random, latest);
    case 2:
      return addStepEdit(latest);
    case 3:
      return _randomConnectionEdit(random, latest);
    default:
      return _randomRemovalEdit(random, latest);
  }
}
