import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';

import '../../data/rules/support/protected_pattern_inputs.dart';
import '../../support/random_inputs.dart';
import 'support/protected_files_section_harness.dart';

const int _longestFillerLength = 190;

String _randomLongPattern(Random random, int position) {
  final int fillerLength = 1 + random.nextInt(_longestFillerLength);
  final String filler = 'x' * fillerLength;
  return 'long-$position-$filler';
}

List<String> _randomPatternsWithLongOnes(Random random) {
  final List<String> patterns = <String>[...randomStoredPatterns(random)];
  final int longCount = random.nextInt(3);
  for (int i = 0; i < longCount; i += 1) {
    patterns.add(_randomLongPattern(random, i));
  }
  return patterns;
}

void main() {
  testWidgets(
    'test_protected_files_section_build_property_no_overflow_at_any_width',
    (WidgetTester tester) async {
      final Random random = seededRandom(310905);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final double width = randomSectionWidth(random);
        final List<String> patterns = _randomPatternsWithLongOnes(random);

        await pumpProtectedFiles(
          tester,
          width: width,
          repository: await buildRepositoryWithPatterns(patterns),
        );

        expect(tester.takeException(), isNull, reason: 'width $width');
        expect(find.text(protectedFilesTitle), findsOneWidget);
        expect(find.text(protectedFilesNote), findsOneWidget);
        expect(find.text(protectedFilesHint), findsOneWidget);
        expect(findPatternButton(resetPatternsLabel), findsOneWidget);
        expect(findPatternButton(addPatternLabel), findsOneWidget);
      }
    },
  );

  testWidgets(
    'test_protected_files_section_build_property_rows_follow_saved_order',
    (WidgetTester tester) async {
      final Random random = seededRandom(310906);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final List<String> patterns = randomDistinctPatterns(random);
        await pumpProtectedFiles(
          tester,
          width: randomSectionWidth(random),
          repository: await buildRepositoryWithPatterns(patterns),
        );

        double previousTop = double.negativeInfinity;
        for (final String pattern in patterns) {
          final double top = tester.getTopLeft(find.text(pattern)).dy;
          expect(top, greaterThan(previousTop), reason: pattern);
          previousTop = top;
        }
      }
    },
  );

  testWidgets(
    'test_protected_files_section_build_property_list_only_when_patterns',
    (WidgetTester tester) async {
      final Random random = seededRandom(310907);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final List<String> patterns = randomStoredPatterns(random);
        await pumpProtectedFiles(
          tester,
          width: randomSectionWidth(random),
          repository: await buildRepositoryWithPatterns(patterns),
        );

        final Matcher expectedList = patterns.isEmpty
            ? findsNothing
            : findsOneWidget;
        expect(
          findInProtectedFiles(find.byType(ResponsiveList)),
          expectedList,
        );
      }
    },
  );

  testWidgets(
    'test_build_pattern_row_property_each_pattern_once_in_monospace',
    (WidgetTester tester) async {
      final Random random = seededRandom(310908);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final List<String> patterns = _randomPatternsWithLongOnes(random);
        await pumpProtectedFiles(
          tester,
          width: randomSectionWidth(random),
          repository: await buildRepositoryWithPatterns(patterns),
        );

        for (final String pattern in patterns) {
          final Finder shown = findInProtectedFiles(find.text(pattern));
          expect(shown, findsOneWidget, reason: pattern);
          final Text text = tester.widget<Text>(shown);
          expect(text.style?.fontFamily, AppFontFamilies.monospace);
        }
      }
    },
  );

  testWidgets(
    'test_build_pattern_row_property_every_remove_button_is_enabled',
    (WidgetTester tester) async {
      final Random random = seededRandom(310909);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final List<String> patterns = randomStoredPatterns(random);
        await pumpProtectedFiles(
          tester,
          width: randomSectionWidth(random),
          repository: await buildRepositoryWithPatterns(patterns),
        );

        final Iterable<AppButton> removeButtons = tester.widgetList<AppButton>(
          findPatternButton(removePatternLabel),
        );
        expect(removeButtons.length, patterns.length);
        for (final AppButton button in removeButtons) {
          expect(button.onPressed, isNotNull);
        }
      }
    },
  );

  testWidgets(
    'test_build_pattern_row_property_remove_sits_on_its_pattern_row',
    (WidgetTester tester) async {
      final Random random = seededRandom(310910);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final List<String> patterns = randomDistinctPatterns(random);
        await pumpProtectedFiles(
          tester,
          width: randomSectionWidth(random),
          repository: await buildRepositoryWithPatterns(patterns),
        );

        final List<Rect> removeRects = readShownRects(
          findPatternButton(removePatternLabel),
        );
        final List<Rect> patternRects = <Rect>[
          for (final String pattern in patterns)
            tester.getRect(find.text(pattern)),
        ];
        expect(removeRects.length, patterns.length);
        for (int index = 0; index < patterns.length; index += 1) {
          expect(
            removeRects[index].bottom,
            greaterThan(patternRects[index].top),
          );
          if (index + 1 < patterns.length) {
            expect(
              removeRects[index].top,
              lessThan(patternRects[index + 1].top),
            );
          }
        }
      }
    },
  );
}
