import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/shared/muted_note.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const int _largestKeyNumber = 1000;
const int _longestRepeat = 40;

void main() {
  test('test_muted_note_constructor_property_keeps_the_text', () {
    final Random random = seededRandom(111301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = randomHostileText(random);

      expect(MutedNote(text).text, text);
    }
  });

  test('test_muted_note_constructor_property_keeps_the_key', () {
    final Random random = seededRandom(111302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(_largestKeyNumber));

      expect(MutedNote(randomText(random), key: key).key, key);
    }
  });

  test('test_muted_note_constructor_property_holds_no_state', () {
    final Random random = seededRandom(111306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final MutedNote note = MutedNote(randomText(random));

      expect(note, isA<StatelessWidget>());
      expect(note.createElement(), isA<StatelessElement>());
    }
  });

  testWidgets('test_muted_note_build_property_shows_the_text_unchanged', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String text = randomHostileText(random);
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: MutedNote(text),
      );

      final Text shown = tester.widget<Text>(find.byType(Text));

      expect(shown.data, text);
    }
  });

  testWidgets('test_muted_note_build_property_reads_as_muted_body_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: MutedNote(randomText(random)),
      );

      final TextStyle? style = tester.widget<Text>(find.byType(Text)).style;

      expect(style?.color, AppColors.inkMuted);
      expect(style?.fontSize, AppTextStyles.body.fontSize);
    }
  });

  testWidgets('test_muted_note_build_property_long_text_wraps_without_'
      'overflow', (WidgetTester tester) async {
    final Random random = seededRandom(111305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String word = 'note${random.nextInt(_largestKeyNumber)} ';
      final String text = word * (1 + random.nextInt(_longestRepeat));
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: MutedNote(text),
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(MutedNote)).width,
        lessThan(width + 1),
      );
    }
  });
}
