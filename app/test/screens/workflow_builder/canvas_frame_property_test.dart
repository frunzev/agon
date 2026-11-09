import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../support/random_inputs.dart';
import '../../support/recorded_canvas_calls.dart';
import '../support/random_page_windows.dart';

const double _dotSpacing = AppSpacing.space4;
const double _largestSide = 900;
const Key _childKey = Key('canvas-child');

Size _randomSize(Random random) {
  return Size(
    random.nextDouble() * _largestSide,
    random.nextDouble() * _largestSide,
  );
}

int _countGridSteps(double extent) {
  int count = 0;
  for (double place = _dotSpacing / 2; place < extent; place += _dotSpacing) {
    count += 1;
  }
  return count;
}

Future<void> _pumpFrame(WidgetTester tester, Random random) async {
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: const Padding(
      padding: EdgeInsets.all(AppSpacing.space4),
      child: CanvasFrame(child: SizedBox.expand(key: _childKey)),
    ),
  );
}

void main() {
  test('test_dot_grid_painter_paint_property_one_dot_per_grid_tile', () {
    final Random random = seededRandom(1162101);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Size size = _randomSize(random);
      final RecordingCanvas canvas = RecordingCanvas();

      const DotGridPainter().paint(canvas, size);

      expect(
        canvas.circles.length,
        _countGridSteps(size.width) * _countGridSteps(size.height),
      );
    }
  });

  test('test_dot_grid_painter_paint_property_dots_centered_in_tiles', () {
    final Random random = seededRandom(1162102);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Size size = _randomSize(random);
      final RecordingCanvas canvas = RecordingCanvas();

      const DotGridPainter().paint(canvas, size);

      for (final RecordedCircle dot in canvas.circles) {
        expect((Offset.zero & size).contains(dot.center), isTrue);
        final double column = (dot.center.dx - _dotSpacing / 2) / _dotSpacing;
        final double row = (dot.center.dy - _dotSpacing / 2) / _dotSpacing;
        expect(column, closeTo(column.roundToDouble(), 1e-9));
        expect(row, closeTo(row.roundToDouble(), 1e-9));
      }
    }
  });

  test('test_dot_grid_painter_paint_property_thin_strong_line_dots', () {
    final Random random = seededRandom(1162103);
    for (int i = 0; i < propertyIterations; i += 1) {
      final RecordingCanvas canvas = RecordingCanvas();

      const DotGridPainter().paint(canvas, _randomSize(random));

      for (final RecordedCircle dot in canvas.circles) {
        expect(dot.radius, AppBorders.thin);
        expect(dot.color.toARGB32(), AppColors.lineStrong.toARGB32());
      }
    }
  });

  test('test_dot_grid_painter_should_repaint_property_never_repaints', () {
    expect(
      const DotGridPainter().shouldRepaint(const DotGridPainter()),
      isFalse,
    );
  });

  test(
    'test_dot_grid_painter_should_repaint_property_self_never_repaints',
    () {
      const DotGridPainter painter = DotGridPainter();

      expect(painter.shouldRepaint(painter), isFalse);
    },
  );

  test(
    'test_dot_grid_painter_should_repaint_property_same_dots_each_paint',
    () {
      final Random random = seededRandom(1162107);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Size size = _randomSize(random);
        final RecordingCanvas first = RecordingCanvas();
        final RecordingCanvas second = RecordingCanvas();

        const DotGridPainter().paint(first, size);
        const DotGridPainter().paint(second, size);

        expect(first.circles.length, second.circles.length);
        for (int index = 0; index < first.circles.length; index += 1) {
          expect(first.circles[index].center, second.circles[index].center);
        }
      }
    },
  );

  testWidgets('test_canvas_frame_build_property_child_fills_the_frame', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162104);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpFrame(tester, random);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(
        tester.getSize(find.byKey(_childKey)),
        tester.getSize(find.byType(CanvasFrame)),
      );
    }
  });

  testWidgets('test_canvas_frame_build_property_sunken_rounded_and_lined', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162105);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpFrame(tester, random);
      final DecoratedBox box = tester.widget(
        find.descendant(
          of: find.byType(CanvasFrame),
          matching: find.byType(DecoratedBox),
        ),
      );
      final BoxDecoration decoration = box.decoration as BoxDecoration;
      final ClipRRect clip = tester.widget(
        find.descendant(
          of: find.byType(CanvasFrame),
          matching: find.byType(ClipRRect),
        ),
      );

      expect(decoration.color, AppColors.sunken);
      expect((decoration.border! as Border).top.color, AppColors.line);
      expect(decoration.borderRadius, BorderRadius.circular(AppRadii.panel));
      expect(clip.borderRadius, BorderRadius.circular(AppRadii.panel));
    }
  });

  testWidgets('test_canvas_frame_build_property_dots_behind_the_child', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162106);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpFrame(tester, random);
      final CustomPaint paint = tester.widget(
        find.ancestor(
          of: find.byKey(_childKey),
          matching: find.byWidgetPredicate(
            (Widget widget) =>
                widget is CustomPaint && widget.painter is DotGridPainter,
          ),
        ),
      );

      expect(paint.foregroundPainter, isNull);
      expect(paint.painter, isA<DotGridPainter>());
    }
  });
}
