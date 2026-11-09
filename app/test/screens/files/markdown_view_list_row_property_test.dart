import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'markdown_nesting_inputs.dart';
import 'markdown_view_inputs.dart';

void main() {
  testWidgets('test_build_list_row_property_shallow_markers_sit_beside_'
      'their_text', (WidgetTester tester) async {
    final Random random = seededRandom(105707);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int depth = 1 + random.nextInt(deepestIndentedLevel);
      final List<String> markers = randomListMarkers(random, depth);

      await pumpMarkdown(
        tester,
        random,
        nestMarkdownList(markers, isLoose: false),
      );

      for (int level = 0; level < depth; level += 1) {
        final Rect item = tester.getRect(findNestedItem(level));
        final Rect marker = tester.getRect(
          findShownMarkdownText(describeShownMarker(markers[level]))
              .at(countSameMarkersBefore(markers, level)),
        );
        expect(marker.top, closeTo(item.top, 0.01), reason: 'level $level');
        expect(marker.right, lessThanOrEqualTo(item.left));
      }
    }
  });

  testWidgets('test_build_list_row_property_deep_markers_share_the_text_'
      'line', (WidgetTester tester) async {
    final Random random = seededRandom(105708);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int depth = deepestIndentedLevel + 1 + random.nextInt(12);

      await pumpMarkdown(
        tester,
        random,
        nestMarkdownList(
          List<String>.filled(depth, '-'),
          isLoose: random.nextBool(),
        ),
      );

      final int bulletsAlone = findShownMarkdownText(shownBullet)
          .evaluate()
          .length;
      expect(bulletsAlone, deepestIndentedLevel);
    }
  });

  testWidgets('test_build_list_row_property_rows_fit_the_narrowest_'
      'window', (WidgetTester tester) async {
    final Random random = seededRandom(105709);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int depth = 1 + random.nextInt(deepestNesting);
      final String text = nestMarkdownList(
        randomListMarkers(random, depth),
        isLoose: random.nextBool(),
      );

      await pumpMarkdownAtNarrowestWidth(tester, text);

      for (int level = 0; level < depth; level += 1) {
        final Rect item = tester.getRect(findNestedItem(level));
        expect(item.right, lessThanOrEqualTo(narrowestWidth + 0.01));
        expect(item.width, greaterThan(0));
      }
    }
  });

  testWidgets('test_place_marker_inline_property_tight_items_join_their_'
      'marker', (WidgetTester tester) async {
    final Random random = seededRandom(105710);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int depth = deepestIndentedLevel + 1 + random.nextInt(8);
      final List<String> markers = randomListMarkers(random, depth);

      await pumpMarkdown(
        tester,
        random,
        nestMarkdownList(markers, isLoose: false),
      );

      for (int level = deepestIndentedLevel; level < depth; level += 1) {
        final String marker = describeShownMarker(markers[level]);
        expect(
          findShownMarkdownText('$marker item$level'),
          findsOneWidget,
          reason: 'level $level',
        );
      }
    }
  });

  testWidgets('test_place_marker_inline_property_loose_items_join_their_'
      'marker', (WidgetTester tester) async {
    final Random random = seededRandom(105711);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int depth = deepestIndentedLevel + 1 + random.nextInt(8);
      final List<String> markers = randomListMarkers(random, depth);

      await pumpMarkdown(
        tester,
        random,
        nestMarkdownList(markers, isLoose: true),
      );

      for (int level = deepestIndentedLevel; level < depth; level += 1) {
        final String marker = describeShownMarker(markers[level]);
        expect(findShownMarkdownText('$marker item$level'), findsOneWidget);
      }
    }
  });

  testWidgets('test_place_marker_inline_property_a_marker_before_a_block_'
      'keeps_the_order', (WidgetTester tester) async {
    final Random random = seededRandom(105712);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String indent = ' ' * (2 * deepestIndentedLevel);
      final String code = randomPlainWord(random);
      final String outer = nestMarkdownList(
        List<String>.filled(deepestIndentedLevel, '-'),
        isLoose: false,
      );
      final String text = '$outer\n$indent- ```\n$indent  $code\n$indent  ```';

      await pumpMarkdown(tester, random, text);

      final double marker = tester
          .getTopLeft(findShownMarkdownText(shownBullet).last)
          .dy;
      final double codeTop = tester.getTopLeft(find.text(code)).dy;
      expect(marker, lessThan(codeTop));
    }
  });
}
