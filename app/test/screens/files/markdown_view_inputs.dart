import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/markdown_view.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const List<String> _hostileMarkdownPieces = <String>[
  '# Title\n\n',
  '###### Small\n\n',
  'Setext\n======\n\n',
  '- item\n  - nested\n    - deeper\n\n',
  '3. third\n4. fourth\n\n',
  '```sh\nnpm install\n```\n\n',
  '    indented code\n\n',
  '`inline`',
  '*soft* _soft_',
  '**bold** __bold__',
  '[link](https://example.com "title")',
  '<https://auto.link>',
  '![alt text](image.png)',
  '[![badge](badge.svg)](https://ci.example)',
  '> quoted\n> > twice\n\n',
  '---\n\n',
  '| a | b |\n|---|---|\n| 1 | 2 |\n\n',
  '<div>block html</div>\n\n',
  '<script>alert(1)</script>',
  '<!-- comment -->',
  'Tom &amp; Jerry &copy; &#169;',
  r'\*escaped\* \\',
  'line  \nbreak',
  '\n\n',
  'שלום עולם مرحبا',
  '\u202eright to left\u202c',
  '\u{1F469}\u{200D}\u{1F4BB}',
];
const int _largestPieceCount = 12;
const int _longLineLength = 600;

String randomHostileMarkdown(Random random) {
  final StringBuffer text = StringBuffer();
  final int pieceCount = random.nextInt(_largestPieceCount);
  for (int index = 0; index < pieceCount; index += 1) {
    text.write(_randomHostilePiece(random));
  }
  return text.toString();
}

String _randomHostilePiece(Random random) {
  return switch (random.nextInt(6)) {
    0 => randomHostileText(random),
    1 => pickOne(random, <String>['x', 'word ', '`', '|']) * _longLineLength,
    _ => pickOne(random, _hostileMarkdownPieces),
  };
}

String randomPlainWord(Random random) {
  final int length = 1 + random.nextInt(8);
  final StringBuffer word = StringBuffer();
  for (int index = 0; index < length; index += 1) {
    word.writeCharCode('a'.codeUnitAt(0) + random.nextInt(26));
  }
  return word.toString();
}

Future<double> pumpMarkdown(
  WidgetTester tester,
  Random random,
  String text,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: MarkdownView(text: text),
  );
  expect(tester.takeException(), isNull, reason: 'width $width: $text');
  return width;
}

Finder findMarkdownTexts() {
  return find.descendant(
    of: find.byType(MarkdownView),
    matching: find.byType(Text),
  );
}

String readPlainText(Text text) {
  final String? data = text.data;
  if (data != null) {
    return data;
  }
  return text.textSpan!.toPlainText();
}

List<String> readShownMarkdownTexts(WidgetTester tester) {
  return <String>[
    for (final Element element in findMarkdownTexts().evaluate())
      readPlainText(element.widget as Text),
  ];
}

Finder findShownMarkdownText(String plainText) {
  return find.descendant(
    of: find.byType(MarkdownView),
    matching: find.byWidgetPredicate(
      (Widget widget) => widget is Text && readPlainText(widget) == plainText,
    ),
  );
}
