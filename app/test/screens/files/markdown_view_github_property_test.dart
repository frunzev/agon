import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../support/random_inputs.dart';
import 'markdown_github_inputs.dart';
import 'markdown_view_inputs.dart';

const int _mostColumns = 8;
const String _checkedBox = '☑';

String _renderTaskLine(
  Random random, {
  required bool isChecked,
  required int index,
}) {
  final String box = isChecked ? pickOne(random, <String>['x', 'X']) : ' ';
  return '- [$box] task$index';
}

String _makeRagged(Random random, String line) {
  if (random.nextBool()) {
    return '$line extra |';
  }
  return line.split('|')[1];
}

void main() {
  testWidgets('test_markdown_view_build_property_github_tables_show_cells_'
      'not_pipes', (WidgetTester tester) async {
    final Random random = seededRandom(105801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TableCells cells = randomTableCells(
        random,
        1 + random.nextInt(_mostColumns),
      );

      await pumpMarkdown(tester, random, renderMarkdownTable(cells));

      final List<String> shown = readShownMarkdownTexts(tester);
      expect(shown.where((String text) => text.contains('|')), isEmpty);
      for (final List<String> row in cells) {
        for (final String cell in row) {
          expect(findShownMarkdownText(cell), findsOneWidget, reason: cell);
        }
      }
    }
  });

  testWidgets('test_markdown_view_build_property_strikethrough_shows_no_'
      'tildes', (WidgetTester tester) async {
    final Random random = seededRandom(105802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String before = randomPlainWord(random);
      final String struck = randomPlainWord(random);
      final String tildes = pickOne(random, <String>['~', '~~']);

      await pumpMarkdown(tester, random, '$before $tildes$struck$tildes end');

      expect(readShownMarkdownTexts(tester), <String>['$before $struck end']);
    }
  });

  testWidgets('test_markdown_view_build_property_task_items_show_boxes_not_'
      'brackets', (WidgetTester tester) async {
    final Random random = seededRandom(105803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int count = 1 + random.nextInt(5);
      final List<bool> checks = <bool>[
        for (int index = 0; index < count; index += 1) random.nextBool(),
      ];
      final String text = <String>[
        for (int index = 0; index < checks.length; index += 1)
          _renderTaskLine(random, isChecked: checks[index], index: index),
      ].join('\n');

      await pumpMarkdown(tester, random, text);

      final List<String> shown = readShownMarkdownTexts(tester);
      expect(shown.where((String text) => text.contains('[')), isEmpty);
      for (int index = 0; index < checks.length; index += 1) {
        expect(findShownMarkdownText('task$index'), findsOneWidget);
      }
      expect(
        shown.where((String text) => text == _checkedBox),
        hasLength(checks.where((bool isChecked) => isChecked).length),
      );
    }
  });

  testWidgets('test_build_markdown_table_property_cells_read_in_row_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TableCells cells = randomTableCells(
        random,
        1 + random.nextInt(_mostColumns),
      );

      await pumpMarkdown(tester, random, renderMarkdownTable(cells));

      for (int row = 0; row < cells.length; row += 1) {
        for (int column = 0; column < cells[row].length; column += 1) {
          final Rect cell = tester.getRect(
            findShownMarkdownText(cells[row][column]),
          );
          if (column > 0) {
            final Rect left = tester.getRect(
              findShownMarkdownText(cells[row][column - 1]),
            );
            expect(left.left, lessThan(cell.left));
          }
          if (row > 0) {
            final Rect above = tester.getRect(
              findShownMarkdownText(cells[row - 1][column]),
            );
            expect(above.top, lessThan(cell.top));
          }
        }
      }
    }
  });

  testWidgets(
    'test_build_markdown_table_property_wide_tables_fit_the_window',
    (WidgetTester tester) async {
      final Random random = seededRandom(105805);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TableCells cells = randomTableCells(random, _mostColumns);

        final double width = await pumpMarkdown(
          tester,
          random,
          renderMarkdownTable(cells),
        );

        final Rect table = tester.getRect(find.byType(Table));
        expect(table.left, greaterThanOrEqualTo(0));
        expect(table.right, lessThanOrEqualTo(min(width, AppSizes.measure)));
      }
    },
  );

  testWidgets('test_build_markdown_table_property_ragged_rows_keep_the_header_'
      'columns', (WidgetTester tester) async {
    final Random random = seededRandom(105806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final int columns = 1 + random.nextInt(_mostColumns);
      final TableCells cells = randomTableCells(random, columns);
      final List<String> lines = renderMarkdownTable(cells).split('\n');
      final String ragged = <String>[
        ...lines.take(2),
        for (final String line in lines.skip(2)) _makeRagged(random, line),
      ].join('\n');

      await pumpMarkdown(tester, random, ragged);

      final Table table = tester.widget(find.byType(Table));
      for (final TableRow row in table.children) {
        expect(row.children, hasLength(columns));
      }
    }
  });
}
