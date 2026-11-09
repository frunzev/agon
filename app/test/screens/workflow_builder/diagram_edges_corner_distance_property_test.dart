import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/edge_distance_model.dart';
import 'support/random_canvas_points.dart';
import 'support/random_diagram_layouts.dart';

const double _segmentReach = 2000;
const double _modelBand = 0.01;
const AgentConnection _someLoop = AgentConnection(
  from: WorkflowAgentId('loop-source'),
  to: WorkflowAgentId('loop-target'),
  condition: 'changes',
  roundLimit: 2,
);

bool _isHit(List<Offset> corners, Offset point) {
  final DiagramEdge edge = DiagramEdge(
    connection: _someLoop,
    route: LoopRoute(corners: corners, labelArea: Rect.zero),
    label: null,
    line: EdgeLine.dashed,
    look: EdgeLook.normal,
  );
  return findEdgeHit(<DiagramEdge>[edge], point) != null;
}

List<List<Offset>> _listLoopCorners(Random random) {
  final List<List<Offset>> loops = <List<Offset>>[];
  for (final DiagramEdge edge in describeSavedEdges(
    randomDiagramWorkflow(random),
  )) {
    final EdgeRoute route = edge.route;
    if (route is LoopRoute) {
      loops.add(route.corners);
    }
  }
  return loops;
}

Offset _randomNearPoint(Random random, List<Offset> corners) {
  final LoopRoute route = LoopRoute(corners: corners, labelArea: Rect.zero);
  final Offset onRoute = pickPointOnRoute(random, route);
  return onRoute + randomCanvasPoint(random, reach: 2 * edgeHitDistance);
}

bool _isNearTheModelEdge(double distance) {
  return (distance - edgeHitDistance).abs() < _modelBand;
}

void main() {
  test('test_measure_distance_to_corners_property_every_segment_hits', () {
    final Random random = seededRandom(118301);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final List<Offset> corners in _listLoopCorners(random)) {
        final LoopRoute route = LoopRoute(
          corners: corners,
          labelArea: Rect.zero,
        );

        expect(_isHit(corners, pickPointOnRoute(random, route)), isTrue);
        expect(_isHit(corners, pickOne(random, corners)), isTrue);
      }
    }
  });

  test('test_measure_distance_to_corners_property_matches_the_model', () {
    final Random random = seededRandom(118302);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final List<Offset> corners in _listLoopCorners(random)) {
        final Offset point = _randomNearPoint(random, corners);
        final double distance = measureReferenceDistanceToPoints(
          corners,
          point,
        );
        if (_isNearTheModelEdge(distance)) {
          continue;
        }

        expect(_isHit(corners, point), distance < edgeHitDistance);
      }
    }
  });

  test('test_measure_distance_to_corners_property_ignores_direction', () {
    final Random random = seededRandom(118303);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final List<Offset> corners in _listLoopCorners(random)) {
        final Offset point = _randomNearPoint(random, corners);
        final List<Offset> reversed = corners.reversed.toList();

        expect(_isHit(reversed, point), _isHit(corners, point));
      }
    }
  });

  test('test_measure_distance_to_segment_property_any_direction_model', () {
    final Random random = seededRandom(118304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Offset> segment = <Offset>[
        randomCanvasPoint(random, reach: _segmentReach),
        randomCanvasPoint(random, reach: _segmentReach),
      ];
      final Offset point = _randomNearPoint(random, segment);
      final double distance = measureReferenceDistanceToPoints(segment, point);
      if (_isNearTheModelEdge(distance)) {
        continue;
      }

      expect(_isHit(segment, point), distance < edgeHitDistance);
    }
  });

  test('test_measure_distance_to_segment_property_a_dot_measures_to_it', () {
    final Random random = seededRandom(118305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset dot = randomCanvasPoint(random, reach: farCanvasReach);
      final Offset point =
          dot + randomCanvasPoint(random, reach: 2 * edgeHitDistance);
      final double distance = (point - dot).distance;
      if (_isNearTheModelEdge(distance)) {
        continue;
      }

      expect(_isHit(<Offset>[dot, dot], point), distance < edgeHitDistance);
    }
  });

  test('test_measure_distance_to_segment_property_past_ends_use_the_end', () {
    final Random random = seededRandom(118306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset start = randomCanvasPoint(random, reach: _segmentReach);
      final Offset end = randomCanvasPoint(random, reach: _segmentReach);
      final Offset direction = end - start;
      if (direction.distance == 0) {
        continue;
      }
      final double beyond = random.nextDouble() * 2 * edgeHitDistance;
      final Offset pastEnd = end + direction / direction.distance * beyond;
      if (_isNearTheModelEdge(beyond)) {
        continue;
      }

      expect(_isHit(<Offset>[start, end], pastEnd), beyond < edgeHitDistance);
    }
  });
}
