import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../support/random_inputs.dart';
import 'support/random_diagram_layouts.dart';
import 'support/route_box_checks.dart';

const double _sizeTolerance = 1e-6;
const double _columnGap = layoutColumnPitch - CanvasMetrics.nodeWidth;
const double _extraGap = AppSpacing.space6;

List<Rect> _listStepBoxes(Workflow workflow) {
  return <Rect>[
    for (final WorkflowAgent agent in workflow.agents)
      findNodeRect(agent.position),
  ];
}

List<DiagramEdge> _listLoopEdges(Workflow workflow) {
  return <DiagramEdge>[
    for (final DiagramEdge edge in describeSavedEdges(workflow))
      if (edge.route is LoopRoute) edge,
  ];
}

bool _overlapsInside(Rect first, Rect second) {
  return first.left < second.right &&
      second.left < first.right &&
      first.top < second.bottom &&
      second.top < first.bottom;
}

void main() {
  test('test_route_loop_property_label_area_has_the_measured_size', () {
    final Random random = seededRandom(119501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);

      for (final DiagramEdge edge in _listLoopEdges(workflow)) {
        final LoopRoute loop = edge.route as LoopRoute;
        final String? label = edge.label;
        final Size expected = label == null
            ? Size.zero
            : measureEdgeLabel(label);

        expect(loop.labelArea.width, closeTo(expected.width, _sizeTolerance));
        expect(
          loop.labelArea.height,
          closeTo(expected.height, _sizeTolerance),
        );
      }
    }
  });

  test('test_route_loop_property_label_never_covers_a_step', () {
    final Random random = seededRandom(119502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      final List<Rect> boxes = _listStepBoxes(workflow);

      for (final DiagramEdge edge in _listLoopEdges(workflow)) {
        final Rect labelArea = (edge.route as LoopRoute).labelArea;
        for (final Rect box in boxes) {
          expect(_overlapsInside(labelArea, box), isFalse);
        }
      }
    }
  });

  test('test_route_loop_property_laid_out_loops_cross_no_step', () {
    final Random random = seededRandom(119503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomLaidOutWorkflow(random);
      final List<Rect> boxes = _listStepBoxes(workflow);

      for (final DiagramEdge edge in _listLoopEdges(workflow)) {
        for (final Rect box in boxes) {
          expect(doesRouteEnterBox(edge.route, box), isFalse);
        }
      }
    }
  });

  test('test_route_loop_property_never_crosses_its_own_steps', () {
    final Random random = seededRandom(119504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);

      for (final DiagramEdge edge in _listLoopEdges(workflow)) {
        final Rect source = findAgentRect(workflow, edge.connection.from);
        final Rect target = findAgentRect(workflow, edge.connection.to);
        if (_overlapsInside(source, target)) {
          continue;
        }

        expect(doesRouteEnterBox(edge.route, source), isFalse);
        expect(doesRouteEnterBox(edge.route, target), isFalse);
      }
    }
  });

  test(
    'test_route_loop_property_neighbours_a_column_gap_apart_stay_clear',
    () {
      final Random random = seededRandom(119505);

      for (int i = 0; i < propertyIterations; i += 1) {
        final Workflow workflow = randomValidWorkflow(random);
        if (workflow.agents.length < 2) {
          continue;
        }
        final WorkflowAgent target = workflow.agents.first;
        final double side = random.nextBool() ? 1 : -1;
        final Offset nearby = Offset(
          side *
              (CanvasMetrics.nodeWidth +
                  _columnGap +
                  random.nextDouble() * _extraGap),
          (random.nextDouble() * 2 - 1) * CanvasMetrics.nodeHeight,
        );
        final WorkflowAgent source = workflow.agents.last.copyWith(
          position: CanvasPosition(
            horizontal: target.position.horizontal + nearby.dx,
            vertical: target.position.vertical + nearby.dy,
          ),
        );
        final AgentConnection loop = AgentConnection(
          from: source.id,
          to: target.id,
          condition: 'changes',
          roundLimit: 1,
        );

        final EdgeRoute route = describeDiagramEdges(
          agents: <WorkflowAgent>[target, source],
          connections: <AgentConnection>[loop],
          selected: null,
          drawnLoop: null,
        ).single.route;

        expect(
          doesRouteEnterBox(route, findNodeRect(source.position)),
          isFalse,
        );
        expect(
          doesRouteEnterBox(route, findNodeRect(target.position)),
          isFalse,
        );
      }
    },
  );
}
