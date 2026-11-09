import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import '../support/random_page_windows.dart';
import 'support/random_diagram_layouts.dart';

const double _tolerance = 1e-3;
const Duration _pauseBetweenDrags = Duration(seconds: 1);

List<DiagramNode> _describeNodes(Workflow workflow) {
  return <DiagramNode>[
    for (final WorkflowAgent agent in workflow.agents)
      describeAgentNode(
        agent: agent,
        workflow: workflow,
        deviceNames: DeviceNames(galleryDevices),
        look: NodeLook.normal,
      ),
  ];
}

Future<Workflow> _pumpReadOnly(
  WidgetTester tester,
  Random random, {
  Key? key,
}) async {
  final Workflow workflow = randomDiagramWorkflow(random);
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SizedBox.expand(
      child: ReadOnlyWorkflowDiagram(
        key: key,
        nodes: _describeNodes(workflow),
        edges: describeSavedEdges(workflow),
      ),
    ),
  );
  return workflow;
}

Offset _readOrigin(WidgetTester tester) {
  final RenderBox canvas = tester.renderObject<RenderBox>(
    find.byType(WorkflowDiagram),
  );
  final Offset corner = tester.getTopLeft(
    find.byType(ReadOnlyWorkflowDiagram),
  );
  return canvas.localToGlobal(Offset.zero) - corner;
}

Offset _randomShift(Random random) {
  return Offset(
    (random.nextBool() ? 1 : -1) * (30 + random.nextDouble() * 80),
    (random.nextBool() ? 1 : -1) * (30 + random.nextDouble() * 80),
  );
}

Offset _findPanStart(WidgetTester tester) {
  final Rect canvas = tester.getRect(find.byType(ReadOnlyWorkflowDiagram));
  return Offset(
    canvas.right - canvas.width / 4,
    canvas.top + canvas.height / 3,
  );
}

void _expectNear(Offset actual, Offset expected) {
  expect((actual - expected).distance, lessThan(_tolerance));
}

void main() {
  testWidgets('test_read_only_workflow_diagram_build_property_draws_what_'
      'it_is_given', (WidgetTester tester) async {
    final Random random = seededRandom(1192101);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = await _pumpReadOnly(tester, random);

      final WorkflowDiagram diagram = tester.widget(
        find.byType(WorkflowDiagram),
      );
      expect(tester.takeException(), isNull);
      expect(diagram.nodes, hasLength(workflow.agents.length));
      expect(diagram.edges, hasLength(workflow.connections.length));
      expect(diagram.drawnEdge, isNull);
    }
  });

  testWidgets('test_read_only_workflow_diagram_build_property_canvas_holds_'
      'every_step', (WidgetTester tester) async {
    final Random random = seededRandom(1192102);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = await _pumpReadOnly(tester, random);

      final WorkflowDiagram diagram = tester.widget(
        find.byType(WorkflowDiagram),
      );
      for (final WorkflowAgent agent in workflow.agents) {
        final Rect node = findNodeRect(agent.position);
        expect(node.right, lessThanOrEqualTo(diagram.size.width));
        expect(node.bottom, lessThanOrEqualTo(diagram.size.height));
      }
    }
  });

  testWidgets('test_read_only_workflow_diagram_build_property_starts_at_'
      'the_starting_view', (WidgetTester tester) async {
    final Random random = seededRandom(1192103);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpReadOnly(tester, random, key: UniqueKey());

      _expectNear(_readOrigin(tester), startingCanvasView.offset);
    }
  });

  testWidgets('test_pan_view_property_dragging_moves_the_canvas_with_the_'
      'pointer', (WidgetTester tester) async {
    final Random random = seededRandom(1192104);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpReadOnly(tester, random, key: UniqueKey());
      final Offset before = _readOrigin(tester);
      final Offset shift = _randomShift(random);

      await tester.dragFrom(_findPanStart(tester), shift);
      await tester.pump();

      _expectNear(_readOrigin(tester), before + shift);
    }
  });

  testWidgets('test_pan_view_property_drags_add_up', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1192105);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpReadOnly(tester, random, key: UniqueKey());
      final Offset before = _readOrigin(tester);
      final int dragCount = 1 + random.nextInt(3);
      Offset total = Offset.zero;

      for (int drag = 0; drag < dragCount; drag += 1) {
        final Offset shift = _randomShift(random);
        total += shift;
        await tester.dragFrom(_findPanStart(tester), shift);
        await tester.pump(_pauseBetweenDrags);
      }

      _expectNear(_readOrigin(tester), before + total);
    }
  });

  testWidgets('test_pan_view_property_taps_do_not_move_the_canvas', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1192106);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpReadOnly(tester, random, key: UniqueKey());
      final Offset before = _readOrigin(tester);

      await tester.tapAt(_findPanStart(tester));
      await tester.pump();

      _expectNear(_readOrigin(tester), before);
    }
  });

  testWidgets('test_read_only_workflow_diagram_dispose_property_unmounting_'
      'mid_pan_is_quiet', (WidgetTester tester) async {
    final Random random = seededRandom(1192107);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpReadOnly(tester, random);
      final TestGesture gesture = await tester.startGesture(
        _findPanStart(tester),
      );
      await gesture.moveBy(_randomShift(random));
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await gesture.moveBy(_randomShift(random));
      await gesture.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_read_only_workflow_diagram_dispose_property_a_new_'
      'diagram_forgets_the_pan', (WidgetTester tester) async {
    final Random random = seededRandom(1192108);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpReadOnly(tester, random, key: UniqueKey());
      await tester.dragFrom(_findPanStart(tester), _randomShift(random));
      await tester.pump();

      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpReadOnly(tester, random, key: UniqueKey());

      _expectNear(_readOrigin(tester), startingCanvasView.offset);
    }
  });

  testWidgets('test_read_only_workflow_diagram_dispose_property_same_'
      'diagram_keeps_the_pan', (WidgetTester tester) async {
    final Random random = seededRandom(1192109);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      final Widget page = SizedBox.expand(
        child: ReadOnlyWorkflowDiagram(
          nodes: _describeNodes(workflow),
          edges: describeSavedEdges(workflow),
        ),
      );
      useViewSize(tester, const Size(desktopWidth, desktopHeight));
      await tester.pumpWidget(wrapInApp(page, platform: desktopPlatform));
      await tester.dragFrom(_findPanStart(tester), _randomShift(random));
      await tester.pump();
      final Offset panned = _readOrigin(tester);

      await tester.pumpWidget(wrapInApp(page, platform: desktopPlatform));

      _expectNear(_readOrigin(tester), panned);
    }
  });
}
