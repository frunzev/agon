import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../support/random_inputs.dart';
import '../../support/recorded_canvas_calls.dart';

const double _dashLength = AppSpacing.space1;
const double _largestSide = 900;
const double _edgeTolerance = AppBorders.thin;

Size _randomSize(Random random) {
  return Size(
    random.nextDouble() * _largestSide,
    random.nextDouble() * _largestSide,
  );
}

Color _randomColor(Random random) {
  return Color.fromARGB(255, random.nextInt(256), random.nextInt(256), 0);
}

double _roundedPerimeter(Size size) {
  final double radius = min(AppRadii.panel, min(size.width, size.height) / 2);
  final double straight = 2 * (size.width + size.height) - 8 * radius;
  return straight + 2 * pi * radius;
}

void main() {
  test('test_dashed_outline_painter_paint_property_dashes_cover_half', () {
    final Random random = seededRandom(1162001);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Size size = _randomSize(random);
      final RecordingCanvas canvas = RecordingCanvas();

      const DashedOutlinePainter(color: AppColors.lineStrong)
          .paint(canvas, size);

      final double perimeter = _roundedPerimeter(size);
      final int fewest = (perimeter / (2 * _dashLength)).floor();
      final int most = (perimeter / (2 * _dashLength)).ceil() + 1;
      expect(canvas.paths.length, inInclusiveRange(fewest, most));
    }
  });

  test('test_dashed_outline_painter_paint_property_stays_inside_the_box', () {
    final Random random = seededRandom(1162002);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Size size = _randomSize(random);
      final RecordingCanvas canvas = RecordingCanvas();
      final Rect allowed = (Offset.zero & size).inflate(_edgeTolerance);

      const DashedOutlinePainter(color: AppColors.lineStrong)
          .paint(canvas, size);

      for (final RecordedPath dash in canvas.paths) {
        expect(allowed.contains(dash.bounds.topLeft), isTrue);
        expect(allowed.contains(dash.bounds.bottomRight), isTrue);
      }
    }
  });

  test('test_dashed_outline_painter_paint_property_thin_strokes_in_color', () {
    final Random random = seededRandom(1162003);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Color color = _randomColor(random);
      final RecordingCanvas canvas = RecordingCanvas();

      DashedOutlinePainter(color: color).paint(canvas, _randomSize(random));

      for (final RecordedPath dash in canvas.paths) {
        expect(dash.paint.color.toARGB32(), color.toARGB32());
        expect(dash.paint.style, PaintingStyle.stroke);
        expect(dash.paint.strokeWidth, AppBorders.thin);
      }
    }
  });

  test(
    'test_dashed_outline_painter_should_repaint_property_only_on_color',
    () {
      final Random random = seededRandom(1162004);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Color first = _randomColor(random);
        final Color second = random.nextBool() ? first : _randomColor(random);

        final bool repaints = DashedOutlinePainter(color: second)
            .shouldRepaint(DashedOutlinePainter(color: first));

        expect(repaints, first != second);
      }
    },
  );

  test('test_dashed_outline_painter_should_repaint_property_symmetric', () {
    final Random random = seededRandom(1162005);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DashedOutlinePainter first = DashedOutlinePainter(
        color: _randomColor(random),
      );
      final DashedOutlinePainter second = DashedOutlinePainter(
        color: _randomColor(random),
      );

      expect(first.shouldRepaint(second), second.shouldRepaint(first));
    }
  });

  test('test_dashed_outline_painter_should_repaint_property_self_is_same', () {
    final Random random = seededRandom(1162006);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DashedOutlinePainter painter = DashedOutlinePainter(
        color: _randomColor(random),
      );

      expect(painter.shouldRepaint(painter), isFalse);
      expect(painter.color, isA<Color>());
    }
  });
}
