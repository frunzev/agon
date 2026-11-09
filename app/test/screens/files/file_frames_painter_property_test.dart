import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_frames.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const double _square = AppSpacing.space4 / 2;
const double _largestSide = 600;

typedef _PaintedRect = ({Rect rect, int color});

final class _RecordingCanvas implements Canvas {
  final List<_PaintedRect> paintedRects = <_PaintedRect>[];

  @override
  void drawRect(Rect rect, Paint paint) {
    paintedRects.add((rect: rect, color: paint.color.toARGB32()));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('the checkerboard only draws rectangles');
  }
}

Future<CustomPainter> _pumpCheckerboard(
  WidgetTester tester,
  Random random,
) async {
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: ImageFrame(
      child: SizedBox.square(dimension: random.nextDouble() * 99),
    ),
  );
  final CustomPaint paint = tester.widget<CustomPaint>(
    find
        .descendant(
          of: find.byType(ImageFrame),
          matching: find.byType(CustomPaint),
        )
        .first,
  );
  return paint.painter!;
}

Size _randomSize(Random random) {
  return Size(
    random.nextDouble() * _largestSide,
    random.nextDouble() * _largestSide,
  );
}

List<_PaintedRect> _paint(CustomPainter painter, Size size) {
  final _RecordingCanvas canvas = _RecordingCanvas();
  painter.paint(canvas, size);
  return canvas.paintedRects;
}

void main() {
  testWidgets('test_checkerboard_painter_new_property_one_shared_painter', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100101);
    final Set<CustomPainter> painters = <CustomPainter>{};

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      painters.add(await _pumpCheckerboard(tester, random));
    }

    expect(painters, hasLength(1));
  });

  testWidgets('test_checkerboard_painter_new_property_paints_behind_child', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpCheckerboard(tester, random);
      final CustomPaint paint = tester.widget<CustomPaint>(
        find
            .descendant(
              of: find.byType(ImageFrame),
              matching: find.byType(CustomPaint),
            )
            .first,
      );

      expect(paint.painter, isNotNull);
      expect(paint.foregroundPainter, isNull);
    }
  });

  testWidgets('test_checkerboard_painter_new_property_never_repaints', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100103);
    final CustomPainter first = await _pumpCheckerboard(tester, random);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final CustomPainter next = await _pumpCheckerboard(tester, random);

      expect(next.shouldRepaint(first), isFalse);
    }
  });

  testWidgets('test_paint_property_paper_first_then_raised_squares', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100104);
    final CustomPainter painter = await _pumpCheckerboard(tester, random);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Size size = _randomSize(random);
      final List<_PaintedRect> painted = _paint(painter, size);

      expect(painted.first.rect, Offset.zero & size);
      expect(painted.first.color, AppColors.paper.toARGB32());
      for (final _PaintedRect square in painted.skip(1)) {
        expect(square.color, AppColors.raised.toARGB32());
        expect(square.rect.size, const Size.square(_square));
      }
    }
  });

  testWidgets('test_paint_property_squares_alternate_like_a_checkerboard', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100105);
    final CustomPainter painter = await _pumpCheckerboard(tester, random);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_PaintedRect> painted = _paint(painter, _randomSize(random));

      for (final _PaintedRect square in painted.skip(1)) {
        final int column = (square.rect.left / _square).round();
        final int row = (square.rect.top / _square).round();
        expect((row + column).isOdd, isTrue, reason: '${square.rect}');
      }
    }
  });

  testWidgets('test_paint_property_covers_the_whole_area_and_no_more', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100106);
    final CustomPainter painter = await _pumpCheckerboard(tester, random);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Size size = _randomSize(random);
      final List<_PaintedRect> painted = _paint(painter, size);
      final int columns = (size.width / _square).ceil();
      final int rows = (size.height / _square).ceil();
      int oddCells = 0;
      for (int row = 0; row < rows; row += 1) {
        for (int column = 0; column < columns; column += 1) {
          if ((row + column).isOdd) {
            oddCells += 1;
          }
        }
      }

      expect(painted.length - 1, oddCells);
      for (final _PaintedRect square in painted.skip(1)) {
        expect(square.rect.left, lessThan(size.width));
        expect(square.rect.top, lessThan(size.height));
      }
    }
  });

  testWidgets('test_should_repaint_property_false_for_itself', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100107);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final CustomPainter painter = await _pumpCheckerboard(tester, random);

      expect(painter.shouldRepaint(painter), isFalse);
    }
  });

  testWidgets('test_should_repaint_property_painting_is_deterministic', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100108);
    final CustomPainter painter = await _pumpCheckerboard(tester, random);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Size size = _randomSize(random);

      expect(_paint(painter, size), _paint(painter, size));
    }
  });

  testWidgets('test_should_repaint_property_no_repaint_on_rebuild', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100109);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final CustomPainter before = await _pumpCheckerboard(tester, random);
      final CustomPainter after = await _pumpCheckerboard(tester, random);

      expect(after.shouldRepaint(before), isFalse);
      expect(before.shouldRepaint(after), isFalse);
    }
  });
}
