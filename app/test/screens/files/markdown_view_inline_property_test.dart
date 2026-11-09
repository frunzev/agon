import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_typography.dart';

import '../../support/random_inputs.dart';
import 'markdown_view_inputs.dart';

const int _largestItemCount = 6;
const int _largestListStart = 999999999;
const String _bullet = '•';
const List<({String markdown, String shown})> _inlinePieces =
    <({String markdown, String shown})>[
      (markdown: '*soft*', shown: 'soft'),
      (markdown: '**bold**', shown: 'bold'),
      (markdown: '`co de`', shown: 'co de'),
      (markdown: '[label](https://example.com/secret)', shown: 'label'),
      (markdown: '<b>html</b>', shown: '<b>html</b>'),
      (markdown: '&amp;', shown: '&'),
      (markdown: r'\*', shown: '*'),
      (markdown: '![alt words](image.png)', shown: 'alt words'),
    ];

List<String> _readMarkers(WidgetTester tester) {
  return <String>[
    for (final String text in readShownMarkdownTexts(tester))
      if (text == _bullet || RegExp(r'^\d+\.$').hasMatch(text)) text,
  ];
}

TextStyle? _findWordStyle(InlineSpan span, String word, TextStyle? above) {
  if (span is! TextSpan) {
    return null;
  }
  final TextStyle? merged = above == null
      ? span.style
      : above.merge(span.style);
  if (span.text == word) {
    return merged ?? const TextStyle();
  }
  for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
    final TextStyle? found = _findWordStyle(child, word, merged);
    if (found != null) {
      return found;
    }
  }
  return null;
}

TextStyle _readWordStyle(WidgetTester tester, String word) {
  final Text paragraph = tester.widget(findMarkdownTexts().first);
  return _findWordStyle(paragraph.textSpan!, word, null)!;
}

void main() {
  testWidgets('test_build_list_property_numbers_count_up_from_the_start', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100531);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int start = random.nextBool()
          ? random.nextInt(20)
          : random.nextInt(_largestListStart);
      final int count = 1 + random.nextInt(_largestItemCount);
      final String text = <String>[
        for (int index = 0; index < count; index += 1)
          '${index == 0 ? start : 1}. item$index',
      ].join('\n');

      await pumpMarkdown(tester, random, text);

      expect(_readMarkers(tester), <String>[
        for (int index = 0; index < count; index += 1) '${start + index}.',
      ]);
    }
  });

  testWidgets('test_build_list_property_bullets_mark_every_item', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100532);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String marker = pickOne(random, <String>['-', '*', '+']);
      final int count = 1 + random.nextInt(_largestItemCount);
      final String text = <String>[
        for (int index = 0; index < count; index += 1) '$marker item$index',
      ].join('\n');

      await pumpMarkdown(tester, random, text);

      expect(_readMarkers(tester), List<String>.filled(count, _bullet));
      for (int index = 0; index < count; index += 1) {
        final double markerTop = tester
            .getTopLeft(findShownMarkdownText(_bullet).at(index))
            .dy;
        final double itemTop = tester
            .getTopLeft(findShownMarkdownText('item$index'))
            .dy;
        expect(markerTop, closeTo(itemTop, 0.01));
      }
    }
  });

  testWidgets('test_build_list_property_markers_stay_on_one_line', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100533);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int start = random.nextInt(_largestListStart);
      final String text = random.nextBool()
          ? '$start. first\n1. second'
          : '- first\n- second';

      await pumpMarkdown(tester, random, text);

      for (final String marker in _readMarkers(tester).toSet()) {
        for (final Element element in findShownMarkdownText(
          marker,
        ).evaluate()) {
          final RenderParagraph paragraph =
              element.renderObject! as RenderParagraph;
          final double oneLineWidth = paragraph.getMaxIntrinsicWidth(
            double.infinity,
          );
          expect(
            paragraph.size.width,
            greaterThanOrEqualTo(oneLineWidth - 0.01),
            reason: marker,
          );
        }
      }
    }
  });

  testWidgets('test_build_rich_text_property_paragraph_reads_as_its_inline_'
      'text', (WidgetTester tester) async {
    final Random random = seededRandom(100534);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final List<({String markdown, String shown})> pieces =
          <({String markdown, String shown})>[
            for (int index = 0; index < 1 + random.nextInt(5); index += 1)
              pickOne(random, _inlinePieces),
          ];
      final String text = <String>[
        for (final ({String markdown, String shown}) piece in pieces)
          piece.markdown,
      ].join(' ');

      await pumpMarkdown(tester, random, 'a $text z');

      final String expected = <String>[
        for (final ({String markdown, String shown}) piece in pieces)
          piece.shown,
      ].join(' ');
      expect(readShownMarkdownTexts(tester), <String>['a $expected z']);
    }
  });

  testWidgets('test_build_rich_text_property_items_and_quotes_read_as_'
      'body_text', (WidgetTester tester) async {
    final Random random = seededRandom(100535);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String word = '${randomPlainWord(random)}w';
      final String text = pickOne(random, <String>[
        '- $word',
        '1. $word',
        '> $word',
        '> - $word',
      ]);

      await pumpMarkdown(tester, random, text);

      final Text shown = tester.widget(findShownMarkdownText(word));
      expect(shown.style, AppTextStyles.body);
    }
  });

  testWidgets('test_build_rich_text_property_soft_breaks_join_and_hard_'
      'breaks_keep_lines', (WidgetTester tester) async {
    final Random random = seededRandom(100536);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String first = randomPlainWord(random);
      final String second = randomPlainWord(random);
      final bool isHard = random.nextBool();
      final String breakMark = isHard
          ? pickOne(random, <String>['  \n', '\\\n'])
          : '\n';

      await pumpMarkdown(tester, random, '$first$breakMark$second');

      final String joiner = isHard ? '\n' : ' ';
      expect(readShownMarkdownTexts(tester), <String>['$first$joiner$second']);
    }
  });

  testWidgets('test_build_span_property_emphasis_and_strong_style_their_'
      'words', (WidgetTester tester) async {
    final Random random = seededRandom(100537);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String soft = '${randomPlainWord(random)}s';
      final String bold = '${randomPlainWord(random)}b';
      final String code = '${randomPlainWord(random)}c';

      await pumpMarkdown(tester, random, 'x *$soft* **$bold** `$code` y');

      expect(_readWordStyle(tester, soft).fontStyle, FontStyle.italic);
      expect(_readWordStyle(tester, bold).fontWeight, FontWeight.w700);
      expect(
        _readWordStyle(tester, code).fontFamily,
        AppFontFamilies.monospace,
      );
    }
  });

  testWidgets('test_build_span_property_links_show_their_label_never_the_'
      'address', (WidgetTester tester) async {
    final Random random = seededRandom(100538);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String label = '${randomPlainWord(random)}l';
      final String address = 'https://${randomPlainWord(random)}.example/x';

      await pumpMarkdown(tester, random, 'see [$label]($address) now');

      expect(readShownMarkdownTexts(tester), <String>['see $label now']);
      expect(
        _readWordStyle(tester, label).decoration,
        TextDecoration.underline,
      );
    }
  });

  testWidgets('test_build_span_property_images_show_their_alt_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100539);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String alt =
          '${randomPlainWord(random)} ${randomPlainWord(random)}';
      final String image = '![$alt](${randomPlainWord(random)}.png)';
      final String text = random.nextBool()
          ? image
          : '[$image](https://ci.example/badge)';

      await pumpMarkdown(tester, random, 'before $text after');

      expect(readShownMarkdownTexts(tester), <String>['before $alt after']);
    }
  });
}
