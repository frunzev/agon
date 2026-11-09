import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/edge_distance_model.dart';
import 'support/random_canvas_points.dart';
import 'support/random_diagram_layouts.dart';

const double _modelBand = 0.5;
const double _farMargin = 1;

double _measureNearestReference(List<DiagramEdge> edges, Offset point) {
  double nearest = double.infinity;
  for (final DiagramEdge edge in edges) {
    final double distance = measureReferenceDistanceToRoute(edge.route, point);
    nearest = min(nearest, distance);
  }
  return nearest;
}

Offset _randomPointNearEdges(Random random, List<DiagramEdge> edges) {
  final Offset onEdge = pickPointOnRoute(random, pickOne(random, edges).route);
  final Offset nudge = randomCanvasPoint(random, reach: 2 * edgeHitDistance);
  return onEdge + nudge;
}

void main() {
  test('test_find_edge_hit_property_points_on_any_edge_hit_an_edge', () {
    final Random random = seededRandom(118101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      final List<DiagramEdge> edges = describeSavedEdges(workflow);
      if (edges.isEmpty) {
        continue;
      }

      for (final DiagramEdge edge in edges) {
        final Offset point = pickPointOnRoute(random, edge.route);
        final DiagramEdge? hit = findEdgeHit(edges, point);

        expect(hit, isNotNull, reason: 'point $point on ${edge.connection}');
        expect(
          measureReferenceDistanceToRoute(hit!.route, point),
          lessThanOrEqualTo(edgeHitDistance + _modelBand),
        );
      }
    }
  });

  test('test_find_edge_hit_property_agrees_with_a_dense_reference', () {
    final Random random = seededRandom(118102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Workflow workflow = randomDiagramWorkflow(random);
      final List<DiagramEdge> edges = describeSavedEdges(workflow);
      if (edges.isEmpty) {
        continue;
      }
      final Offset point = _randomPointNearEdges(random, edges);
      final double nearest = _measureNearestReference(edges, point);
      if ((nearest - edgeHitDistance).abs() < _modelBand) {
        continue;
      }

      final DiagramEdge? hit = findEdgeHit(edges, point);

      expect(hit != null, nearest < edgeHitDistance, reason: 'at $point');
      if (hit != null) {
        expect(
          measureReferenceDistanceToRoute(hit.route, point),
          lessThanOrEqualTo(nearest + _modelBand),
        );
      }
    }
  });

  test('test_find_edge_hit_property_edge_order_never_changes_the_reach', () {
    final Random random = seededRandom(118103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<DiagramEdge> edges = describeSavedEdges(
        randomDiagramWorkflow(random),
      );
      if (edges.isEmpty) {
        continue;
      }
      final List<DiagramEdge> shuffled = List<DiagramEdge>.of(edges);
      shuffled.shuffle(random);
      final Offset point = _randomPointNearEdges(random, edges);

      final DiagramEdge? hit = findEdgeHit(edges, point);
      final DiagramEdge? shuffledHit = findEdgeHit(shuffled, point);

      expect(shuffledHit != null, hit != null);
      if (hit != null && shuffledHit != null) {
        expect(
          measureReferenceDistanceToRoute(shuffledHit.route, point),
          closeTo(
            measureReferenceDistanceToRoute(hit.route, point),
            _modelBand,
          ),
        );
      }
    }
  });

  test('test_find_edge_hit_property_points_beyond_every_route_miss', () {
    final Random random = seededRandom(118104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<DiagramEdge> edges = describeSavedEdges(
        randomDiagramWorkflow(random),
      );
      final Offset point = randomCanvasPoint(
        random,
        reach: 2 * farCanvasReach,
      );
      final bool isNearARoute = edges.any(
        (DiagramEdge edge) =>
            findRouteBounds(edge.route)
                .inflate(edgeHitDistance + _farMargin)
                .contains(point),
      );
      if (isNearARoute) {
        continue;
      }

      expect(findEdgeHit(edges, point), isNull);
      expect(findEdgeHit(const <DiagramEdge>[], point), isNull);
    }
  });
}
