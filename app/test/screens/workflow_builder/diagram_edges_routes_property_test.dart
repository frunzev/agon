import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/random_diagram_layouts.dart';
import 'support/route_box_checks.dart';

const double _portReach = CanvasMetrics.portRadius + CanvasMetrics.arrowGap;
const double _clearRise = 2 * _portReach;

Workflow _dropOneTouchedAgent(Random random, Workflow workflow) {
  final AgentConnection touched = pickOne(random, workflow.connections);
  final WorkflowAgent dropped = workflow.findAgent(
    random.nextBool() ? touched.from : touched.to,
  );
  return workflow.withGraph(
    agents: <WorkflowAgent>[
      for (final WorkflowAgent agent in workflow.agents)
        if (agent.id != dropped.id) agent,
    ],
    connections: workflow.connections,
  );
}

Workflow _moveAllBut(
  Random random,
  Workflow workflow, {
  required Set<WorkflowAgentId> kept,
}) {
  final Workflow placed = placeRandomly(random, workflow);
  return workflow.withGraph(
    agents: <WorkflowAgent>[
      for (final WorkflowAgent agent in workflow.agents)
        if (kept.contains(agent.id)) agent else placed.findAgent(agent.id),
    ],
    connections: workflow.connections,
  );
}

void main() {
  test('test_describe_diagram_edges_property_curves_join_bottom_to_top', () {
    final Random random = seededRandom(118601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);

      for (final DiagramEdge edge in describeSavedEdges(workflow)) {
        final EdgeRoute route = edge.route;
        if (route is! EdgeCurve) {
          continue;
        }
        final Rect source = findAgentRect(workflow, edge.connection.from);
        final Rect target = findAgentRect(workflow, edge.connection.to);

        expect(
          (route.start - source.bottomCenter).distance,
          lessThanOrEqualTo(_portReach),
        );
        expect(
          (route.end - target.topCenter).distance,
          lessThanOrEqualTo(_portReach),
        );
        expect(route.start.dy, greaterThan(source.bottom));
        expect(route.end.dy, lessThan(target.top));
        expect(route.start.dx, source.center.dx);
        expect(route.end.dx, target.center.dx);
      }
    }
  });

  test('test_describe_diagram_edges_property_downward_curves_miss_ends', () {
    final Random random = seededRandom(118602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);

      for (final DiagramEdge edge in describeSavedEdges(workflow)) {
        final Rect source = findAgentRect(workflow, edge.connection.from);
        final Rect target = findAgentRect(workflow, edge.connection.to);
        final bool isTargetClearlyBelow =
            target.top - source.bottom > _clearRise;
        if (edge.route is! EdgeCurve || !isTargetClearlyBelow) {
          continue;
        }

        expect(doesRouteEnterBox(edge.route, source), isFalse);
        expect(doesRouteEnterBox(edge.route, target), isFalse);
      }
    }
  });

  test('test_describe_diagram_edges_property_loops_go_side_to_side', () {
    final Random random = seededRandom(118603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);

      for (final DiagramEdge edge in describeSavedEdges(workflow)) {
        final EdgeRoute route = edge.route;
        if (route is! LoopRoute) {
          continue;
        }
        final Rect source = findAgentRect(workflow, edge.connection.from);
        final Rect target = findAgentRect(workflow, edge.connection.to);
        final Offset first = route.corners.first;
        final Offset last = route.corners.last;

        expect(first.dx, source.right);
        expect(first.dy, inInclusiveRange(source.top, source.bottom));
        expect(last.dx - target.right, inInclusiveRange(0, _portReach));
        expect(last.dy, inInclusiveRange(target.top, target.bottom));
      }
    }
  });

  test('test_describe_diagram_edges_property_every_route_is_finite', () {
    final Random random = seededRandom(118604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      final List<WorkflowAgent> agents = workflow.agents;
      final AgentConnection? drawnLoop = agents.length < 2
          ? null
          : AgentConnection(
              from: agents.last.id,
              to: agents.first.id,
              condition: null,
              roundLimit: null,
            );

      final List<DiagramEdge> edges = describeDiagramEdges(
        agents: agents,
        connections: workflow.connections,
        selected: null,
        drawnLoop: drawnLoop,
      );

      for (final DiagramEdge edge in edges) {
        expect(isRouteFinite(edge.route), isTrue);
      }
    }
  });

  test('test_describe_diagram_edges_property_refuses_undrawn_agents', () {
    final Random random = seededRandom(118605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      if (workflow.connections.isEmpty) {
        continue;
      }
      final Workflow broken = _dropOneTouchedAgent(random, workflow);

      expect(() => describeSavedEdges(broken), throwsA(isA<StateError>()));
    }
  });

  test('test_describe_edge_property_dashed_lines_route_as_loops', () {
    final Random random = seededRandom(118606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      if (workflow.agents.length < 2) {
        continue;
      }
      final AgentConnection drawnLoop = AgentConnection(
        from: pickOne(random, workflow.agents).id,
        to: pickOne(random, workflow.agents).id,
        condition: null,
        roundLimit: null,
      );

      final List<DiagramEdge> edges = describeDiagramEdges(
        agents: workflow.agents,
        connections: workflow.connections,
        selected: null,
        drawnLoop: drawnLoop,
      );

      for (final DiagramEdge edge in edges) {
        expect(edge.route is LoopRoute, edge.line == EdgeLine.dashed);
      }
      expect(edges.last.line, EdgeLine.dashed);
    }
  });

  test('test_describe_edge_property_label_is_the_connection_label', () {
    final Random random = seededRandom(118607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);

      for (final DiagramEdge edge in describeSavedEdges(workflow)) {
        expect(edge.label, describeConnectionLabel(edge.connection));
      }
    }
  });

  test('test_describe_edge_property_curves_ignore_other_steps', () {
    final Random random = seededRandom(118608);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      if (workflow.connections.isEmpty) {
        continue;
      }
      final int index = random.nextInt(workflow.connections.length);
      final AgentConnection connection = workflow.connections[index];
      final Workflow moved = _moveAllBut(
        random,
        workflow,
        kept: <WorkflowAgentId>{connection.from, connection.to},
      );
      final EdgeRoute route = describeSavedEdges(workflow)[index].route;
      final EdgeRoute movedRoute = describeSavedEdges(moved)[index].route;
      if (route is! EdgeCurve || movedRoute is! EdgeCurve) {
        continue;
      }

      expect(movedRoute.start, route.start);
      expect(movedRoute.controlStart, route.controlStart);
      expect(movedRoute.controlEnd, route.controlEnd);
      expect(movedRoute.end, route.end);
    }
  });
}
