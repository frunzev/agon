import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/hovered_cursor.dart';
import '../../support/random_inputs.dart';
import 'support/editable_diagram_scene.dart';
import 'support/random_diagram_layouts.dart';

Offset _findPortOf(Random random, WorkflowAgent agent) {
  return random.nextBool()
      ? findInputPort(agent.position)
      : findOutputPort(agent.position);
}

Offset? _findLabelPoint(WidgetTester tester, DiagramEdge edge) {
  if (edge.label == null) {
    return null;
  }
  final Offset centre = findLabelCentre(edge.route);
  final Offset global = findGlobalCanvasPoint(tester, centre);
  return isReachable(tester, global) ? global : null;
}

bool _isOnAStep(WidgetTester tester, Workflow workflow, Offset global) {
  final Offset centre = findCanvasPointAt(tester, global);
  for (final WorkflowAgent agent in workflow.agents) {
    final Rect reach = findNodeRect(agent.position)
        .inflate(CanvasMetrics.portHitRadius);
    if (reach.contains(centre)) {
      return true;
    }
  }
  return false;
}

Future<OpenDiagram?> _openWithDrawnLoop(
  WidgetTester tester,
  Random random,
) async {
  final Workflow laidOut = randomLaidOutWorkflow(random);
  if (laidOut.agents.length < 2) {
    return null;
  }
  final AgentConnection loop = AgentConnection(
    from: laidOut.agents.last.id,
    to: laidOut.agents.first.id,
    condition: 'loop-${random.nextInt(99)}',
    roundLimit: 1 + random.nextInt(10),
  );
  final EditableDiagramScene scene = await pumpEditableDiagram(
    tester,
    random: random,
    workflow: laidOut,
    selection: DrawnLoop(loop),
  );
  return (scene: scene, workflow: laidOut);
}

Offset? _findLonelyDrawnLoopLabel(WidgetTester tester, Workflow workflow) {
  final DiagramEdge drawn = readShownDiagram(tester).edges.last;
  final Offset? global = _findLabelPoint(tester, drawn);
  if (global == null) {
    return null;
  }
  final Offset centre = findCanvasPointAt(tester, global);
  return isNearSavedDrawing(workflow, centre) ? null : global;
}

void main() {
  testWidgets('test_choose_shown_cursor_property_moving_a_step_grabs', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191501);
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
      final TestGesture mouse = await hoverMouseAt(tester, grabbed.global);
      await mouse.down(grabbed.global);
      await mouse.moveBy(Offset(40 + random.nextDouble() * 40, 30));
      await tester.pump();

      expect(readMouseCursor(), SystemMouseCursors.grabbing);
      await mouse.up();
      await mouse.removePointer();
      await tester.pump();
    }
  });

  testWidgets('test_choose_shown_cursor_property_grabbing_ends_with_the_'
      'drop', (WidgetTester tester) async {
    final Random random = seededRandom(1191502);
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
      final TestGesture mouse = await hoverMouseAt(tester, grabbed.global);
      await mouse.down(grabbed.global);
      await mouse.moveBy(const Offset(50, 40));
      await tester.pump();
      await mouse.up();
      await tester.pump();

      expect(readMouseCursor(), isNot(SystemMouseCursors.grabbing));
      await mouse.removePointer();
      await tester.pump();
    }
  });

  testWidgets('test_choose_shown_cursor_property_empty_canvas_is_basic', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191503);
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

      expect(await readCursorOver(tester, empty), SystemMouseCursors.basic);
    }
  });

  testWidgets('test_show_cursor_at_property_ports_are_clickable', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191504);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenDiagram open = await openLaidOutDiagram(tester, random);
      final ReachableAgent? port = pickReachableAgent(
        tester,
        random: random,
        workflow: open.workflow,
        findPoint: (WorkflowAgent agent) => _findPortOf(random, agent),
      );
      if (port == null) {
        continue;
      }

      expect(
        await readCursorOver(tester, port.global),
        SystemMouseCursors.click,
      );
    }
  });

  testWidgets('test_show_cursor_at_property_step_bodies_can_be_grabbed', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191505);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenDiagram open = await openLaidOutDiagram(tester, random);
      final ReachableAgent? body = pickReachableAgent(
        tester,
        random: random,
        workflow: open.workflow,
        findPoint: findNodeCentre,
      );
      if (body == null) {
        continue;
      }

      expect(
        await readCursorOver(tester, body.global),
        SystemMouseCursors.grab,
      );
    }
  });

  testWidgets('test_show_cursor_at_property_leaving_a_step_returns_to_'
      'basic', (WidgetTester tester) async {
    final Random random = seededRandom(1191506);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenDiagram open = await openLaidOutDiagram(tester, random);
      final ReachableAgent? body = pickReachableAgent(
        tester,
        random: random,
        workflow: open.workflow,
        findPoint: findNodeCentre,
      );
      final Offset? empty = pickEmptyGlobalPoint(
        tester,
        random,
        open.workflow,
      );
      if (body == null || empty == null) {
        continue;
      }
      final TestGesture mouse = await hoverMouseAt(tester, body.global);

      await mouse.moveTo(empty);
      await tester.pump();
      expect(readMouseCursor(), SystemMouseCursors.basic);
      await mouse.moveTo(body.global);
      await tester.pump();
      expect(readMouseCursor(), SystemMouseCursors.grab);
      await mouse.removePointer();
      await tester.pump();
    }
  });

  testWidgets('test_find_saved_edge_hit_property_saved_labels_are_'
      'clickable', (WidgetTester tester) async {
    final Random random = seededRandom(1191507);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenDiagram open = await openLaidOutDiagram(tester, random);
      for (final DiagramEdge edge in describeSavedEdges(open.workflow)) {
        final Offset? label = _findLabelPoint(tester, edge);
        if (label == null || _isOnAStep(tester, open.workflow, label)) {
          continue;
        }

        expect(await readCursorOver(tester, label), SystemMouseCursors.click);
      }
    }
  });

  testWidgets('test_find_saved_edge_hit_property_drawn_loop_label_is_not_'
      'clickable', (WidgetTester tester) async {
    final Random random = seededRandom(1191508);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenDiagram? open = await _openWithDrawnLoop(tester, random);
      if (open == null) {
        continue;
      }
      final Offset? label = _findLonelyDrawnLoopLabel(tester, open.workflow);
      if (label == null) {
        continue;
      }

      expect(await readCursorOver(tester, label), SystemMouseCursors.basic);
    }
  });

  testWidgets('test_find_saved_edge_hit_property_tapping_a_drawn_loop_'
      'clears', (WidgetTester tester) async {
    final Random random = seededRandom(1191509);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenDiagram? open = await _openWithDrawnLoop(tester, random);
      if (open == null) {
        continue;
      }
      final Offset? label = _findLonelyDrawnLoopLabel(tester, open.workflow);
      if (label == null) {
        continue;
      }

      await tester.tapAt(label);
      await tester.pump();

      expect(open.scene.selectedConnections, isEmpty);
      expect(open.scene.clearCount, 1);
    }
  });
}
