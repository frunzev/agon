import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/random_loop_layouts.dart';

void main() {
  test('test_route_leg_property_detour_meets_the_escape_row', () {
    final Random random = seededRandom(1191107);
    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopLayout layout = randomLaneLayout(random);
      final List<Offset> leg = findSourceLeg(routeLoopLayout(layout));
      if (leg.length != 4) {
        continue;
      }

      final bool isSourceBelow =
          layout.source.center.dy >= layout.target.center.dy;
      final double escape = isSourceBelow
          ? layout.source.bottom + loopRowEscape
          : layout.source.top - loopRowEscape;
      expect(leg[2].dy, closeTo(escape, loopTolerance));
      expect(leg[3].dy, closeTo(escape, loopTolerance));
    }
  });

  test('test_route_leg_property_every_leg_ends_on_the_outer_line', () {
    final Random random = seededRandom(1191108);
    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopLayout layout = random.nextBool()
          ? randomLaneLayout(random)
          : randomCloseStepLayout(random);
      final LoopRoute route = routeLoopLayout(layout);

      for (final List<Offset> leg in listLoopLegs(route)) {
        expect(leg.length == 2 || leg.length == 4, isTrue);
        expect(leg.last.dx, closeTo(route.labelArea.center.dx, loopTolerance));
      }
    }
  });

  test('test_route_leg_property_legs_leave_from_the_step_sides', () {
    final Random random = seededRandom(1191109);
    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopLayout layout = randomLaneLayout(random);
      final LoopRoute route = routeLoopLayout(layout);

      expect(findSourceLeg(route).first, layout.source.centerRight);
      final Offset targetSide = findTargetLeg(route).first;
      expect(targetSide.dy, layout.target.center.dy);
      expect(
        targetSide.dx,
        closeTo(layout.target.right + CanvasMetrics.arrowGap, loopTolerance),
      );
    }
  });

  test('test_find_widest_right_property_outer_line_clears_band_steps', () {
    final Random random = seededRandom(1191110);
    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopLayout layout = randomLaneLayout(random);
      final LoopRoute route = routeLoopLayout(layout);
      final double bandReach = loopRowEscape + layout.labelSize.height / 2;
      final double bandTop =
          min(layout.source.top, layout.target.top) - bandReach;
      final double bandBottom =
          max(layout.source.bottom, layout.target.bottom) + bandReach;

      for (final Rect node in layout.nodes) {
        if (node.top < bandBottom && bandTop < node.bottom) {
          expect(
            route.labelArea.left,
            greaterThanOrEqualTo(
              node.right + loopLabelClearance - loopTolerance,
            ),
          );
        }
      }
    }
  });

  test('test_find_widest_right_property_far_steps_change_nothing', () {
    final Random random = seededRandom(1191111);
    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopLayout layout = randomLaneLayout(random);
      final double farBelow =
          max(layout.source.bottom, layout.target.bottom) + 1000;
      final Rect far = buildStepBox(
        5000 + random.nextDouble() * 1000,
        farBelow,
      );
      final LoopLayout withFar = (
        source: layout.source,
        target: layout.target,
        nodes: <Rect>[...layout.nodes, far],
        labelSize: layout.labelSize,
      );

      final LoopRoute first = routeLoopLayout(layout);
      final LoopRoute again = routeLoopLayout(withFar);

      expect(again.corners, first.corners);
      expect(again.labelArea, first.labelArea);
    }
  });

  test('test_find_widest_right_property_outer_line_passes_both_ends', () {
    final Random random = seededRandom(1191112);
    for (int i = 0; i < propertyIterations; i += 1) {
      final LoopLayout layout = randomLaneLayout(random);
      final LoopRoute route = routeLoopLayout(layout);
      final double widestEnd = max(layout.source.right, layout.target.right);

      expect(
        route.labelArea.center.dx,
        greaterThanOrEqualTo(
          widestEnd +
              loopLabelClearance +
              layout.labelSize.width / 2 -
              loopTolerance,
        ),
      );
    }
  });
}
