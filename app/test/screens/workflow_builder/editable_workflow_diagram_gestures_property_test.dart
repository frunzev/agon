import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/editable_diagram_scene.dart';

const double _tolerance = 1e-6;

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
  testWidgets('test_continue_drag_property_moved_step_follows_the_'
      'pointer', (WidgetTester tester) async {
    final Random random = seededRandom(1191307);
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
      final double scale = readCanvasScale(tester);
      final Offset shift = randomDragShift(random);

      await dragThrough(tester, grabbed.global, <Offset>[
        grabbed.global + shift,
      ]);

      final CanvasPosition expected = moveCanvasPosition(
        grabbed.agent.position,
        shift / scale,
      );
      final CanvasPosition moved = open.scene.moves.single.position;
      expect(moved.horizontal, closeTo(expected.horizontal, _tolerance));
      expect(moved.vertical, closeTo(expected.vertical, _tolerance));
    }
  });

  testWidgets('test_continue_drag_property_moved_step_never_leaves_the_'
      'canvas_origin', (WidgetTester tester) async {
    final Random random = seededRandom(1191308);
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
      final Offset farUpLeft = grabbed.global - const Offset(3000, 3000);

      await dragThrough(tester, grabbed.global, <Offset>[
        grabbed.global + randomDragShift(random),
        farUpLeft,
      ]);

      final CanvasPosition moved = open.scene.moves.single.position;
      expect(moved.horizontal, 0);
      expect(moved.vertical, 0);
    }
  });

  testWidgets('test_continue_drag_property_drawing_tracks_every_move', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191309);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenDiagram open = await openLaidOutDiagram(tester, random);
      final ReachableAgent? start = pickReachableAgent(
        tester,
        random: random,
        workflow: open.workflow,
        findPoint: findOutputPortOf,
      );
      if (start == null) {
        continue;
      }
      final TestGesture gesture = await tester.startGesture(start.global);
      Offset pointer = start.global;

      for (int step = 0; step < 3; step += 1) {
        pointer = pointer + randomDragShift(random);
        await gesture.moveTo(pointer);
        await tester.pump();
        final EdgeCurve drawn = readShownDiagram(tester).drawnEdge!;
        final Offset expected = findCanvasPointAt(tester, pointer);
        expect((drawn.end - expected).distance, lessThan(_tolerance));
      }
      await gesture.up();
      await tester.pump();
    }
  });

  testWidgets('test_finish_drag_property_output_dropped_on_a_step_'
      'connects_into_it', (WidgetTester tester) async {
    final Random random = seededRandom(1191310);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _expectDropConnects(
        tester,
        random,
        findStartPort: findOutputPortOf,
        startsAtSource: true,
      );
    }
  });

  testWidgets('test_finish_drag_property_input_dropped_on_a_step_'
      'connects_from_it', (WidgetTester tester) async {
    final Random random = seededRandom(1191311);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _expectDropConnects(
        tester,
        random,
        findStartPort: findInputPortOf,
        startsAtSource: false,
      );
    }
  });

  testWidgets('test_finish_drag_property_dropped_on_nothing_connects_'
      'nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1191312);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OpenDiagram open = await openLaidOutDiagram(tester, random);
      final ReachableAgent? start = pickReachableAgent(
        tester,
        random: random,
        workflow: open.workflow,
        findPoint: random.nextBool() ? findOutputPortOf : findInputPortOf,
      );
      final Offset? empty = pickEmptyGlobalPoint(
        tester,
        random,
        open.workflow,
      );
      if (start == null || empty == null) {
        continue;
      }

      await dragThrough(tester, start.global, <Offset>[empty]);

      expect(open.scene.reportCount, 0);
      expect(readShownDiagram(tester).drawnEdge, isNull);
    }
  });
}
