import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/editable_diagram_scene.dart';
import 'support/random_diagram_layouts.dart';

const double _tolerance = 1e-3;

Offset _readOriginFromCorner(WidgetTester tester, Finder diagram) {
  final RenderBox canvas = tester.renderObject<RenderBox>(
    find.descendant(of: diagram, matching: find.byType(WorkflowDiagram)),
  );
  return canvas.localToGlobal(Offset.zero) - tester.getTopLeft(diagram);
}

Future<bool> _panEmptyCanvas(
  WidgetTester tester,
  Random random,
  Workflow workflow,
) async {
  final Offset? empty = pickEmptyGlobalPoint(tester, random, workflow);
  if (empty == null) {
    return false;
  }
  await tester.dragFrom(empty, Offset(40 + random.nextDouble() * 60, 35));
  await tester.pump();
  return true;
}

Future<TestGesture?> _grabSomething(
  WidgetTester tester,
  Random random,
  Workflow workflow,
) async {
  final ReachableAgent? grabbed = pickReachableAgent(
    tester,
    random: random,
    workflow: workflow,
    findPoint: random.nextBool()
        ? findNodeCentre
        : (WorkflowAgent agent) => findOutputPort(agent.position),
  );
  final Offset? start =
      grabbed?.global ?? pickEmptyGlobalPoint(tester, random, workflow);
  if (start == null) {
    return null;
  }
  final TestGesture gesture = await tester.startGesture(start);
  await gesture.moveBy(const Offset(45, 35));
  await tester.pump();
  return gesture;
}

void main() {
  testWidgets('test_editable_workflow_diagram_create_state_property_each_'
      'diagram_keeps_its_own_view', (WidgetTester tester) async {
    final Random random = seededRandom(1191603);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow laidOut = randomLaidOutWorkflow(random);
      final Workflow workflow = laidOut.withGraph(
        agents: const <WorkflowAgent>[],
        connections: const <AgentConnection>[],
      );
      final EditableDiagramScene first = EditableDiagramScene(
        workflow: workflow,
        selection: null,
      );
      final EditableDiagramScene second = EditableDiagramScene(
        workflow: workflow,
        selection: null,
      );
      useViewSize(tester, const Size(desktopWidth, desktopHeight));
      await tester.pumpWidget(
        wrapInApp(
          Row(
            children: <Widget>[
              Expanded(child: first.buildDiagram()),
              Expanded(child: second.buildDiagram()),
            ],
          ),
          platform: desktopPlatform,
        ),
      );
      final Finder diagrams = find.byType(EditableWorkflowDiagram);
      final Offset secondBefore = _readOriginFromCorner(tester, diagrams.last);
      final Rect firstRect = tester.getRect(diagrams.first);

      final Offset shift = Offset(30 + random.nextDouble() * 50, -40);
      await tester.dragFrom(firstRect.center, shift);
      await tester.pump();

      expect(_readOriginFromCorner(tester, diagrams.last), secondBefore);
      expect(first.reportCount + second.reportCount, 0);
    }
  });

  testWidgets('test_editable_workflow_diagram_create_state_property_view_'
      'survives_a_new_workflow', (WidgetTester tester) async {
    final Random random = seededRandom(1191604);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomLaidOutWorkflow(random);
      await pumpEditableDiagram(tester, random: random, workflow: workflow);
      if (!await _panEmptyCanvas(tester, random, workflow)) {
        continue;
      }
      final Finder diagram = find.byType(EditableWorkflowDiagram);
      final Offset panned = _readOriginFromCorner(tester, diagram);

      await repumpEditableDiagram(
        tester,
        workflow: randomLaidOutWorkflow(random),
      );

      expect(_readOriginFromCorner(tester, diagram), panned);
    }
  });

  testWidgets('test_editable_workflow_diagram_create_state_property_new_'
      'diagram_starts_at_the_starting_view', (WidgetTester tester) async {
    final Random random = seededRandom(1191605);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomLaidOutWorkflow(random);
      await pumpEditableDiagram(tester, random: random, workflow: workflow);
      await _panEmptyCanvas(tester, random, workflow);

      await tester.pumpWidget(const SizedBox.shrink());
      await repumpEditableDiagram(tester, workflow: workflow);

      final Offset origin = _readOriginFromCorner(
        tester,
        find.byType(EditableWorkflowDiagram),
      );
      expect(
        (origin - startingCanvasView.offset).distance,
        lessThan(_tolerance),
      );
      expect(readCanvasScale(tester), startingCanvasView.scale);
    }
  });

  testWidgets('test_editable_workflow_diagram_dispose_property_unmounting_'
      'mid_drag_reports_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1191606);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomLaidOutWorkflow(random);
      final EditableDiagramScene scene = await pumpEditableDiagram(
        tester,
        random: random,
        workflow: workflow,
      );
      final TestGesture? gesture = await _grabSomething(
        tester,
        random,
        workflow,
      );
      if (gesture == null) {
        continue;
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await gesture.moveBy(const Offset(20, 20));
      await gesture.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(scene.reportCount, 0);
    }
  });

  testWidgets('test_editable_workflow_diagram_dispose_property_unmounting_'
      'mid_drag_then_remounting_is_idle', (WidgetTester tester) async {
    final Random random = seededRandom(1191607);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomLaidOutWorkflow(random);
      await pumpEditableDiagram(tester, random: random, workflow: workflow);
      final TestGesture? gesture = await _grabSomething(
        tester,
        random,
        workflow,
      );
      if (gesture == null) {
        continue;
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await gesture.up();
      final EditableDiagramScene again = await repumpEditableDiagram(
        tester,
        workflow: workflow,
      );

      expect(readShownDiagram(tester).drawnEdge, isNull);
      expect(again.reportCount, 0);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_editable_workflow_diagram_dispose_property_unmounting_'
      'while_hovered_is_quiet', (WidgetTester tester) async {
    final Random random = seededRandom(1191608);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomLaidOutWorkflow(random);
      await pumpEditableDiagram(tester, random: random, workflow: workflow);
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      final Rect canvas = tester.getRect(find.byType(EditableWorkflowDiagram));
      await mouse.addPointer(location: canvas.center);
      await mouse.moveTo(canvas.center + const Offset(10, 10));
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await mouse.moveTo(canvas.center);
      await mouse.removePointer();
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });
}
