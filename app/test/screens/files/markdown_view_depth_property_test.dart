import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/random_inputs.dart';
import 'markdown_nesting_inputs.dart';
import 'markdown_view_inputs.dart';

void main() {
  testWidgets('test_build_flow_property_nesting_of_any_depth_never_'
      'overflows', (WidgetTester tester) async {
    final Random random = seededRandom(105701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int depth = 1 + random.nextInt(deepestNesting);
      final String text = nestMarkdownList(
        randomListMarkers(random, depth),
        isLoose: random.nextBool(),
      );

      await pumpMarkdownAtNarrowestWidth(tester, text);
      await pumpMarkdown(tester, random, text);
    }
  });

  testWidgets('test_build_flow_property_indent_stops_growing_past_the_'
      'cap', (WidgetTester tester) async {
    final Random random = seededRandom(105702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int depth = deepestIndentedLevel + 2 + random.nextInt(20);
      final String text = nestMarkdownList(
        List<String>.filled(depth, pickOne(random, <String>['-', '*'])),
        isLoose: false,
      );

      await pumpMarkdownAtNarrowestWidth(tester, text);

      double previousLeft = double.negativeInfinity;
      for (int level = 0; level < depth; level += 1) {
        final double left = tester.getTopLeft(findNestedItem(level)).dx;
        if (level < deepestIndentedLevel) {
          expect(left, greaterThan(previousLeft), reason: 'level $level');
        } else {
          expect(left, closeTo(previousLeft, 0.01), reason: 'level $level');
        }
        previousLeft = left;
      }
    }
  });

  testWidgets('test_build_flow_property_every_item_shows_once_in_source_'
      'order', (WidgetTester tester) async {
    final Random random = seededRandom(105703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int depth = 1 + random.nextInt(deepestNesting);
      final String text = nestMarkdownList(
        randomListMarkers(random, depth),
        isLoose: random.nextBool(),
      );

      await pumpMarkdown(tester, random, text);

      double previousTop = double.negativeInfinity;
      for (int level = 0; level < depth; level += 1) {
        expect(findNestedItem(level), findsOneWidget, reason: 'level $level');
        final double top = tester.getTopLeft(findNestedItem(level)).dy;
        expect(top, greaterThan(previousTop), reason: 'level $level');
        previousTop = top;
      }
    }
  });

  testWidgets('test_build_list_property_every_level_keeps_its_marker', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105704);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int depth = 1 + random.nextInt(deepestNesting);
      final List<String> markers = randomListMarkers(random, depth);

      await pumpMarkdown(
        tester,
        random,
        nestMarkdownList(markers, isLoose: false),
      );

      for (int level = 0; level < depth; level += 1) {
        final String marker = describeShownMarker(markers[level]);
        final Text item = tester.widget(findNestedItem(level));
        if (level >= deepestIndentedLevel) {
          expect(readPlainText(item), '$marker item$level');
        } else {
          expect(readPlainText(item), 'item$level');
        }
      }
    }
  });

  testWidgets('test_build_list_property_deep_task_items_show_their_box', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105705);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int depth = deepestIndentedLevel + 1 + random.nextInt(10);
      final String text = <String>[
        for (int level = 0; level < depth; level += 1)
          '${'  ' * level}- [ ] item$level',
      ].join('\n');

      await pumpMarkdown(tester, random, text);

      for (int level = deepestIndentedLevel; level < depth; level += 1) {
        final Text item = tester.widget(findNestedItem(level));
        expect(readPlainText(item), '$uncheckedBox item$level');
      }
    }
  });

  testWidgets('test_build_list_property_deep_numbers_count_from_their_'
      'start', (WidgetTester tester) async {
    final Random random = seededRandom(105706);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int start = random.nextInt(50);
      const int outerDepth = deepestIndentedLevel + 1;
      final String deepIndent = ' ' * (2 * outerDepth);
      final String outer = nestMarkdownList(
        List<String>.filled(outerDepth, '-'),
        isLoose: false,
      );
      final String text =
          '$outer\n$deepIndent$start. first\n'
          '$deepIndent${start + 9}. second';

      await pumpMarkdown(tester, random, text);

      expect(findShownMarkdownText('$start. first'), findsOneWidget);
      expect(findShownMarkdownText('${start + 1}. second'), findsOneWidget);
    }
  });
}
