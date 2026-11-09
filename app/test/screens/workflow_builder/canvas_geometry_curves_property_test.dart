import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/random_canvas_points.dart';

const double _ordinaryMagnitude = ordinaryCanvasReach * 4;

EdgeCurve _shiftCurve(EdgeCurve curve, Offset delta) {
  return EdgeCurve(
    start: curve.start + delta,
    controlStart: curve.controlStart + delta,
    controlEnd: curve.controlEnd + delta,
    end: curve.end + delta,
  );
}

void _expectSameCurve(EdgeCurve actual, EdgeCurve expected) {
  expectNearlySamePoint(actual.start, expected.start, magnitude: 0);
  expectNearlySamePoint(
    actual.controlStart,
    expected.controlStart,
    magnitude: _ordinaryMagnitude,
  );
  expectNearlySamePoint(
    actual.controlEnd,
    expected.controlEnd,
    magnitude: _ordinaryMagnitude,
  );
  expectNearlySamePoint(actual.end, expected.end, magnitude: 0);
}

void main() {
  test('test_connect_points_property_keeps_ends_and_meets_in_the_middle', () {
    final Random random = seededRandom(117409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset start = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );
      final Offset end = randomCanvasPoint(random, reach: ordinaryCanvasReach);
      final double middle = (start.dy + end.dy) / 2;

      final EdgeCurve curve = connectPoints(start: start, end: end);

      expect(curve.start, start);
      expect(curve.end, end);
      expect(curve.controlStart, Offset(start.dx, middle));
      expect(curve.controlEnd, Offset(end.dx, middle));
    }
  });

  test('test_connect_points_property_swapping_ends_mirrors_the_curve', () {
    final Random random = seededRandom(117410);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset first = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );
      final Offset second = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );

      final EdgeCurve forward = connectPoints(start: first, end: second);
      final EdgeCurve backward = connectPoints(start: second, end: first);

      expect(backward.start, forward.end);
      expect(backward.end, forward.start);
      expectNearlySamePoint(
        backward.controlStart,
        forward.controlEnd,
        magnitude: _ordinaryMagnitude,
      );
    }
  });

  test('test_connect_points_property_moving_both_ends_moves_the_curve', () {
    final Random random = seededRandom(117411);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset start = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );
      final Offset end = randomCanvasPoint(random, reach: ordinaryCanvasReach);
      final Offset delta = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );

      final EdgeCurve moved = connectPoints(
        start: start + delta,
        end: end + delta,
      );
      final EdgeCurve shifted = _shiftCurve(
        connectPoints(start: start, end: end),
        delta,
      );

      _expectSameCurve(moved, shifted);
    }
  });

  test('test_build_edge_curve_property_moving_both_steps_moves_it', () {
    final Random random = seededRandom(117415);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition from = randomPlacedPosition(
        random,
        reach: ordinaryCanvasReach,
      );
      final CanvasPosition to = randomPlacedPosition(
        random,
        reach: ordinaryCanvasReach,
      );
      final Offset delta = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );

      final EdgeCurve moved = buildEdgeCurve(
        from: CanvasPosition(
          horizontal: from.horizontal + delta.dx,
          vertical: from.vertical + delta.dy,
        ),
        to: CanvasPosition(
          horizontal: to.horizontal + delta.dx,
          vertical: to.vertical + delta.dy,
        ),
      );

      _expectSameCurve(
        moved,
        _shiftCurve(buildEdgeCurve(from: from, to: to), delta),
      );
    }
  });

  test('test_build_edge_curve_property_ends_stay_outside_both_steps', () {
    final Random random = seededRandom(117417);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition from = randomPlacedPosition(
        random,
        reach: hugeCanvasReach,
      );
      final CanvasPosition to = randomPlacedPosition(
        random,
        reach: hugeCanvasReach,
      );

      final EdgeCurve curve = buildEdgeCurve(from: from, to: to);

      expect(curve.start.dy, greaterThan(findNodeRect(from).bottom));
      expect(curve.end.dy, lessThan(findNodeRect(to).top));
      expect(curve.start.isFinite && curve.end.isFinite, isTrue);
    }
  });
}
