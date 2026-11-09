import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/theme/page_metrics.dart';

import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';

const Key _canvasKey = Key('builder-canvas');
const Key _panelKey = Key('builder-panel');
const double _topGap = AppSpacing.space3;
const double _sidePanelWidth = 320;
const double _sheetShare = 0.6;
const double _smallestCanvasShare = 0.5;
const double _tallestTop = 400;
const int _mostTops = 6;
const double _tallestPanel = 2000;
const double _tolerance = 0.5;

List<double> _randomTopHeights(Random random) {
  final int count = random.nextInt(_mostTops + 1);
  return <double>[
    for (int index = 0; index < count; index += 1)
      1 + random.nextDouble() * _tallestTop,
  ];
}

Future<List<double>> _pumpPageLayout(
  WidgetTester tester,
  Random random,
) async {
  final List<double> heights = _randomTopHeights(random);
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: BuilderPageLayout(
      top: <Widget>[
        for (int index = 0; index < heights.length; index += 1)
          SizedBox(key: ValueKey<int>(index), height: heights[index]),
      ],
      builder: const SizedBox.expand(key: _canvasKey),
    ),
  );
  return heights;
}

Future<double> _pumpFrame(
  WidgetTester tester,
  Random random, {
  required Widget? panel,
}) async {
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: BuilderFrame(
      canvas: const SizedBox.expand(key: _canvasKey),
      panel: panel,
    ),
  );
  return tester.view.physicalSize.width;
}

Widget _randomPanel(Random random) {
  return SizedBox(
    key: _panelKey,
    height: 1 + random.nextDouble() * _tallestPanel,
  );
}

void main() {
  testWidgets('test_builder_page_layout_build_property_canvas_keeps_half', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162501);
    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      await _pumpPageLayout(tester, random);

      final double page = tester
          .getSize(find.byType(BuilderPageLayout))
          .height;
      final double canvas = tester.getSize(find.byKey(_canvasKey)).height;
      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(canvas, greaterThanOrEqualTo(page * _smallestCanvasShare - 1));
    }
  });

  testWidgets('test_builder_page_layout_build_property_tops_in_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162502);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<double> heights = await _pumpPageLayout(tester, random);

      for (int index = 1; index < heights.length; index += 1) {
        final Rect above = tester.getRect(
          find.byKey(ValueKey<int>(index - 1)),
        );
        final Rect below = tester.getRect(find.byKey(ValueKey<int>(index)));
        expect(below.top - above.bottom, closeTo(_topGap, _tolerance));
      }
    }
  });

  testWidgets('test_builder_page_layout_build_property_canvas_under_tops', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162503);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpPageLayout(tester, random);

      final Rect page = tester.getRect(find.byType(BuilderPageLayout));
      final Rect canvas = tester.getRect(find.byKey(_canvasKey));
      expect(canvas.bottom, lessThanOrEqualTo(page.bottom + _tolerance));
      expect(canvas.top, greaterThan(page.top));
      expect(canvas.width, lessThan(page.width));
    }
  });

  testWidgets('test_build_page_property_short_tops_leave_the_rest', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162504);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<double> heights = await _pumpPageLayout(tester, random);
      final double page = tester
          .getSize(find.byType(BuilderPageLayout))
          .height;
      final double width = tester.view.physicalSize.width;
      final EdgeInsets padding = pagePaddingFor(LayoutSize.forWidth(width));
      double topsHeight = 0;
      for (final double height in heights) {
        topsHeight += height;
      }
      topsHeight += _topGap * max(0, heights.length - 1);
      final double topLimit =
          page * (1 - _smallestCanvasShare) - padding.vertical - _topGap;
      if (topsHeight > topLimit) {
        continue;
      }

      final double canvas = tester.getSize(find.byKey(_canvasKey)).height;
      expect(
        canvas,
        closeTo(page - padding.vertical - topsHeight - _topGap, _tolerance),
      );
    }
  });

  testWidgets('test_build_page_property_tall_tops_scroll_not_overflow', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162505);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: BuilderPageLayout(
          top: <Widget>[
            for (int index = 0; index < _mostTops; index += 1)
              const SizedBox(height: _tallestTop),
          ],
          builder: const SizedBox.expand(key: _canvasKey),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(find.byType(Scrollable), findsOneWidget);
    }
  });

  testWidgets('test_build_page_property_padding_follows_window_size', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162506);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpPageLayout(tester, random);
      final double width = tester.view.physicalSize.width;

      final Rect page = tester.getRect(find.byType(BuilderPageLayout));
      final Rect canvas = tester.getRect(find.byKey(_canvasKey));
      final EdgeInsets padding = pagePaddingFor(LayoutSize.forWidth(width));
      expect(canvas.left - page.left, closeTo(padding.left, _tolerance));
      expect(page.right - canvas.right, closeTo(padding.right, _tolerance));
      expect(page.bottom - canvas.bottom, closeTo(padding.bottom, _tolerance));
    }
  });

  testWidgets('test_builder_frame_build_property_no_panel_canvas_fills', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162507);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpFrame(tester, random, panel: null);

      expect(
        tester.getSize(find.byKey(_canvasKey)),
        tester.getSize(find.byType(BuilderFrame)),
      );
      expect(find.byType(SingleChildScrollView), findsNothing);
    }
  });

  testWidgets('test_builder_frame_build_property_large_side_panel_right', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162508);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = await _pumpFrame(
        tester,
        random,
        panel: _randomPanel(random),
      );
      if (!LayoutSize.forWidth(width).isLarge) {
        continue;
      }
      final Rect frame = tester.getRect(find.byType(BuilderFrame));
      final Rect canvas = tester.getRect(find.byKey(_canvasKey));
      final Rect panel = tester.getRect(find.byKey(_panelKey));

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(canvas.height, closeTo(frame.height, _tolerance));
      expect(panel.left, greaterThan(canvas.right));
      expect(frame.right - panel.left, lessThanOrEqualTo(_sidePanelWidth));
    }
  });

  testWidgets('test_builder_frame_build_property_small_sheet_at_bottom', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162509);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = await _pumpFrame(
        tester,
        random,
        panel: _randomPanel(random),
      );
      if (LayoutSize.forWidth(width).isLarge) {
        continue;
      }
      final Rect frame = tester.getRect(find.byType(BuilderFrame));
      final Rect canvas = tester.getRect(find.byKey(_canvasKey));
      final Rect sheet = tester.getRect(
        find.ancestor(
          of: find.byKey(_panelKey),
          matching: find.byType(SingleChildScrollView),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(canvas, frame);
      expect(sheet.bottom, closeTo(frame.bottom, _tolerance));
      expect(sheet.height, lessThanOrEqualTo(frame.height * _sheetShare + 1));
    }
  });
}
