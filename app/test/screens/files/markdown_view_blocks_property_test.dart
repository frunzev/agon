import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/markdown_view.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/code_block.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'markdown_view_inputs.dart';

const int _largestBlockCount = 6;
const int _largestCodeLineCount = 12;
const List<String> _codeLinePieces = <String>[
  '**not bold**',
  '[not](a link)',
  '# not a heading',
  '- not a list',
  '  two leading spaces',
  '<b>raw</b>',
  '&amp;',
  r'\*',
];

String _randomCodeLine(Random random) {
  final String line = random.nextBool()
      ? pickOne(random, _codeLinePieces)
      : randomHostileText(random);
  return line.replaceAll('\n', ' ').replaceAll('`', "'");
}

List<String> _readCodeLines(WidgetTester tester) {
  final Finder lines = find.descendant(
    of: find.byType(CodePanel),
    matching: find.byType(Text),
  );
  return <String>[
    for (final Element element in lines.evaluate())
      readPlainText(element.widget as Text),
  ];
}

bool _isHeader(WidgetTester tester, String plainText) {
  final Finder headers = find.ancestor(
    of: findShownMarkdownText(plainText),
    matching: find.byWidgetPredicate(
      (Widget widget) =>
          widget is Semantics && widget.properties.header == true,
    ),
  );
  return headers.evaluate().isNotEmpty;
}

void main() {
  testWidgets('test_add_paragraph_property_block_documents_add_no_empty_'
      'texts', (WidgetTester tester) async {
    final Random random = seededRandom(100521);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String text = <String>[
        for (
          int index = 0;
          index < random.nextInt(_largestBlockCount);
          index += 1
        )
          pickOne(random, <String>[
            '# a$index',
            'p$index',
            '---',
            '- l$index',
          ]),
      ].join('\n\n');

      await pumpMarkdown(tester, random, text);

      expect(readShownMarkdownTexts(tester), isNot(contains('')));
    }
  });

  testWidgets('test_add_paragraph_property_html_text_stays_before_the_next_'
      'block', (WidgetTester tester) async {
    final Random random = seededRandom(100522);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String word = randomPlainWord(random);
      final String heading = '${randomPlainWord(random)}h';

      await pumpMarkdown(tester, random, '<div>$word</div>\n\n# $heading');

      final double html = tester
          .getTopLeft(findShownMarkdownText('<div>$word</div>'))
          .dy;
      final double title = tester
          .getTopLeft(findShownMarkdownText(heading))
          .dy;
      expect(html, lessThan(title));
    }
  });

  testWidgets('test_add_paragraph_property_inline_runs_are_never_'
      'repeated', (WidgetTester tester) async {
    final Random random = seededRandom(100523);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int count = 1 + random.nextInt(_largestBlockCount);
      final List<String> htmlBlocks = <String>[
        for (int index = 0; index < count; index += 1) '<div>run$index</div>',
      ];
      final String text = <String>[
        for (int index = 0; index < count; index += 1)
          '${htmlBlocks[index]}\n\n# title$index',
      ].join('\n\n');

      await pumpMarkdown(tester, random, text);

      final List<String> shown = readShownMarkdownTexts(tester);
      for (final String html in htmlBlocks) {
        expect(
          shown.where((String text) => text.contains(html)),
          hasLength(1),
        );
      }
    }
  });

  testWidgets('test_build_block_property_every_heading_level_is_a_'
      'header', (WidgetTester tester) async {
    final Random random = seededRandom(100524);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int level = 1 + random.nextInt(6);
      final String title = '${randomPlainWord(random)}t';
      final String paragraph = '${randomPlainWord(random)}p';

      await pumpMarkdown(
        tester,
        random,
        '${'#' * level} $title\n\n$paragraph',
      );

      expect(_isHeader(tester, title), isTrue, reason: 'level $level');
      expect(_isHeader(tester, paragraph), isFalse);
    }
  });

  testWidgets('test_build_block_property_title_outranks_subheadings_and_'
      'paragraphs', (WidgetTester tester) async {
    final Random random = seededRandom(100525);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int level = 2 + random.nextInt(5);

      await pumpMarkdown(
        tester,
        random,
        '# title\n\n${'#' * level} sub\n\nbody words',
      );

      final Text title = tester.widget(findShownMarkdownText('title'));
      final Text sub = tester.widget(findShownMarkdownText('sub'));
      final Text body = tester.widget(findShownMarkdownText('body words'));
      expect(title.style!.fontSize, greaterThan(sub.style!.fontSize!));
      expect(sub.style!.fontWeight, FontWeight.w700);
      expect(body.style, AppTextStyles.body);
    }
  });

  testWidgets('test_build_block_property_rule_draws_a_thin_full_width_'
      'line', (WidgetTester tester) async {
    final Random random = seededRandom(100526);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String rule = pickOne(random, <String>['---', '***', '___']);

      await pumpMarkdown(tester, random, 'above words\n\n$rule\n\nbelow');

      final Finder line = find.byWidgetPredicate(
        (Widget widget) =>
            widget is Container && widget.color == AppColors.line,
      );
      final Rect area = tester.getRect(line);
      final Rect above = tester.getRect(findShownMarkdownText('above words'));
      final Rect below = tester.getRect(findShownMarkdownText('below'));
      final Rect view = tester.getRect(find.byType(MarkdownView));
      expect(area.height, AppBorders.thin);
      expect(area.width, closeTo(min(view.width, AppSizes.measure), 0.01));
      expect(area.top, greaterThanOrEqualTo(above.bottom));
      expect(area.bottom, lessThanOrEqualTo(below.top));
    }
  });

  testWidgets('test_build_code_block_property_shows_every_line_'
      'verbatim', (WidgetTester tester) async {
    final Random random = seededRandom(100527);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> lines = <String>[
        for (
          int index = 0;
          index < 1 + random.nextInt(_largestCodeLineCount);
          index += 1
        )
          _randomCodeLine(random),
      ];

      await pumpMarkdown(tester, random, '```\n${lines.join('\n')}\n```');

      expect(_readCodeLines(tester), lines);
    }
  });

  testWidgets('test_build_code_block_property_markup_inside_stays_'
      'literal', (WidgetTester tester) async {
    final Random random = seededRandom(100528);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String line = pickOne(random, _codeLinePieces);
      final String fence = pickOne(random, <String>['```', '~~~']);

      await pumpMarkdown(tester, random, '$fence\n$line\n$fence');

      expect(_readCodeLines(tester), <String>[line]);
      expect(findShownMarkdownText(line), findsOneWidget);
    }
  });

  testWidgets('test_build_code_block_property_indented_code_keeps_its_'
      'lines', (WidgetTester tester) async {
    final Random random = seededRandom(100529);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> lines = <String>[
        for (
          int index = 0;
          index < 1 + random.nextInt(_largestCodeLineCount);
          index += 1
        )
          '${' ' * random.nextInt(3)}${randomPlainWord(random)}',
      ];
      final String text = <String>[
        for (final String line in lines) '    $line',
      ].join('\n');

      await pumpMarkdown(tester, random, text);

      expect(_readCodeLines(tester), lines);
    }
  });
}
