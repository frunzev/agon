import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/edge_distance_model.dart';
import 'support/random_canvas_points.dart';
import 'support/random_diagram_layouts.dart';

const double _curveReach = 2000;
const double _floatTolerance = 0.05;
const int _pathSampleCount = 64;

List<EdgeRoute> _randomRoutes(Random random) {
  return <EdgeRoute>[
    for (final DiagramEdge edge in describeSavedEdges(
      randomDiagramWorkflow(random),
    ))
      edge.route,
    randomDrawnCurve(random, reach: _curveReach),
  ];
}

List<Offset> _samplePath(Path path) {
  final List<Offset> samples = <Offset>[];
  for (final PathMetric metric in path.computeMetrics()) {
    for (int sample = 0; sample <= _pathSampleCount; sample += 1) {
      final double offset = metric.length * sample / _pathSampleCount;
      samples.add(metric.getTangentForOffset(offset)!.position);
    }
  }
  return samples;
}

double _measurePathLength(Path path) {
  double length = 0;
  for (final PathMetric metric in path.computeMetrics()) {
    length += metric.length;
  }
  return length;
}

EdgeRoute _shiftRoute(EdgeRoute route, Offset shift) {
  switch (route) {
    case EdgeCurve():
      return EdgeCurve(
        start: route.start + shift,
        controlStart: route.controlStart + shift,
        controlEnd: route.controlEnd + shift,
        end: route.end + shift,
      );
    case LoopRoute():
      return LoopRoute(
        corners: <Offset>[
          for (final Offset corner in route.corners) corner + shift,
        ],
        labelArea: route.labelArea.shift(shift),
      );
  }
}

void main() {
  test('test_build_edge_path_property_bounds_are_finite_everywhere', () {
    final Random random = seededRandom(118901);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final EdgeRoute route in _randomRoutes(random)) {
        final Path path = buildEdgePath(route);

        expect(path.getBounds().isFinite, isTrue);
        expect(_measurePathLength(path).isFinite, isTrue);
      }
    }
  });

  test('test_build_edge_path_property_moves_with_the_route', () {
    final Random random = seededRandom(118902);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final EdgeRoute route in _randomRoutes(random)) {
        final Offset shift = Offset(
          random.nextInt(_curveReach.toInt()).toDouble(),
          random.nextInt(_curveReach.toInt()).toDouble(),
        );
        final Rect bounds = buildEdgePath(route).getBounds();
        final Rect shifted = buildEdgePath(_shiftRoute(route, shift))
            .getBounds();

        expect(shifted.left, closeTo(bounds.left + shift.dx, _floatTolerance));
        expect(shifted.top, closeTo(bounds.top + shift.dy, _floatTolerance));
        expect(shifted.width, closeTo(bounds.width, _floatTolerance));
        expect(shifted.height, closeTo(bounds.height, _floatTolerance));
      }
    }
  });

  test('test_build_curve_path_property_follows_find_curve_point', () {
    final Random random = seededRandom(118903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = randomDrawnCurve(random, reach: _curveReach);
      final List<Offset> reference = sampleCurveDensely(curve);

      for (final Offset point in _samplePath(buildEdgePath(curve))) {
        expect(
          measureReferenceDistanceToPoints(reference, point),
          lessThan(_floatTolerance),
        );
      }
    }
  });

  test('test_build_curve_path_property_length_is_between_chord_and_hull', () {
    final Random random = seededRandom(118904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = EdgeCurve(
        start: randomCanvasPoint(random, reach: _curveReach),
        controlStart: randomCanvasPoint(random, reach: _curveReach),
        controlEnd: randomCanvasPoint(random, reach: _curveReach),
        end: randomCanvasPoint(random, reach: _curveReach),
      );
      final double chord = (curve.end - curve.start).distance;
      final double hull =
          (curve.controlStart - curve.start).distance +
          (curve.controlEnd - curve.controlStart).distance +
          (curve.end - curve.controlEnd).distance;

      final double length = _measurePathLength(buildEdgePath(curve));

      expect(length, greaterThanOrEqualTo(chord - _floatTolerance));
      expect(length, lessThanOrEqualTo(hull + _floatTolerance));
    }
  });

  test('test_build_curve_path_property_is_one_open_line', () {
    final Random random = seededRandom(118905);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = randomDrawnCurve(random, reach: _curveReach);
      if (curve.start == curve.end) {
        continue;
      }

      final List<PathMetric> metrics = buildEdgePath(curve)
          .computeMetrics()
          .toList();

      expect(metrics.length, 1);
      expect(metrics.single.isClosed, isFalse);
    }
  });
}
