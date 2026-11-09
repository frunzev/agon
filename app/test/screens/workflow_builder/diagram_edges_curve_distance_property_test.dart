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

const double _longCurveReach = 1e4;
const double _modelCurveReach = 3000;
const double _hugeShiftReach = 1e6;
const double _modelBand = 1;
const AgentConnection _someConnection = AgentConnection(
  from: WorkflowAgentId('curve-source'),
  to: WorkflowAgentId('curve-target'),
  condition: null,
  roundLimit: null,
);

DiagramEdge _edgeAlong(EdgeRoute route) {
  return DiagramEdge(
    connection: _someConnection,
    route: route,
    label: null,
    line: EdgeLine.solid,
    look: EdgeLook.normal,
  );
}

bool _isHit(EdgeRoute route, Offset point) {
  return findEdgeHit(<DiagramEdge>[_edgeAlong(route)], point) != null;
}

EdgeCurve _shiftCurve(EdgeCurve curve, Offset shift) {
  return EdgeCurve(
    start: curve.start + shift,
    controlStart: curve.controlStart + shift,
    controlEnd: curve.controlEnd + shift,
    end: curve.end + shift,
  );
}

LoopRoute _randomLoopRoute(Random random) {
  while (true) {
    final List<DiagramEdge> edges = describeSavedEdges(
      randomDiagramWorkflow(random),
    );
    for (final DiagramEdge edge in edges) {
      final EdgeRoute route = edge.route;
      if (route is LoopRoute) {
        return route;
      }
    }
  }
}

void main() {
  test('test_measure_distance_to_curve_property_long_curves_hit_anywhere', () {
    final Random random = seededRandom(118201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = randomDrawnCurve(random, reach: _longCurveReach);
      final Offset point = findCurvePoint(curve, random.nextDouble());

      expect(_isHit(curve, point), isTrue, reason: 'at $point');
    }
  });

  test('test_measure_distance_to_curve_property_matches_a_dense_model', () {
    final Random random = seededRandom(118202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = randomDrawnCurve(
        random,
        reach: _modelCurveReach,
      );
      final Offset point =
          findCurvePoint(curve, random.nextDouble()) +
          randomCanvasPoint(random, reach: 2 * edgeHitDistance);
      final double distance = measureReferenceDistanceToRoute(curve, point);
      if ((distance - edgeHitDistance).abs() < _modelBand) {
        continue;
      }

      expect(_isHit(curve, point), distance < edgeHitDistance);
    }
  });

  test('test_measure_distance_to_curve_property_moves_with_the_curve', () {
    final Random random = seededRandom(118203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = randomDrawnCurve(
        random,
        reach: _modelCurveReach,
      );
      final Offset shift = randomCanvasPoint(random, reach: _hugeShiftReach);
      final Offset point =
          findCurvePoint(curve, random.nextDouble()) +
          randomCanvasPoint(random, reach: 2 * edgeHitDistance);
      final double distance = measureReferenceDistanceToRoute(curve, point);
      if ((distance - edgeHitDistance).abs() < _modelBand) {
        continue;
      }

      expect(
        _isHit(_shiftCurve(curve, shift), point + shift),
        _isHit(curve, point),
      );
    }
  });

  test('test_measure_distance_to_route_property_loops_use_their_corners', () {
    final Random random = seededRandom(118204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopRoute loop = _randomLoopRoute(random);
      final EdgeCurve straight = connectPoints(
        start: loop.corners.first,
        end: loop.corners.last,
      );
      final Offset outerMiddle = loop.labelArea.center;

      expect(_isHit(loop, outerMiddle), isTrue);
      expect(
        _isHit(straight, outerMiddle),
        measureReferenceDistanceToRoute(straight, outerMiddle) <=
            edgeHitDistance,
      );
    }
  });

  test('test_measure_distance_to_route_property_curves_use_the_curve', () {
    final Random random = seededRandom(118205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = randomDrawnCurve(
        random,
        reach: _modelCurveReach,
      );
      final LoopRoute corners = LoopRoute(
        corners: <Offset>[curve.start, curve.end],
        labelArea: Rect.zero,
      );
      final Offset middle = findCurvePoint(curve, random.nextDouble());

      expect(_isHit(curve, middle), isTrue);
      expect(
        _isHit(corners, middle),
        measureReferenceDistanceToRoute(corners, middle) <= edgeHitDistance,
      );
    }
  });

  test('test_measure_distance_to_route_property_picks_the_shape_hit', () {
    final Random random = seededRandom(118206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopRoute loop = _randomLoopRoute(random);
      final EdgeCurve curve = randomDrawnCurve(
        random,
        reach: _modelCurveReach,
      );
      final DiagramEdge loopEdge = _edgeAlong(loop);
      final DiagramEdge curveEdge = _edgeAlong(curve);
      final bool picksLoop = random.nextBool();
      final EdgeRoute picked = picksLoop ? loop : curve;
      final EdgeRoute other = picksLoop ? curve : loop;
      final Offset point = pickPointOnRoute(random, picked);
      if (measureReferenceDistanceToRoute(other, point) <=
          edgeHitDistance + _modelBand) {
        continue;
      }

      final DiagramEdge? hit = findEdgeHit(<DiagramEdge>[
        loopEdge,
        curveEdge,
      ], point);

      expect(hit?.route, same(picked));
    }
  });
}
