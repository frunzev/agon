import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/editable_diagram_scene.dart';
import 'support/random_diagram_layouts.dart';

Future<void> _expectDropConnects(
  WidgetTester tester,
  Random random, {
  required FindAgentPoint findStartPort,
  required bool startsAtSource,
}) async {
  final OpenDiagram open = await openLaidOutDiagram(tester, random);
  final ReachableAgent? start = pickReachableAgent(
    tester,
    random: random,
    workflow: open.workflow,
    findPoint: findStartPort,
  );
  if (start == null) {
    return;
  }
  final WorkflowAgent other = pickOne(random, open.workflow.agents);
  final Offset drop = findGlobalCanvasPoint(tester, findNodeCentre(other));
  final Offset away = start.global + randomDragShift(random);

  await dragThrough(tester, start.global, <Offset>[away, drop]);

  final AgentConnection drawn = open.scene.drawnConnections.single;
  expect(drawn.from, startsAtSource ? start.agent.id : other.id);
  expect(drawn.to, startsAtSource ? other.id : start.agent.id);
  expect(drawn.condition, isNull);
  expect(drawn.roundLimit, isNull);
  expect(open.scene.moves, isEmpty);
}

void main() {
  testWidgets('test_select_at_property_tapping_a_step_selects_it', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191301);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenDiagram open = await openLaidOutDiagram(tester, random);
      final ReachableAgent? tapped = pickReachableAgent(
        tester,
        random: random,
        workflow: open.workflow,
        findPoint: findNodeCentre,
      );
      if (tapped == null) {
        continue;
      }

      await tester.tapAt(tapped.global);
      await tester.pump();

      expect(open.scene.selectedAgents, <Object>[tapped.agent.id]);
      expect(open.scene.reportCount, 1);
    }
  });

  testWidgets('test_select_at_property_tapping_empty_canvas_clears', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191302);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenDiagram open = await openLaidOutDiagram(tester, random);
      final Offset? empty = pickEmptyGlobalPoint(
        tester,
        random,
        open.workflow,
      );
      if (empty == null) {
        continue;
      }

      await tester.tapAt(empty);
      await tester.pump();

      expect(open.scene.clearCount, 1);
      expect(open.scene.reportCount, 1);
    }
  });

  testWidgets('test_select_at_property_tapping_a_label_selects_its_'
      'connection', (WidgetTester tester) async {
    final Random random = seededRandom(1191303);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenDiagram open = await openLaidOutDiagram(tester, random);
      final List<DiagramEdge> labelled = <DiagramEdge>[
        for (final DiagramEdge edge in describeSavedEdges(open.workflow))
          if (edge.label != null) edge,
      ];
      if (labelled.isEmpty) {
        continue;
      }
      final DiagramEdge edge = pickOne(random, labelled);
      final Offset centre = findLabelCentre(edge.route);
      final Offset global = findGlobalCanvasPoint(tester, centre);
      final bool isOnAStep = open.workflow.agents.any(
        (WorkflowAgent agent) =>
            findNodeRect(agent.position)
                .inflate(CanvasMetrics.portHitRadius)
                .contains(centre),
      );
      if (isOnAStep || !isReachable(tester, global)) {
        continue;
      }

      await tester.tapAt(global);
      await tester.pump();

      expect(open.scene.reportCount, 1);
      expect(open.scene.selectedConnections, hasLength(1));
    }
  });

  testWidgets('test_start_drag_property_grabbing_a_step_moves_only_it', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191304);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenDiagram open = await openLaidOutDiagram(tester, random);
      final ReachableAgent? grabbed = pickReachableAgent(
        tester,
        random: random,
        workflow: open.workflow,
        findPoint: findNodeCentre,
      );
      if (grabbed == null) {
        continue;
      }

      await dragThrough(tester, grabbed.global, <Offset>[
        grabbed.global + randomDragShift(random),
      ]);

      expect(open.scene.moves.single.agentId, grabbed.agent.id);
      expect(open.scene.reportCount, 1);
    }
  });

  testWidgets('test_start_drag_property_grabbing_empty_canvas_pans_'
      'silently', (WidgetTester tester) async {
    final Random random = seededRandom(1191305);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenDiagram open = await openLaidOutDiagram(tester, random);
      final Offset? empty = pickEmptyGlobalPoint(
        tester,
        random,
        open.workflow,
      );
      if (empty == null) {
        continue;
      }
      final Offset originBefore = findGlobalCanvasPoint(tester, Offset.zero);
      final Offset shift = randomDragShift(random);

      await dragThrough(tester, empty, <Offset>[empty + shift]);

      final Offset originAfter = findGlobalCanvasPoint(tester, Offset.zero);
      expect((originAfter - originBefore - shift).distance, lessThan(1e-3));
      expect(open.scene.reportCount, 0);
    }
  });

  testWidgets('test_start_drag_property_grabbing_a_port_draws_no_move', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191306);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _expectDropConnects(
        tester,
        random,
        findStartPort: findOutputPortOf,
        startsAtSource: true,
      );
    }
  });
}
