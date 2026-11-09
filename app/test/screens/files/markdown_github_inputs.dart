import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/theme/app_typography.dart';

import 'markdown_view_inputs.dart';

const int _mostRows = 6;

typedef TableCells = List<List<String>>;

TableCells randomTableCells(Random random, int columns) {
  final int rows = 1 + random.nextInt(_mostRows);
  return <List<String>>[
    for (int row = 0; row < rows; row += 1)
      <String>[
        for (int column = 0; column < columns; column += 1)
          'c${row}x$column${randomPlainWord(random)}',
      ],
  ];
}

String renderMarkdownTable(TableCells cells) {
  final int columns = cells.first.length;
  final List<String> lines = <String>[
    '| ${cells.first.join(' | ')} |',
    '|${List<String>.filled(columns, '---').join('|')}|',
    for (final List<String> row in cells.skip(1)) '| ${row.join(' | ')} |',
  ];
  return lines.join('\n');
}

TextStyle findCellWordStyle(WidgetTester tester, String word) {
  final Text cell = tester.widget(findShownMarkdownText(word));
  return mergeWordStyle(cell.textSpan!, word, const TextStyle())!;
}

TextStyle? mergeWordStyle(InlineSpan span, String word, TextStyle above) {
  if (span is! TextSpan) {
    return null;
  }
  final TextStyle merged = above.merge(span.style);
  if (span.text == word) {
    return merged;
  }
  for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
    final TextStyle? found = mergeWordStyle(child, word, merged);
    if (found != null) {
      return found;
    }
  }
  return null;
}

bool hasMarkupStyle(TextStyle style, String markup) {
  return switch (markup) {
    '**' => style.fontWeight == FontWeight.w700,
    '_' => style.fontStyle == FontStyle.italic,
    '`' => style.fontFamily == AppFontFamilies.monospace,
    _ => style.decoration == TextDecoration.lineThrough,
  };
}
