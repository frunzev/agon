import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/random_canvas_points.dart';

const int _largestCornerCount = 6;

EdgeCurve _randomCurve(Random random) {
  return EdgeCurve(
    start: randomCanvasPoint(random, reach: hugeCanvasReach),
    controlStart: randomCanvasPoint(random, reach: hugeCanvasReach),
    controlEnd: randomCanvasPoint(random, reach: hugeCanvasReach),
    end: randomCanvasPoint(random, reach: hugeCanvasReach),
  );
}

LoopRoute _randomLoopRoute(Random random) {
  final int cornerCount = random.nextInt(_largestCornerCount + 1);
  return LoopRoute(
    corners: <Offset>[
      for (int index = 0; index < cornerCount; index += 1)
        randomCanvasPoint(random, reach: ordinaryCanvasReach),
    ],
    labelArea: Rect.fromPoints(
      randomCanvasPoint(random, reach: ordinaryCanvasReach),
      randomCanvasPoint(random, reach: ordinaryCanvasReach),
    ),
  );
}

void main() {
  test(
    'test_edge_route_constructor_property_every_route_is_an_edge_route',
    () {
      final Random random = seededRandom(117401);

      for (int i = 0; i < propertyIterations; i += 1) {
        final EdgeRoute route = random.nextBool()
            ? _randomCurve(random)
            : _randomLoopRoute(random);

        final bool isKnownKind = route is EdgeCurve || route is LoopRoute;

        expect(isKnownKind, isTrue);
      }
    },
  );

  test('test_edge_route_constructor_property_kinds_never_mix', () {
    final Random random = seededRandom(117402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeRoute curve = _randomCurve(random);
      final EdgeRoute loop = _randomLoopRoute(random);

      expect(curve is LoopRoute, isFalse);
      expect(loop is EdgeCurve, isFalse);
    }
  });

  test('test_edge_route_constructor_property_const_routes_are_shared', () {
    const EdgeRoute first = EdgeCurve(
      start: Offset.zero,
      controlStart: Offset.zero,
      controlEnd: Offset.zero,
      end: Offset.zero,
    );
    const EdgeRoute second = EdgeCurve(
      start: Offset.zero,
      controlStart: Offset.zero,
      controlEnd: Offset.zero,
      end: Offset.zero,
    );

    expect(identical(first, second), isTrue);
  });

  test('test_edge_curve_constructor_property_keeps_every_point', () {
    final Random random = seededRandom(117403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset start = randomCanvasPoint(random, reach: hugeCanvasReach);
      final Offset controlStart = randomCanvasPoint(
        random,
        reach: hugeCanvasReach,
      );
      final Offset controlEnd = randomCanvasPoint(
        random,
        reach: hugeCanvasReach,
      );
      final Offset end = randomCanvasPoint(random, reach: hugeCanvasReach);

      final EdgeCurve curve = EdgeCurve(
        start: start,
        controlStart: controlStart,
        controlEnd: controlEnd,
        end: end,
      );

      expect(curve.start, start);
      expect(curve.controlStart, controlStart);
      expect(curve.controlEnd, controlEnd);
      expect(curve.end, end);
    }
  });

  test('test_edge_curve_constructor_property_fields_are_independent', () {
    final Random random = seededRandom(117404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = _randomCurve(random);
      final Offset newEnd = randomCanvasPoint(random, reach: hugeCanvasReach);

      final EdgeCurve changed = EdgeCurve(
        start: curve.start,
        controlStart: curve.controlStart,
        controlEnd: curve.controlEnd,
        end: newEnd,
      );

      expect(changed.start, curve.start);
      expect(changed.controlStart, curve.controlStart);
      expect(changed.controlEnd, curve.controlEnd);
      expect(changed.end, newEnd);
    }
  });

  test('test_edge_curve_constructor_property_huge_points_stay_finite', () {
    final Random random = seededRandom(117405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeCurve curve = _randomCurve(random);

      expect(curve.start.isFinite && curve.end.isFinite, isTrue);
      expect(curve.controlStart.isFinite && curve.controlEnd.isFinite, isTrue);
    }
  });

  test('test_loop_route_constructor_property_keeps_corners_and_label', () {
    final Random random = seededRandom(117406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopRoute source = _randomLoopRoute(random);

      final LoopRoute route = LoopRoute(
        corners: source.corners,
        labelArea: source.labelArea,
      );

      expect(route.corners, source.corners);
      expect(route.labelArea, source.labelArea);
    }
  });

  test('test_loop_route_constructor_property_corner_order_is_kept', () {
    final Random random = seededRandom(117407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Offset> corners = _randomLoopRoute(random).corners;

      final LoopRoute route = LoopRoute(
        corners: corners.reversed.toList(),
        labelArea: Rect.zero,
      );

      expect(route.corners, corners.reversed.toList());
      expect(route.corners.length, corners.length);
    }
  });

  test('test_loop_route_constructor_property_is_an_edge_route', () {
    final Random random = seededRandom(117408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final EdgeRoute route = _randomLoopRoute(random);

      expect(route, isA<LoopRoute>());
      expect(route, isNot(isA<EdgeCurve>()));
    }
  });
}
