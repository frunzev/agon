import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/random_canvas_points.dart';

const double _documentedStartingScale = 1;
const Offset _documentedStartingMargin = Offset(24, 24);
const double _ordinaryMagnitude = ordinaryCanvasReach * 8;

void main() {
  test('test_canvas_view_constructor_property_keeps_scale_and_offset', () {
    final Random random = seededRandom(117201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double scale = randomAllowedScale(random);
      final Offset offset = randomCanvasPoint(random, reach: hugeCanvasReach);

      final CanvasView view = CanvasView(scale: scale, offset: offset);

      expect(view.scale, scale);
      expect(view.offset, offset);
    }
  });

  test('test_canvas_view_constructor_property_unit_view_is_identity', () {
    final Random random = seededRandom(117202);
    const CanvasView unitView = CanvasView(scale: 1, offset: Offset.zero);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset point = randomCanvasPoint(random, reach: hugeCanvasReach);

      expect(unitView.findCanvasPoint(point), point);
      expect(unitView.findViewportPoint(point), point);
    }
  });

  test('test_canvas_view_constructor_property_equal_values_map_alike', () {
    final Random random = seededRandom(117203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasView first = randomCanvasView(
        random,
        reach: ordinaryCanvasReach,
      );
      final CanvasView second = CanvasView(
        scale: first.scale,
        offset: first.offset,
      );
      final Offset point = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );

      expect(second.findCanvasPoint(point), first.findCanvasPoint(point));
      expect(second.findViewportPoint(point), first.findViewportPoint(point));
    }
  });

  test('test_find_canvas_point_property_offset_is_the_canvas_origin', () {
    final Random random = seededRandom(117204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasView view = randomCanvasView(random, reach: hugeCanvasReach);

      expect(view.findCanvasPoint(view.offset), Offset.zero);
    }
  });

  test('test_find_canvas_point_property_huge_points_round_trip', () {
    final Random random = seededRandom(117205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasView view = randomCanvasView(random, reach: hugeCanvasReach);
      final Offset viewportPoint = randomCanvasPoint(
        random,
        reach: hugeCanvasReach,
      );

      final Offset canvasPoint = view.findCanvasPoint(viewportPoint);
      final Offset backOnViewport = view.findViewportPoint(canvasPoint);

      expect(canvasPoint.isFinite, isTrue);
      expectNearlySamePoint(
        backOnViewport,
        viewportPoint,
        magnitude: measureViewMagnitude(view, viewportPoint),
      );
    }
  });

  test('test_find_viewport_point_property_canvas_origin_lands_on_offset', () {
    final Random random = seededRandom(117206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasView view = randomCanvasView(random, reach: hugeCanvasReach);

      expect(view.findViewportPoint(Offset.zero), view.offset);
    }
  });

  test('test_find_viewport_point_property_keeps_left_right_order', () {
    final Random random = seededRandom(117207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasView view = randomCanvasView(
        random,
        reach: ordinaryCanvasReach,
      );
      final Offset first = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );
      final Offset second = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );

      final Offset shownFirst = view.findViewportPoint(first);
      final Offset shownSecond = view.findViewportPoint(second);

      expect(first.dx < second.dx, shownFirst.dx < shownSecond.dx);
      expect(first.dy < second.dy, shownFirst.dy < shownSecond.dy);
    }
  });

  test('test_starting_canvas_view_property_matches_documented_start', () {
    expect(startingCanvasView.scale, _documentedStartingScale);
    expect(
      startingCanvasView.findViewportPoint(Offset.zero),
      _documentedStartingMargin,
    );
  });

  test('test_starting_canvas_view_property_scale_within_zoom_limits', () {
    expect(
      startingCanvasView.scale,
      inInclusiveRange(CanvasZoom.smallestScale, CanvasZoom.largestScale),
    );
    expect(
      startingCanvasView.scale,
      lessThanOrEqualTo(CanvasZoom.largestFitScale),
    );
  });

  test('test_starting_canvas_view_property_round_trips_points', () {
    final Random random = seededRandom(117208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Offset point = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );

      final Offset back = startingCanvasView.findCanvasPoint(
        startingCanvasView.findViewportPoint(point),
      );

      expectNearlySamePoint(back, point, magnitude: _ordinaryMagnitude);
    }
  });
}
