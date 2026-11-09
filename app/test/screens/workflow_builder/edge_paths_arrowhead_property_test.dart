import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/random_canvas_points.dart';
import 'support/random_diagram_layouts.dart';

const double _curveReach = 2000;
const double _floatTolerance = 0.05;
const double _probeStep = 1;
const double _arrowHalfWidth = CanvasMetrics.arrowLength / 2;

List<EdgeRoute> _randomRoutes(Random random) {
  final Workflow workflow = randomLaidOutWorkflow(random);
  return <EdgeRoute>[
    for (final DiagramEdge edge in describeSavedEdges(workflow)) edge.route,
    randomDrawnCurve(random, reach: _curveReach),
  ];
}

Offset _findRouteEnd(EdgeRoute route) {
  switch (route) {
    case EdgeCurve():
      return route.end;
    case LoopRoute():
      return route.corners.last;
  }
}

Offset? _findFinalHeading(EdgeRoute route) {
  final List<PathMetric> metrics = buildEdgePath(route)
      .computeMetrics()
      .toList();
  if (metrics.isEmpty) {
    return null;
  }
  final PathMetric line = metrics.last;
  return line.getTangentForOffset(line.length)!.vector;
}

void main() {
  test('test_build_arrowhead_property_points_along_the_line_end', () {
    final Random random = seededRandom(119101);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final EdgeRoute route in _randomRoutes(random)) {
        final Offset? heading = _findFinalHeading(route);
        if (heading == null) {
          continue;
        }
        final Path arrowhead = buildArrowhead(route);
        final Offset tip = _findRouteEnd(route);

        expect(
          arrowhead.contains(tip - heading * _probeStep),
          isTrue,
          reason: 'heading $heading at $tip',
        );
        expect(arrowhead.contains(tip + heading * _probeStep), isFalse);
      }
    }
  });

  test('test_build_arrowhead_property_loops_point_left_into_target', () {
    final Random random = seededRandom(119102);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final EdgeRoute route in _randomRoutes(random)) {
        if (route is! LoopRoute) {
          continue;
        }
        final Path arrowhead = buildArrowhead(route);
        final Offset tip = route.corners.last;
        const Offset rightward = Offset(_probeStep, 0);

        expect(arrowhead.contains(tip + rightward), isTrue);
        expect(arrowhead.contains(tip - rightward), isFalse);
      }
    }
  });

  test('test_build_arrowhead_property_is_finite_for_every_route', () {
    final Random random = seededRandom(119103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<EdgeRoute> routes = <EdgeRoute>[
        for (final DiagramEdge edge in describeSavedEdges(
          randomDiagramWorkflow(random),
        ))
          edge.route,
        randomDrawnCurve(random, reach: _curveReach),
      ];

      for (final EdgeRoute route in routes) {
        expect(buildArrowhead(route).getBounds().isFinite, isTrue);
      }
    }
  });

  test('test_build_arrowhead_at_property_is_an_arrow_sized_triangle', () {
    final Random random = seededRandom(119104);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final EdgeRoute route in _randomRoutes(random)) {
        final Rect bounds = buildArrowhead(route).getBounds();
        final double longSide = max(bounds.width, bounds.height);
        final double shortSide = min(bounds.width, bounds.height);

        expect(longSide, closeTo(CanvasMetrics.arrowLength, _floatTolerance));
        expect(shortSide, closeTo(2 * _arrowHalfWidth, _floatTolerance));
      }
    }
  });

  test('test_build_arrowhead_at_property_base_sits_one_arrow_behind', () {
    final Random random = seededRandom(119105);

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final EdgeRoute route in _randomRoutes(random)) {
        final Offset? heading = _findFinalHeading(route);
        if (heading == null) {
          continue;
        }
        final Path arrowhead = buildArrowhead(route);
        final Offset tip = _findRouteEnd(route);
        final Offset baseMiddle = tip - heading * CanvasMetrics.arrowLength;

        expect(arrowhead.contains(baseMiddle + heading * _probeStep), isTrue);
        expect(arrowhead.contains(baseMiddle - heading * _probeStep), isFalse);
      }
    }
  });

  test('test_build_arrowhead_at_property_is_one_closed_outline', () {
    final Random random = seededRandom(119106);
    final double side = sqrt(
      CanvasMetrics.arrowLength * CanvasMetrics.arrowLength +
          _arrowHalfWidth * _arrowHalfWidth,
    );
    final double perimeter = 2 * side + 2 * _arrowHalfWidth;

    for (int i = 0; i < propertyIterations; i += 1) {
      for (final EdgeRoute route in _randomRoutes(random)) {
        final List<PathMetric> outlines = buildArrowhead(route)
            .computeMetrics()
            .toList();

        expect(outlines.length, 1);
        expect(outlines.single.isClosed, isTrue);
        expect(outlines.single.length, closeTo(perimeter, _floatTolerance));
      }
    }
  });

  test('test_find_curve_heading_property_level_drawing_points_across', () {
    final Random random = seededRandom(119107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset port = randomCanvasPoint(random, reach: _curveReach);
      final double across = randomSignedCoordinate(random, reach: _curveReach);
      if (across.abs() < CanvasMetrics.arrowLength) {
        continue;
      }
      final Offset pointer = port.translate(across, 0);
      final Offset towardPointer = Offset(across.sign, 0);

      final Path arrowhead = buildArrowhead(
        connectPoints(start: port, end: pointer),
      );

      expect(arrowhead.contains(pointer - towardPointer), isTrue);
      expect(arrowhead.contains(pointer.translate(0, -_probeStep)), isFalse);
    }
  });

  test('test_find_curve_heading_property_follows_any_cubic_end', () {
    final Random random = seededRandom(119108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = EdgeCurve(
        start: randomCanvasPoint(random, reach: _curveReach),
        controlStart: randomCanvasPoint(random, reach: _curveReach),
        controlEnd: randomCanvasPoint(random, reach: _curveReach),
        end: randomCanvasPoint(random, reach: _curveReach),
      );
      final Offset heading = _findFinalHeading(curve)!;

      final Path arrowhead = buildArrowhead(curve);

      expect(arrowhead.contains(curve.end - heading * _probeStep), isTrue);
      expect(arrowhead.contains(curve.end + heading * _probeStep), isFalse);
    }
  });

  test('test_find_curve_heading_property_a_dot_points_down', () {
    final Random random = seededRandom(119109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset dot = randomCanvasPoint(random, reach: _curveReach);
      const Offset downward = Offset(0, _probeStep);

      final Path arrowhead = buildArrowhead(
        connectPoints(start: dot, end: dot),
      );

      expect(arrowhead.contains(dot - downward), isTrue);
      expect(arrowhead.contains(dot + downward), isFalse);
      expect(arrowhead.getBounds().isFinite, isTrue);
    }
  });
}
