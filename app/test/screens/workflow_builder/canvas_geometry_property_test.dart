import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/random_canvas_points.dart';

const Size _documentedStepSize = Size(160, 88);

CanvasPosition _shiftPosition(CanvasPosition position, Offset delta) {
  return CanvasPosition(
    horizontal: position.horizontal + delta.dx,
    vertical: position.vertical + delta.dy,
  );
}

List<CanvasPosition> _randomPositions(Random random) {
  final int count = random.nextInt(8);
  return <CanvasPosition>[
    for (int index = 0; index < count; index += 1)
      randomPlacedPosition(random, reach: ordinaryCanvasReach),
  ];
}

void main() {
  test('test_find_node_rect_property_step_size_at_its_position', () {
    final Random random = seededRandom(117301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = randomPlacedPosition(
        random,
        reach: hugeCanvasReach,
      );

      final Rect node = findNodeRect(position);

      expect(node.topLeft, Offset(position.horizontal, position.vertical));
      expect(node.width, closeTo(_documentedStepSize.width, 1e-6));
      expect(node.height, closeTo(_documentedStepSize.height, 1e-6));
    }
  });

  test('test_find_node_rect_property_moves_with_its_position', () {
    final Random random = seededRandom(117302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = randomPlacedPosition(
        random,
        reach: ordinaryCanvasReach,
      );
      final Offset delta = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );

      final Rect moved = findNodeRect(_shiftPosition(position, delta));
      final Rect shifted = findNodeRect(position).shift(delta);

      expectNearlySamePoint(moved.topLeft, shifted.topLeft, magnitude: 0);
      expectNearlySamePoint(
        moved.bottomRight,
        shifted.bottomRight,
        magnitude: 0,
      );
    }
  });

  test('test_find_node_rect_property_holds_its_centre_not_far_points', () {
    final Random random = seededRandom(117303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rect node = findNodeRect(
        randomPlacedPosition(random, reach: ordinaryCanvasReach),
      );
      final double beyond = 1 + random.nextDouble() * ordinaryCanvasReach;

      expect(node.contains(node.center), isTrue);
      expect(node.contains(node.topLeft), isTrue);
      expect(node.contains(node.bottomRight.translate(beyond, 0)), isFalse);
      expect(node.contains(node.topLeft.translate(0, -beyond)), isFalse);
    }
  });

  test('test_measure_canvas_property_adds_the_end_margins', () {
    final Random random = seededRandom(117310);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rect bounds = findNodesBounds(_randomPositions(random));

      final Size size = measureCanvas(bounds);

      expect(size.width, bounds.right + CanvasMetrics.endMarginHorizontal);
      expect(size.height, bounds.bottom + CanvasMetrics.endMarginVertical);
    }
  });

  test('test_measure_canvas_property_bigger_bounds_never_shrink', () {
    final Random random = seededRandom(117311);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rect bounds = findNodesBounds(_randomPositions(random));
      final Rect grown = bounds.expandToInclude(
        findNodeRect(randomPlacedPosition(random, reach: ordinaryCanvasReach)),
      );

      final Size size = measureCanvas(bounds);
      final Size grownSize = measureCanvas(grown);

      expect(grownSize.width, greaterThanOrEqualTo(size.width));
      expect(grownSize.height, greaterThanOrEqualTo(size.height));
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0));
    }
  });

  test('test_find_nodes_bounds_property_order_does_not_matter', () {
    final Random random = seededRandom(117312);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<CanvasPosition> positions = _randomPositions(random);
      final List<CanvasPosition> shuffled = List<CanvasPosition>.of(positions);
      shuffled.shuffle(random);

      expect(findNodesBounds(shuffled), findNodesBounds(positions));
    }
  });

  test('test_find_nodes_bounds_property_empty_or_one_step_is_exact', () {
    final Random random = seededRandom(117313);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = randomPlacedPosition(
        random,
        reach: hugeCanvasReach,
      );

      final Rect lone = findNodesBounds(<CanvasPosition>[position]);

      expect(findNodesBounds(const <CanvasPosition>[]), Rect.zero);
      expect(lone, findNodeRect(position));
      expect(lone.isFinite, isTrue);
    }
  });

  test('test_move_canvas_position_property_zero_move_changes_nothing', () {
    final Random random = seededRandom(117314);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = randomPlacedPosition(
        random,
        reach: hugeCanvasReach,
      );

      expect(moveCanvasPosition(position, Offset.zero), position);
    }
  });

  test('test_move_canvas_position_property_each_axis_stops_at_zero', () {
    final Random random = seededRandom(117315);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = randomPlacedPosition(
        random,
        reach: ordinaryCanvasReach,
      );
      final Offset delta = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );

      final CanvasPosition moved = moveCanvasPosition(position, delta);

      expect(
        moved.horizontal,
        closeTo(max(0, position.horizontal + delta.dx), 1e-9),
      );
      expect(
        moved.vertical,
        closeTo(max(0, position.vertical + delta.dy), 1e-9),
      );
    }
  });

  test('test_move_canvas_position_property_unclamped_moves_add_up', () {
    final Random random = seededRandom(117316);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = randomPlacedPosition(
        random,
        reach: ordinaryCanvasReach,
      );
      final Offset first = Offset(
        random.nextDouble() * ordinaryCanvasReach,
        random.nextDouble() * ordinaryCanvasReach,
      );
      final Offset second = Offset(
        random.nextDouble() * ordinaryCanvasReach,
        random.nextDouble() * ordinaryCanvasReach,
      );

      final CanvasPosition stepped = moveCanvasPosition(
        moveCanvasPosition(position, first),
        second,
      );
      final CanvasPosition jumped = moveCanvasPosition(
        position,
        first + second,
      );

      expect(stepped.horizontal, closeTo(jumped.horizontal, 1e-9));
      expect(stepped.vertical, closeTo(jumped.vertical, 1e-9));
    }
  });
}
