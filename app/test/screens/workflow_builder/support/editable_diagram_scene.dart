import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../../support/widget_harness.dart';
import '../../support/random_page_windows.dart';
import 'random_diagram_layouts.dart';

typedef AgentMove = ({WorkflowAgentId agentId, CanvasPosition position});

const double _visibleMargin = 4;

final class EditableDiagramScene {
  EditableDiagramScene({required this.workflow, required this.selection});

  final Workflow workflow;
  final BuilderSelection? selection;
  final List<WorkflowAgentId> selectedAgents = <WorkflowAgentId>[];
  final List<AgentConnection> selectedConnections = <AgentConnection>[];
  final List<AgentMove> moves = <AgentMove>[];
  final List<AgentConnection> drawnConnections = <AgentConnection>[];
  int clearCount = 0;

  int get reportCount {
    return selectedAgents.length +
        selectedConnections.length +
        moves.length +
        drawnConnections.length +
        clearCount;
  }

  EditableWorkflowDiagram buildDiagram() {
    return EditableWorkflowDiagram(
      workflow: workflow,
      selection: selection,
      deviceNames: DeviceNames(galleryDevices),
      onAgentSelected: selectedAgents.add,
      onConnectionSelected: selectedConnections.add,
      onSelectionCleared: _countClear,
      onAgentMoved: _recordMove,
      onAgentsConnected: drawnConnections.add,
    );
  }

  void _countClear() {
    clearCount += 1;
  }

  void _recordMove(WorkflowAgentId agentId, CanvasPosition position) {
    moves.add((agentId: agentId, position: position));
  }
}

Future<EditableDiagramScene> pumpEditableDiagram(
  WidgetTester tester, {
  required Random random,
  required Workflow workflow,
  BuilderSelection? selection,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  useViewSize(tester, randomPageWindowSize(random));
  return repumpEditableDiagram(
    tester,
    workflow: workflow,
    selection: selection,
  );
}

Future<EditableDiagramScene> repumpEditableDiagram(
  WidgetTester tester, {
  required Workflow workflow,
  BuilderSelection? selection,
}) async {
  final EditableDiagramScene scene = EditableDiagramScene(
    workflow: workflow,
    selection: selection,
  );
  final double windowWidth = tester.view.physicalSize.width;
  await tester.pumpWidget(
    wrapInApp(
      SizedBox.expand(child: scene.buildDiagram()),
      platform: platformMeantByWidth(windowWidth),
    ),
  );
  await tester.pump();
  return scene;
}

RenderBox _findDiagramBox(WidgetTester tester) {
  return tester.renderObject<RenderBox>(find.byType(WorkflowDiagram));
}

Offset findGlobalCanvasPoint(WidgetTester tester, Offset canvasPoint) {
  return _findDiagramBox(tester).localToGlobal(canvasPoint);
}

Offset findCanvasPointAt(WidgetTester tester, Offset globalPoint) {
  return _findDiagramBox(tester).globalToLocal(globalPoint);
}

double readCanvasScale(WidgetTester tester) {
  final RenderBox diagram = _findDiagramBox(tester);
  final Offset origin = diagram.localToGlobal(Offset.zero);
  return diagram.localToGlobal(const Offset(1, 0)).dx - origin.dx;
}

bool isReachable(WidgetTester tester, Offset globalPoint) {
  final Rect canvas = tester
      .getRect(find.byType(EditableWorkflowDiagram))
      .deflate(_visibleMargin);
  final Rect zoomButtons = tester
      .getRect(find.byType(CanvasZoomButtons))
      .inflate(_visibleMargin);
  return canvas.contains(globalPoint) && !zoomButtons.contains(globalPoint);
}

WorkflowDiagram readShownDiagram(WidgetTester tester) {
  return tester.widget<WorkflowDiagram>(find.byType(WorkflowDiagram));
}

typedef ReachableAgent = ({WorkflowAgent agent, Offset global});

typedef FindAgentPoint = Offset Function(WorkflowAgent agent);

Offset findNodeCentre(WorkflowAgent agent) {
  return findNodeRect(agent.position).center;
}

ReachableAgent? pickReachableAgent(
  WidgetTester tester, {
  required Random random,
  required Workflow workflow,
  required FindAgentPoint findPoint,
}) {
  final List<WorkflowAgent> agents = List<WorkflowAgent>.of(workflow.agents);
  agents.shuffle(random);
  for (final WorkflowAgent agent in agents) {
    final Offset global = findGlobalCanvasPoint(tester, findPoint(agent));
    if (isReachable(tester, global)) {
      return (agent: agent, global: global);
    }
  }
  return null;
}

const int _emptyPointAttempts = 60;
const double _emptyMargin = CanvasMetrics.portHitRadius + 4;

bool isNearSavedDrawing(Workflow workflow, Offset canvasPoint) {
  for (final WorkflowAgent agent in workflow.agents) {
    final Rect reach = findNodeRect(agent.position).inflate(_emptyMargin);
    if (reach.contains(canvasPoint)) {
      return true;
    }
  }
  final List<DiagramEdge> edges = describeDiagramEdges(
    agents: workflow.agents,
    connections: workflow.connections,
    selected: null,
    drawnLoop: null,
  );
  return findEdgeHit(edges, canvasPoint) != null;
}

Offset? pickEmptyGlobalPoint(
  WidgetTester tester,
  Random random,
  Workflow workflow,
) {
  final Rect canvas = tester.getRect(find.byType(EditableWorkflowDiagram));
  for (int attempt = 0; attempt < _emptyPointAttempts; attempt += 1) {
    final Offset global = Offset(
      canvas.left + random.nextDouble() * canvas.width,
      canvas.top + random.nextDouble() * canvas.height,
    );
    final Offset canvasPoint = findCanvasPointAt(tester, global);
    final bool isEmpty = !isNearSavedDrawing(workflow, canvasPoint);
    if (isEmpty && isReachable(tester, global)) {
      return global;
    }
  }
  return null;
}

typedef OpenDiagram = ({EditableDiagramScene scene, Workflow workflow});

Offset findInputPortOf(WorkflowAgent agent) => findInputPort(agent.position);

Offset findOutputPortOf(WorkflowAgent agent) => findOutputPort(agent.position);

Future<OpenDiagram> openLaidOutDiagram(
  WidgetTester tester,
  Random random, {
  BuilderSelection? selection,
}) async {
  final Workflow workflow = randomLaidOutWorkflow(random);
  final EditableDiagramScene scene = await pumpEditableDiagram(
    tester,
    random: random,
    workflow: workflow,
    selection: selection,
  );
  return (scene: scene, workflow: workflow);
}

double _randomDragDistance(Random random) {
  final double direction = random.nextBool() ? 1 : -1;
  return direction * (30 + random.nextDouble() * 60);
}

Offset randomDragShift(Random random) {
  return Offset(_randomDragDistance(random), _randomDragDistance(random));
}

Future<void> dragThrough(
  WidgetTester tester,
  Offset start,
  List<Offset> stops,
) async {
  final TestGesture gesture = await tester.startGesture(start);
  for (final Offset stop in stops) {
    await gesture.moveTo(stop);
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}
