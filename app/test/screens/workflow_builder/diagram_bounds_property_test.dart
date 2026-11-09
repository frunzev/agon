import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/rules/connection_rules.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';
import 'support/random_canvas_points.dart';
import 'support/random_connection_scenes.dart';

const double _tolerance = 1e-6;

String _randomLongOutcome(Random random, int index) {
  final String prefix = 'o$index-';
  final int letterCount = random.nextInt(maximumOutcomeLength - prefix.length);
  return '$prefix${randomOutcomeOfLength(random, letterCount)}';
}

Workflow _withLongOutcomes(Random random, Workflow workflow) {
  final List<AgentConnection> connections = <AgentConnection>[];
  for (int index = 0; index < workflow.connections.length; index += 1) {
    final AgentConnection connection = workflow.connections[index];
    final bool keepsOutcome = connection.isLoop || random.nextBool();
    connections.add(
      keepsOutcome
          ? connection
          : connection.withCondition(_randomLongOutcome(random, index)),
    );
  }
  return workflow.withGraph(agents: workflow.agents, connections: connections);
}

Workflow _withoutForwardOutcomes(Workflow workflow) {
  return workflow.withGraph(
    agents: workflow.agents,
    connections: <AgentConnection>[
      for (final AgentConnection connection in workflow.connections)
        if (connection.isLoop) connection else connection.withCondition(null),
    ],
  );
}

List<CanvasPosition> _positionsOf(Workflow workflow) {
  return <CanvasPosition>[
    for (final WorkflowAgent agent in workflow.agents) agent.position,
  ];
}

List<DiagramEdge> _edgesOf(Workflow workflow) {
  return describeDiagramEdges(
    agents: workflow.agents,
    connections: workflow.connections,
    selected: null,
    drawnLoop: null,
  );
}

void main() {
  test('test_include_curve_label_property_every_drawn_label_is_inside', () {
    final Random random = seededRandom(117601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _withLongOutcomes(
        random,
        randomBranchingWorkflow(random),
      );
      final List<DiagramEdge> edges = _edgesOf(workflow);

      final Rect bounds = findDiagramBounds(
        positions: _positionsOf(workflow),
        edges: edges,
      );

      final Rect allowed = bounds.inflate(_tolerance);
      for (final DiagramEdge edge in edges) {
        final String? label = edge.label;
        if (label == null) {
          continue;
        }
        final Size labelSize = measureEdgeLabel(label);
        final Rect labelArea = Rect.fromCenter(
          center: findLabelCentre(edge.route),
          width: labelSize.width,
          height: labelSize.height,
        );
        expect(allowed.expandToInclude(labelArea), allowed, reason: label);
      }
    }
  });

  test('test_find_diagram_bounds_property_empty_or_one_step_is_exact', () {
    final Random random = seededRandom(117602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = randomPlacedPosition(
        random,
        reach: hugeCanvasReach,
      );

      final Rect empty = findDiagramBounds(
        positions: const <CanvasPosition>[],
        edges: const <DiagramEdge>[],
      );
      final Rect lone = findDiagramBounds(
        positions: <CanvasPosition>[position],
        edges: const <DiagramEdge>[],
      );

      expect(empty, Rect.zero);
      expect(lone, findNodeRect(position));
      expect(lone.isFinite, isTrue);
    }
  });

  test('test_find_diagram_bounds_property_order_does_not_matter', () {
    final Random random = seededRandom(117603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = _withLongOutcomes(
        random,
        randomBranchingWorkflow(random),
      );
      final List<CanvasPosition> positions = _positionsOf(workflow);
      final List<DiagramEdge> edges = _edgesOf(workflow);
      final List<CanvasPosition> shuffledPositions = List<CanvasPosition>.of(
        positions,
      );
      final List<DiagramEdge> shuffledEdges = List<DiagramEdge>.of(edges);
      shuffledPositions.shuffle(random);
      shuffledEdges.shuffle(random);

      final Rect bounds = findDiagramBounds(
        positions: positions,
        edges: edges,
      );
      final Rect shuffled = findDiagramBounds(
        positions: shuffledPositions,
        edges: shuffledEdges,
      );

      expect(shuffled, bounds);
    }
  });

  test('test_include_curve_label_property_unlabelled_steps_add_nothing', () {
    final Random random = seededRandom(117604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow acyclic = randomBranchingWorkflow(random);
      final Workflow unlabelled = acyclic.withGraph(
        agents: acyclic.agents,
        connections: <AgentConnection>[
          for (final AgentConnection connection in acyclic.connections)
            if (!connection.isLoop) connection.withCondition(null),
        ],
      );

      final Rect bounds = findDiagramBounds(
        positions: _positionsOf(unlabelled),
        edges: _edgesOf(unlabelled),
      );

      expect(bounds, findNodesBounds(_positionsOf(unlabelled)));
    }
  });

  test('test_include_curve_label_property_labels_only_grow_bounds', () {
    final Random random = seededRandom(117605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow labelled = _withLongOutcomes(
        random,
        randomBranchingWorkflow(random),
      );
      final Workflow unlabelled = _withoutForwardOutcomes(labelled);

      final Rect withLabels = findDiagramBounds(
        positions: _positionsOf(labelled),
        edges: _edgesOf(labelled),
      );
      final Rect withoutLabels = findDiagramBounds(
        positions: _positionsOf(unlabelled),
        edges: _edgesOf(unlabelled),
      );

      expect(withLabels.expandToInclude(withoutLabels), withLabels);
    }
  });
}
