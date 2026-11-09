import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/random_loop_layouts.dart';
import 'support/route_box_checks.dart';

void _expectStubClearsCloseSteps(List<Offset> leg, List<Rect> nodes) {
  if (leg.length < 4) {
    return;
  }
  final Offset sidePoint = leg.first;
  for (final Rect node in nodes) {
    if (node.left <= sidePoint.dx) {
      continue;
    }
    for (int i = 1; i < 3; i += 1) {
      final bool enters = doesSegmentEnterBox(leg[i - 1], leg[i], node);
      expect(enters, isFalse, reason: '${leg[i - 1]}-${leg[i]} in $node');
    }
  }
}

void main() {
  test('test_find_stub_horizontal_property_stub_clears_a_close_step', () {
    final Random random = seededRandom(1191101);
    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopLayout layout = randomCloseStepLayout(random);

      final LoopRoute route = routeLoopLayout(layout);

      for (final List<Offset> leg in listLoopLegs(route)) {
        _expectStubClearsCloseSteps(leg, layout.nodes);
      }
    }
  });

  test('test_find_stub_horizontal_property_stub_leaves_the_side_by_at_'
      'most_the_full_stub', () {
    final Random random = seededRandom(1191102);
    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopLayout layout = random.nextBool()
          ? randomCloseStepLayout(random)
          : randomLaneLayout(random);

      for (final List<Offset> leg in listLoopLegs(routeLoopLayout(layout))) {
        if (leg.length == 4) {
          final double stubReach = leg[1].dx - leg.first.dx;
          expect(stubReach, greaterThan(0));
          expect(stubReach, lessThanOrEqualTo(fullLoopStub + loopTolerance));
          expect(leg[2].dx, leg[1].dx);
        }
      }
    }
  });

  test('test_find_stub_horizontal_property_lane_layouts_keep_the_full_'
      'stub', () {
    final Random random = seededRandom(1191103);
    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopLayout layout = randomLaneLayout(random);

      for (final List<Offset> leg in listLoopLegs(routeLoopLayout(layout))) {
        if (leg.length == 4) {
          expect(
            leg[1].dx - leg.first.dx,
            closeTo(fullLoopStub, loopTolerance),
          );
        }
      }
    }
  });

  test('test_is_leg_clear_property_open_row_goes_straight_out', () {
    final Random random = seededRandom(1191104);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Rect source = buildStepBox(
        0,
        loopRowPitch * (1 + random.nextInt(3)),
      );
      final Rect target = buildStepBox(random.nextDouble() * 300, 0);
      final LoopLayout layout = (
        source: source,
        target: target,
        nodes: <Rect>[source, target],
        labelSize: randomLoopLabelSize(random),
      );

      for (final List<Offset> leg in listLoopLegs(routeLoopLayout(layout))) {
        expect(leg, hasLength(2));
        expect(leg.last.dy, leg.first.dy);
      }
    }
  });

  test('test_is_leg_clear_property_step_in_the_row_forces_a_detour', () {
    final Random random = seededRandom(1191105);
    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopLayout lane = randomLaneLayout(random);
      final Rect blocker = buildStepBox(
        lane.source.right + 20 + random.nextDouble() * 100,
        lane.source.top + (random.nextDouble() - 0.5) * 40,
      );
      final LoopLayout layout = (
        source: lane.source,
        target: lane.target,
        nodes: <Rect>[...lane.nodes, blocker],
        labelSize: lane.labelSize,
      );

      expect(findSourceLeg(routeLoopLayout(layout)), hasLength(4));
    }
  });

  test('test_is_leg_clear_property_own_step_never_blocks', () {
    final Random random = seededRandom(1191106);
    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopLayout layout = randomLaneLayout(random);
      final LoopLayout alone = (
        source: layout.source,
        target: layout.target,
        nodes: <Rect>[layout.source, layout.target],
        labelSize: layout.labelSize,
      );

      for (final List<Offset> leg in listLoopLegs(routeLoopLayout(alone))) {
        expect(leg, hasLength(2));
      }
    }
  });
}
