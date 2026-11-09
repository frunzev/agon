import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/shared/placeholder_screen.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import '../support/runner_settings_screen_checks.dart';

const String _laterReleaseSummary = 'This screen arrives in a later release.';

String _randomTitle(Random random) {
  return 'Title ${randomHostileText(random)}';
}

Future<void> _pumpPlaceholder(
  WidgetTester tester,
  Random random,
  PlaceholderScreen screen,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  final double height = pickOne(random, <double>[phoneHeight, desktopHeight]);
  useViewSize(tester, Size(width, height));
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    wrapInApp(screen, platform: platformMeantByWidth(width)),
  );
}

void main() {
  test('test_placeholder_screen_property_keeps_the_title', () {
    final Random random = seededRandom(111801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = randomHostileText(random);

      expect(PlaceholderScreen(title: title).title, title);
    }
  });

  test('test_placeholder_screen_property_keeps_the_key', () {
    final Random random = seededRandom(111802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomHostileText(random));

      final PlaceholderScreen screen = PlaceholderScreen(
        key: key,
        title: randomHostileText(random),
      );

      expect(screen.key, key);
    }
  });

  testWidgets('test_placeholder_screen_property_same_title_same_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String title = _randomTitle(random);
      await _pumpPlaceholder(tester, random, PlaceholderScreen(title: title));
      final List<String> first = readShownTexts(
        tester,
        find.byType(PageHeader),
      );

      await _pumpPlaceholder(tester, random, PlaceholderScreen(title: title));

      expect(readShownTexts(tester, find.byType(PageHeader)), first);
    }
  });

  testWidgets('test_placeholder_screen_build_property_title_then_summary', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String title = _randomTitle(random);

      await _pumpPlaceholder(tester, random, PlaceholderScreen(title: title));

      expect(readShownTexts(tester, find.byType(PageHeader)), <String>[
        title,
        _laterReleaseSummary,
      ]);
    }
  });

  testWidgets('test_placeholder_screen_build_property_fits_every_window', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpPlaceholder(
        tester,
        random,
        PlaceholderScreen(title: _randomTitle(random)),
      );

      final Size window = tester.view.physicalSize;
      final Rect header = tester.getRect(find.byType(PageHeader));
      expect(tester.takeException(), isNull);
      expect(header.left, greaterThanOrEqualTo(0));
      expect(header.right, lessThanOrEqualTo(window.width));
    }
  });

  testWidgets('test_placeholder_screen_build_property_summary_sits_below', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String title = _randomTitle(random);

      await _pumpPlaceholder(tester, random, PlaceholderScreen(title: title));

      final Rect titleBox = tester.getRect(find.text(title));
      final Rect summaryBox = tester.getRect(
        find.text(_laterReleaseSummary, findRichText: true),
      );
      expect(summaryBox.top, greaterThanOrEqualTo(titleBox.bottom));
    }
  });
}
