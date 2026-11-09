import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/markdown_view.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/code_block.dart';

import '../../support/random_inputs.dart';
import 'markdown_view_inputs.dart';

const int _largestBlockCount = 8;
const int _deepestQuote = 6;
const List<String> _inlinePieces = <String>[
  '*soft*',
  '**bold**',
  '`code`',
  '[label](https://example.com)',
  '<b>html</b>',
  '![alt](image.png)',
  '&amp;',
];

String _randomBlock(Random random, String marker) {
  return switch (random.nextInt(5)) {
    0 => '# $marker',
    1 => '## $marker',
    2 => '- $marker',
    3 => '```\n$marker\n```',
    _ => '$marker paragraph',
  };
}

void main() {
  testWidgets('test_markdown_view_build_property_hostile_markdown_renders_'
      'at_every_width', (WidgetTester tester) async {
    final Random random = seededRandom(100511);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      await pumpMarkdown(tester, random, randomHostileMarkdown(random));
    }
  });

  testWidgets('test_markdown_view_build_property_never_wider_than_the_'
      'measure', (WidgetTester tester) async {
    final Random random = seededRandom(100512);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = await pumpMarkdown(
        tester,
        random,
        randomHostileMarkdown(random),
      );

      final Finder codeTexts = find.descendant(
        of: find.byType(CodePanel),
        matching: find.byType(Text),
      );
      final Set<Element> scrollingTexts = codeTexts.evaluate().toSet();
      final List<Element> boxes = <Element>[
        ...find.byType(CodePanel).evaluate(),
        for (final Element element in findMarkdownTexts().evaluate())
          if (!scrollingTexts.contains(element)) element,
      ];
      for (final Element element in boxes) {
        final Rect area = tester.getRect(find.byWidget(element.widget));
        expect(area.left, greaterThanOrEqualTo(0));
        expect(area.right, lessThanOrEqualTo(min(width, AppSizes.measure)));
      }
    }
  });

  testWidgets('test_markdown_view_build_property_plain_paragraphs_survive', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100513);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<List<String>> paragraphs = <List<String>>[
        for (int index = 0; index < 1 + random.nextInt(4); index += 1)
          <String>[
            for (int word = 0; word < 1 + random.nextInt(9); word += 1)
              randomPlainWord(random),
          ],
      ];
      final String text = <String>[
        for (final List<String> words in paragraphs)
          words.join(pickOne(random, <String>[' ', '\n'])),
      ].join('\n\n');

      await pumpMarkdown(tester, random, text);

      expect(readShownMarkdownTexts(tester), <String>[
        for (final List<String> words in paragraphs) words.join(' '),
      ]);
    }
  });

  testWidgets('test_build_flow_property_blocks_keep_the_source_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100514);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int blockCount = 1 + random.nextInt(_largestBlockCount);
      final List<String> markers = <String>[
        for (int index = 0; index < blockCount; index += 1) 'mark$index',
      ];
      final String text = <String>[
        for (final String marker in markers) _randomBlock(random, marker),
      ].join('\n\n');

      await pumpMarkdown(tester, random, text);

      double previousTop = double.negativeInfinity;
      for (final String marker in markers) {
        final Finder shown = find.descendant(
          of: find.byType(MarkdownView),
          matching: find.textContaining(marker, findRichText: true),
        );
        final double top = tester.getTopLeft(shown.last).dy;
        expect(top, greaterThan(previousTop), reason: marker);
        previousTop = top;
      }
    }
  });

  testWidgets('test_build_flow_property_quotes_step_in_once_per_level', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100515);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int depth = random.nextInt(_deepestQuote);
      final String text = 'outside\n\n${'> ' * depth}inside';

      await pumpMarkdown(tester, random, text);

      final double outside = tester
          .getTopLeft(findShownMarkdownText('outside'))
          .dx;
      final double inside = tester
          .getTopLeft(findShownMarkdownText('inside'))
          .dx;
      expect(inside - outside, closeTo(depth * AppSpacing.space5, 0.01));
    }
  });

  testWidgets('test_build_flow_property_later_paragraphs_of_an_item_line_up_'
      'with_its_first', (WidgetTester tester) async {
    final Random random = seededRandom(100516);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String first = randomPlainWord(random);
      final String second = '${randomPlainWord(random)}z';
      final String bullet = pickOne(random, <String>['-', '*', '1.']);
      final String indent = ' ' * (bullet.length + 1);

      await pumpMarkdown(tester, random, '$bullet $first\n\n$indent$second');

      final Offset firstStart = tester.getTopLeft(
        findShownMarkdownText(first),
      );
      final Offset secondStart = tester.getTopLeft(
        findShownMarkdownText(second),
      );
      expect(secondStart.dx, closeTo(firstStart.dx, 0.01));
      expect(secondStart.dy, greaterThan(firstStart.dy));
    }
  });

  testWidgets('test_is_block_property_inline_markup_never_splits_a_'
      'paragraph', (WidgetTester tester) async {
    final Random random = seededRandom(100517);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String text = <String>[
        for (int index = 0; index < 1 + random.nextInt(6); index += 1)
          pickOne(random, _inlinePieces),
      ].join(' ');

      await pumpMarkdown(tester, random, 'start $text end');

      expect(findMarkdownTexts(), findsOneWidget, reason: text);
    }
  });

  testWidgets('test_is_block_property_every_block_gets_its_own_widget', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100518);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int count = 1 + random.nextInt(_largestBlockCount);
      final String text = <String>[
        for (int index = 0; index < count; index += 1)
          '${'#' * (1 + random.nextInt(6))} heading$index',
      ].join('\n');

      await pumpMarkdown(tester, random, text);

      expect(readShownMarkdownTexts(tester), <String>[
        for (int index = 0; index < count; index += 1) 'heading$index',
      ]);
    }
  });

  testWidgets('test_is_block_property_raw_html_blocks_show_as_their_own_'
      'text', (WidgetTester tester) async {
    final Random random = seededRandom(100519);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String word = randomPlainWord(random);
      final String html = pickOne(random, <String>[
        '<div>$word</div>',
        '<script>$word</script>',
        '<details>$word</details>',
      ]);

      await pumpMarkdown(tester, random, '$html\n\n# after');

      expect(readShownMarkdownTexts(tester), <String>[html, 'after']);
    }
  });
}
