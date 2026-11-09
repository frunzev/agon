import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';
import 'support/random_canvas_points.dart';

const double _ordinaryMagnitude = ordinaryCanvasReach * 8;
const double _outOfRangeScaleReach = 8;
const List<double> _hostileScales = <double>[
  double.nan,
  double.infinity,
  double.negativeInfinity,
  0,
  -1,
  double.minPositive,
  double.maxFinite,
];

void main() {
  test('test_zoom_canvas_view_property_current_scale_changes_nothing', () {
    final Random random = seededRandom(117209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasView view = randomCanvasView(
        random,
        reach: ordinaryCanvasReach,
      );

      final CanvasView zoomed = zoomCanvasView(
        view: view,
        focus: randomCanvasPoint(random, reach: ordinaryCanvasReach),
        scale: view.scale,
      );

      expect(zoomed.scale, view.scale);
      expectNearlySamePoint(
        zoomed.offset,
        view.offset,
        magnitude: _ordinaryMagnitude,
      );
    }
  });

  test('test_zoom_canvas_view_property_two_zooms_equal_the_last_one', () {
    final Random random = seededRandom(117210);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasView view = randomCanvasView(
        random,
        reach: ordinaryCanvasReach,
      );
      final Offset focus = randomCanvasPoint(
        random,
        reach: ordinaryCanvasReach,
      );
      final double lastScale = random.nextDouble() * _outOfRangeScaleReach;

      final CanvasView twice = zoomCanvasView(
        view: zoomCanvasView(
          view: view,
          focus: focus,
          scale: random.nextDouble() * _outOfRangeScaleReach,
        ),
        focus: focus,
        scale: lastScale,
      );
      final CanvasView once = zoomCanvasView(
        view: view,
        focus: focus,
        scale: lastScale,
      );

      expect(twice.scale, once.scale);
      expectNearlySamePoint(
        twice.offset,
        once.offset,
        magnitude: _ordinaryMagnitude / CanvasZoom.smallestScale,
      );
    }
  });

  test('test_zoom_canvas_view_property_hostile_scales_stay_usable', () {
    final Random random = seededRandom(117211);

    for (final double hostileScale in _hostileScales) {
      final CanvasView view = randomCanvasView(
        random,
        reach: ordinaryCanvasReach,
      );

      final CanvasView zoomed = zoomCanvasView(
        view: view,
        focus: randomCanvasPoint(random, reach: ordinaryCanvasReach),
        scale: hostileScale,
      );

      expect(
        zoomed.scale,
        inInclusiveRange(CanvasZoom.smallestScale, CanvasZoom.largestScale),
        reason: '$hostileScale',
      );
      expect(zoomed.offset.isFinite, isTrue, reason: '$hostileScale');
    }
  });

  test('test_pan_canvas_view_property_pans_add_up', () {
    final Random random = seededRandom(117212);

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

      final CanvasView stepped = panCanvasView(
        view: panCanvasView(view: view, delta: first),
        delta: second,
      );
      final CanvasView jumped = panCanvasView(
        view: view,
        delta: first + second,
      );

      expect(stepped.scale, jumped.scale);
      expectNearlySamePoint(
        stepped.offset,
        jumped.offset,
        magnitude: _ordinaryMagnitude,
      );
    }
  });

  test('test_pan_canvas_view_property_pan_back_restores_the_view', () {
    final Random random = seededRandom(117213);

    for (int i = 0; i < propertyIterations; i += 1) {
      final CanvasView view = randomCanvasView(random, reach: hugeCanvasReach);
      final Offset delta = randomCanvasPoint(random, reach: hugeCanvasReach);

      final CanvasView back = panCanvasView(
        view: panCanvasView(view: view, delta: delta),
        delta: -delta,
      );

      expect(back.scale, view.scale);
      expectNearlySamePoint(
        back.offset,
        view.offset,
        magnitude: hugeCanvasReach * 4,
      );
    }
  });

  test('test_fit_canvas_view_property_empty_or_one_step_stays_finite', () {
    final Random random = seededRandom(117214);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Rect> diagrams = <Rect>[
        Rect.zero,
        findNodeRect(randomPlacedPosition(random, reach: hugeCanvasReach)),
      ];
      final Size viewport = Size(
        random.nextInt(3) == 0 ? 0 : random.nextDouble() * ordinaryCanvasReach,
        random.nextInt(3) == 0 ? 0 : random.nextDouble() * ordinaryCanvasReach,
      );

      for (final Rect diagram in diagrams) {
        final CanvasView fitted = fitCanvasView(
          diagramBounds: diagram,
          viewport: viewport,
        );

        expect(fitted.scale.isFinite, isTrue);
        expect(fitted.offset.isFinite, isTrue);
        expect(
          fitted.scale,
          inInclusiveRange(
            CanvasZoom.smallestScale,
            CanvasZoom.largestFitScale,
          ),
        );
      }
    }
  });

  test('test_fit_canvas_view_property_bigger_viewport_never_shrinks', () {
    final Random random = seededRandom(117215);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Rect diagram = Rect.fromLTWH(
        random.nextDouble() * ordinaryCanvasReach,
        random.nextDouble() * ordinaryCanvasReach,
        random.nextDouble() * ordinaryCanvasReach,
        random.nextDouble() * ordinaryCanvasReach,
      );
      final Size viewport = Size(
        random.nextDouble() * ordinaryCanvasReach,
        random.nextDouble() * ordinaryCanvasReach,
      );
      final Size bigger = Size(
        viewport.width + random.nextDouble() * ordinaryCanvasReach,
        viewport.height + random.nextDouble() * ordinaryCanvasReach,
      );

      final double scale = fitCanvasView(
        diagramBounds: diagram,
        viewport: viewport,
      ).scale;
      final double biggerScale = fitCanvasView(
        diagramBounds: diagram,
        viewport: bigger,
      ).scale;

      expect(biggerScale, greaterThanOrEqualTo(scale));
    }
  });
}
