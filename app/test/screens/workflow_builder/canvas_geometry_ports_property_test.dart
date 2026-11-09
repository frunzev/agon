import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/random_canvas_points.dart';

const double _hugeMagnitude = hugeCanvasReach * 4;
const Size _documentedStepSize = Size(160, 88);

CanvasPosition _shiftPosition(CanvasPosition position, Offset delta) {
  return CanvasPosition(
    horizontal: position.horizontal + delta.dx,
    vertical: position.vertical + delta.dy,
  );
}

void main() {
  test('test_find_input_port_property_middle_of_the_top_edge', () {
    final Random random = seededRandom(117304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = randomPlacedPosition(
        random,
        reach: hugeCanvasReach,
      );
      final Rect node = findNodeRect(position);

      final Offset port = findInputPort(position);

      expect(port.dy, node.top);
      expectNearlySamePoint(port, node.topCenter, magnitude: _hugeMagnitude);
    }
  });

  test('test_find_input_port_property_one_step_height_above_output', () {
    final Random random = seededRandom(117305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = randomPlacedPosition(
        random,
        reach: ordinaryCanvasReach,
      );

      final Offset input = findInputPort(position);
      final Offset output = findOutputPort(position);

      expect(input.dx, output.dx);
      expect(output.dy - input.dy, closeTo(_documentedStepSize.height, 1e-6));
    }
  });

  test('test_find_input_port_property_moves_with_its_position', () {
    final Random random = seededRandom(117306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = randomPlacedPosition(
        random,
        reach: ordinaryCanvasReach,
      );
      final Offset delta = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );

      expectNearlySamePoint(
        findInputPort(_shiftPosition(position, delta)),
        findInputPort(position) + delta,
        magnitude: 0,
      );
    }
  });

  test('test_find_output_port_property_middle_of_the_bottom_edge', () {
    final Random random = seededRandom(117307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = randomPlacedPosition(
        random,
        reach: hugeCanvasReach,
      );
      final Rect node = findNodeRect(position);

      final Offset port = findOutputPort(position);

      expectNearlySamePoint(
        port,
        node.bottomCenter,
        magnitude: _hugeMagnitude,
      );
      expect(port.dx, greaterThan(node.left));
      expect(port.dx, lessThan(node.right));
    }
  });

  test('test_find_output_port_property_moves_with_its_position', () {
    final Random random = seededRandom(117308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = randomPlacedPosition(
        random,
        reach: ordinaryCanvasReach,
      );
      final Offset delta = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );

      expectNearlySamePoint(
        findOutputPort(_shiftPosition(position, delta)),
        findOutputPort(position) + delta,
        magnitude: 0,
      );
    }
  });

  test('test_find_output_port_property_input_and_output_are_distinct', () {
    final Random random = seededRandom(117309);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasPosition position = randomPlacedPosition(
        random,
        reach: ordinaryCanvasReach,
      );

      final double gap =
          (findOutputPort(position) - findInputPort(position)).distance;

      expect(gap, greaterThan(2 * CanvasMetrics.portHitRadius));
    }
  });
}
