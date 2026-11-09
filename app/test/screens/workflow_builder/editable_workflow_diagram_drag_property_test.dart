import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/workflow_edits.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/editable_diagram_scene.dart';
import 'support/random_diagram_layouts.dart';

const double _pointTolerance = 1e-6;

FindAgentPoint _choosePortFinder(PortSide side) {
  switch (side) {
    case PortSide.input:
      return findInputPortOf;
    case PortSide.output:
      return findOutputPortOf;
  }
}

ReachableAgent? _pickReachablePort(
  WidgetTester tester,
  Random random,
  Workflow workflow,
  PortSide side,
) {
  return pickReachableAgent(
    tester,
    random: random,
    workflow: workflow,
    findPoint: _choosePortFinder(side),
  );
}

void _expectSamePoint(Offset actual, Offset expected) {
  expect(actual.dx, closeTo(expected.dx, _pointTolerance));
  expect(actual.dy, closeTo(expected.dy, _pointTolerance));
}

Future<TestGesture?> _startDrawingFrom(
  WidgetTester tester,
  Random random,
  PortSide side,
) async {
  final Workflow workflow = randomLaidOutWorkflow(random);
  await pumpEditableDiagram(tester, random: random, workflow: workflow);
  final ReachableAgent? port = _pickReachablePort(
    tester,
    random,
    workflow,
    side,
  );
  if (port == null) {
    return null;
  }
  final TestGesture gesture = await tester.startGesture(port.global);
  await gesture.moveBy(randomDragShift(random));
  await tester.pump();
  return gesture;
}

Future<void> _finishAfterRemovingTheAgent(
  WidgetTester tester,
  Random random, {
  required FindAgentPoint findPoint,
}) async {
  final Workflow workflow = randomLaidOutWorkflow(random);
  await pumpEditableDiagram(tester, random: random, workflow: workflow);
  final ReachableAgent? grabbed = pickReachableAgent(
    tester,
    random: random,
    workflow: workflow,
    findPoint: findPoint,
  );
  if (grabbed == null) {
    return;
  }
  final TestGesture gesture = await tester.startGesture(grabbed.global);
  await gesture.moveBy(randomDragShift(random));
  await tester.pump();

  final EditableDiagramScene after = await repumpEditableDiagram(
    tester,
    workflow: removeAgent(workflow, grabbed.agent.id),
  );
  await gesture.moveBy(randomDragShift(random));
  await gesture.up();
  await tester.pump();

  expect(tester.takeException(), isNull);
  expect(readShownDiagram(tester).drawnEdge, isNull);
  expect(after.reportCount, 0);
}

void main() {
  testWidgets('test_build_drawn_edge_property_from_an_input_the_arrow_'
      'points_at_the_step', (WidgetTester tester) async {
    final Random random = seededRandom(1191201);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomLaidOutWorkflow(random);
      await pumpEditableDiagram(tester, random: random, workflow: workflow);
      final ReachableAgent? port = _pickReachablePort(
        tester,
        random,
        workflow,
        PortSide.input,
      );
      if (port == null) {
        continue;
      }
      final TestGesture gesture = await tester.startGesture(port.global);
      final Offset shift = randomDragShift(random);
      await gesture.moveBy(shift);
      await tester.pump();

      final EdgeCurve drawn = readShownDiagram(tester).drawnEdge!;
      _expectSamePoint(drawn.end, findInputPort(port.agent.position));
      _expectSamePoint(
        drawn.start,
        findCanvasPointAt(tester, port.global + shift),
      );
      await gesture.up();
      await tester.pump();
    }
  });

  testWidgets('test_build_drawn_edge_property_from_an_output_the_arrow_'
      'follows_the_pointer', (WidgetTester tester) async {
    final Random random = seededRandom(1191202);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomLaidOutWorkflow(random);
      await pumpEditableDiagram(tester, random: random, workflow: workflow);
      final ReachableAgent? port = _pickReachablePort(
        tester,
        random,
        workflow,
        PortSide.output,
      );
      if (port == null) {
        continue;
      }
      final TestGesture gesture = await tester.startGesture(port.global);
      final Offset shift = randomDragShift(random);
      await gesture.moveBy(shift);
      await tester.pump();

      final EdgeCurve drawn = readShownDiagram(tester).drawnEdge!;
      _expectSamePoint(drawn.start, findOutputPort(port.agent.position));
      _expectSamePoint(
        drawn.end,
        findCanvasPointAt(tester, port.global + shift),
      );
      await gesture.up();
      await tester.pump();
    }
  });

  testWidgets('test_build_drawn_edge_property_only_while_drawing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1191203);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PortSide side = pickOne(random, PortSide.values);
      expect(readShownDiagramIfAny(tester)?.drawnEdge, isNull);
      final TestGesture? gesture = await _startDrawingFrom(
        tester,
        random,
        side,
      );
      if (gesture == null) {
        continue;
      }

      expect(readShownDiagram(tester).drawnEdge, isNotNull);
      await gesture.up();
      await tester.pump();
      expect(readShownDiagram(tester).drawnEdge, isNull);
    }
  });

  testWidgets('test_editable_workflow_diagram_did_update_widget_property_'
      'removed_drawing_start_ends_the_drawing', (WidgetTester tester) async {
    final Random random = seededRandom(1191204);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _finishAfterRemovingTheAgent(
        tester,
        random,
        findPoint: random.nextBool() ? findInputPortOf : findOutputPortOf,
      );
    }
  });

  testWidgets('test_editable_workflow_diagram_did_update_widget_property_'
      'removed_moved_step_reports_no_move', (WidgetTester tester) async {
    final Random random = seededRandom(1191205);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _finishAfterRemovingTheAgent(
        tester,
        random,
        findPoint: findNodeCentre,
      );
    }
  });

  testWidgets('test_editable_workflow_diagram_did_update_widget_property_'
      'kept_step_keeps_moving', (WidgetTester tester) async {
    final Random random = seededRandom(1191206);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomLaidOutWorkflow(random);
      await pumpEditableDiagram(tester, random: random, workflow: workflow);
      final ReachableAgent? grabbed = pickReachableAgent(
        tester,
        random: random,
        workflow: workflow,
        findPoint: findNodeCentre,
      );
      if (grabbed == null) {
        continue;
      }
      final TestGesture gesture = await tester.startGesture(grabbed.global);
      await gesture.moveBy(randomDragShift(random));
      await tester.pump();

      final EditableDiagramScene after = await repumpEditableDiagram(
        tester,
        workflow: workflow,
      );
      await gesture.up();
      await tester.pump();

      expect(after.moves, hasLength(1));
      expect(after.moves.single.agentId, grabbed.agent.id);
    }
  });
}

WorkflowDiagram? readShownDiagramIfAny(WidgetTester tester) {
  final Finder diagram = find.byType(WorkflowDiagram);
  if (diagram.evaluate().isEmpty) {
    return null;
  }
  return tester.widget<WorkflowDiagram>(diagram);
}
