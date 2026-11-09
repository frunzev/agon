import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../support/random_inputs.dart';
import 'markdown_github_inputs.dart';
import 'markdown_view_inputs.dart';

const int _mostColumns = 8;
const int _deepestIndentedLevel = 6;

void main() {
  testWidgets('test_build_table_cell_property_header_cells_are_bold', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105807);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TableCells cells = randomTableCells(
        random,
        1 + random.nextInt(_mostColumns),
      );

      await pumpMarkdown(tester, random, renderMarkdownTable(cells));

      for (int row = 0; row < cells.length; row += 1) {
        final Text cell = tester.widget(findShownMarkdownText(cells[row][0]));
        final FontWeight? weight = cell.style?.fontWeight;
        expect(weight == FontWeight.w700, row == 0, reason: 'row $row');
      }
    }
  });

  testWidgets('test_build_table_cell_property_inline_markup_is_styled_not_'
      'shown', (WidgetTester tester) async {
    final Random random = seededRandom(105808);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String word = randomPlainWord(random);
      final String markup = pickOne(random, <String>['**', '_', '`', '~~']);
      final String table = '| h |\n|---|\n| $markup$word$markup |';

      await pumpMarkdown(tester, random, table);

      expect(findShownMarkdownText(word), findsOneWidget);
      expect(hasMarkupStyle(findCellWordStyle(tester, word), markup), isTrue);
    }
  });

  testWidgets('test_build_table_cell_property_empty_cells_keep_their_'
      'place', (WidgetTester tester) async {
    final Random random = seededRandom(105809);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int columns = 2 + random.nextInt(_mostColumns - 1);
      final int emptyColumn = random.nextInt(columns);
      final String header = <String>[
        for (int column = 0; column < columns; column += 1) 'h$column',
      ].join(' | ');
      final String body = <String>[
        for (int column = 0; column < columns; column += 1)
          if (column == emptyColumn) ' ' else 'b$column',
      ].join(' | ');

      await pumpMarkdown(
        tester,
        random,
        '| $header |\n|${List<String>.filled(columns, '-').join('|')}|\n'
        '| $body |',
      );

      for (int column = 0; column < columns; column += 1) {
        final Finder bodyCell = findShownMarkdownText('b$column');
        expect(bodyCell, column == emptyColumn ? findsNothing : findsOne);
      }
      final Table table = tester.widget(find.byType(Table));
      expect(table.children.last.children, hasLength(columns));
    }
  });

  testWidgets('test_build_block_property_a_table_keeps_its_place_in_the_'
      'flow', (WidgetTester tester) async {
    final Random random = seededRandom(105810);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String before = 'before${randomPlainWord(random)}';
      final String after = 'after${randomPlainWord(random)}';
      final TableCells cells = randomTableCells(random, 2);

      await pumpMarkdown(
        tester,
        random,
        '$before\n\n${renderMarkdownTable(cells)}\n\n$after',
      );

      final Rect table = tester.getRect(find.byType(Table));
      expect(
        tester.getRect(findShownMarkdownText(before)).bottom,
        lessThanOrEqualTo(table.top),
      );
      expect(
        tester.getRect(findShownMarkdownText(after)).top,
        greaterThanOrEqualTo(table.bottom),
      );
    }
  });

  testWidgets('test_build_block_property_footnotes_read_as_a_numbered_'
      'list', (WidgetTester tester) async {
    final Random random = seededRandom(105811);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String note = 'note${randomPlainWord(random)}';
      final String label = pickOne(random, <String>['1', 'a', 'note']);

      await pumpMarkdown(tester, random, 'text[^$label]\n\n[^$label]: $note');

      expect(findShownMarkdownText('1.'), findsOneWidget);
      expect(find.textContaining(note, findRichText: true), findsOneWidget);
      expect(
        readShownMarkdownTexts(tester).where((String t) => t.contains('[^')),
        isEmpty,
      );
    }
  });

  testWidgets('test_build_block_property_quotes_stop_stepping_in_past_the_'
      'cap', (WidgetTester tester) async {
    final Random random = seededRandom(105812);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int depth = random.nextInt(_deepestIndentedLevel * 3);

      await pumpMarkdown(tester, random, 'outside\n\n${'> ' * depth}inside');

      final double outside = tester
          .getTopLeft(findShownMarkdownText('outside'))
          .dx;
      final double inside = tester
          .getTopLeft(findShownMarkdownText('inside'))
          .dx;
      final int indentedLevels = min(depth, _deepestIndentedLevel);
      expect(
        inside - outside,
        closeTo(indentedLevels * AppSpacing.space5, 0.01),
      );
    }
  });

  testWidgets('test_paragraph_fallback_table_syntax_parse_property_'
      'mismatched_link_rows_read_as_text', (WidgetTester tester) async {
    final Random random = seededRandom(105813);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String word = randomPlainWord(random);
      final String start = pickOne(random, <String>[
        '[$word](https://example.com "title")',
        '[$word]',
        '[$word]: https://example.com',
        '![$word](image.png)',
      ]);
      final int headerCells = 2 + random.nextInt(3);
      final int delimiterCells = headerCells - 1;
      final String header = '$start ${' | x' * (headerCells - 1)} |';
      final String delimiter =
          '|${List<String>.filled(delimiterCells, '---').join('|')}|';

      await pumpMarkdown(tester, random, '$header\n$delimiter');

      expect(find.byType(Table), findsNothing);
      expect(readShownMarkdownTexts(tester).join(' '), contains('|'));
    }
  });

  testWidgets('test_paragraph_fallback_table_syntax_parse_property_real_'
      'tables_stay_tables', (WidgetTester tester) async {
    final Random random = seededRandom(105814);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TableCells cells = randomTableCells(
        random,
        1 + random.nextInt(_mostColumns),
      );
      final String link = '[${randomPlainWord(random)}](https://example.com)';
      final String table = renderMarkdownTable(<List<String>>[
        <String>[link, ...cells.first.skip(1)],
        ...cells.skip(1),
      ]);

      await pumpMarkdown(tester, random, table);

      final Table shown = tester.widget(find.byType(Table));
      expect(shown.children, hasLength(cells.length));
    }
  });

  testWidgets('test_paragraph_fallback_table_syntax_parse_property_any_'
      'pipes_and_links_keep_every_word', (WidgetTester tester) async {
    final Random random = seededRandom(105815);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final List<String> words = <String>[
        for (int index = 0; index < 1 + random.nextInt(4); index += 1)
          'w$index${randomPlainWord(random)}',
      ];
      final List<String> lines = <String>[
        for (final String word in words)
          pickOne(random, <String>[
            '[$word] | a |',
            '| $word |',
            '|---|---|',
            '[$word](u "t") | b | c |',
            '$word |',
          ]),
      ];

      await pumpMarkdown(tester, random, lines.join('\n'));

      final String shown = readShownMarkdownTexts(tester).join(' ');
      for (final String word in words) {
        if (lines.any((String line) => line.contains(word))) {
          expect(shown, contains(word));
        }
      }
    }
  });
}
