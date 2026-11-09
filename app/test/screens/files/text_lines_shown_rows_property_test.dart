import 'dart:math';

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/code_view.dart';
import 'package:agent_orchestration/screens/files/text_lines.dart';

import '../../support/random_inputs.dart';
import 'shown_code_lines.dart';

const List<String> _lineBreaks = <String>[
  '\n',
  '\r\n',
  '\r',
  '\u0085',
  '\u2028',
  '\u2029',
];
const List<String> _charactersFlutterBreaksAt = <String>[
  '\n',
  '\r',
  '\u000B',
  '\u000C',
  '\u0085',
  '\u2028',
  '\u2029',
];
const List<String> _pageBreaks = <String>['\u000B', '\u000C'];
const int _lastControlCodeUnit = 0x9F;
const int _largestPieceCount = 12;

String _randomLineWithoutBreaks(Random random) {
  String line = randomText(random);
  for (final String character in _charactersFlutterBreaksAt) {
    line = line.replaceAll(character, '');
  }
  return line;
}

String _randomControlCharacter(Random random) {
  final int codeUnit = random.nextInt(_lastControlCodeUnit + 1);
  return String.fromCharCode(codeUnit);
}

String _randomTextFullOfControls(Random random) {
  final int pieceCount = random.nextInt(_largestPieceCount);
  final StringBuffer text = StringBuffer();
  for (int index = 0; index < pieceCount; index += 1) {
    final String piece = pickOne(random, <String>[
      randomText(random),
      _randomControlCharacter(random),
      pickOne(random, _charactersFlutterBreaksAt),
      pickOne(random, _lineBreaks),
    ]);
    text.write(piece);
  }
  return text.toString();
}

int _countDrawnRows(RenderParagraph paragraph) {
  final TextPainter painter = TextPainter(
    text: paragraph.text,
    textDirection: TextDirection.ltr,
  );
  painter.layout();
  final int rowCount = painter.computeLineMetrics().length;
  painter.dispose();
  return rowCount;
}

int _countCharacters(String text, List<String> characters) {
  int count = 0;
  for (final String character in characters) {
    count += character.allMatches(text).length;
  }
  return count;
}

void main() {
  test('test_split_text_lines_property_every_unicode_line_break_splits', () {
    final Random random = seededRandom(1060601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int lineCount = 1 + random.nextInt(8);
      final List<String> lines = <String>[
        for (int index = 0; index < lineCount; index += 1)
          'a${_randomLineWithoutBreaks(random)}',
      ];
      final StringBuffer text = StringBuffer(lines.first);
      for (final String line in lines.skip(1)) {
        text.write('${pickOne(random, _lineBreaks)}$line');
      }

      expect(splitTextLines(text.toString()), lines, reason: '$text');
    }
  });

  test('test_split_text_lines_property_no_line_keeps_a_flutter_break', () {
    final Random random = seededRandom(1060602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = _randomTextFullOfControls(random);

      final List<String> lines = splitTextLines(text);

      for (final String line in lines) {
        for (final String character in _charactersFlutterBreaksAt) {
          expect(line.contains(character), isFalse, reason: text);
        }
      }
    }
  });

  test('test_split_text_lines_property_page_breaks_stay_visible_in_line', () {
    final Random random = seededRandom(1060603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String before = _randomLineWithoutBreaks(random);
      final String after = _randomLineWithoutBreaks(random);
      final String pageBreak = pickOne(random, _pageBreaks);

      final List<String> lines = splitTextLines('$before$pageBreak$after');

      expect(lines, hasLength(1));
      expect(lines.single.startsWith(before), isTrue);
      expect(lines.single.endsWith(after), isTrue);
      expect(lines.single.length, greaterThan('$before$after'.length));
      expect(_countCharacters(lines.single, _pageBreaks), 0);
    }
  });

  testWidgets('test_split_text_lines_property_numbered_rows_draw_as_one_row', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1060604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String text = _randomTextFullOfControls(random);
      await pumpCodeView(
        tester,
        random,
        CodeView(text: text, language: randomSyntaxLanguage(random)),
      );

      final List<ShownCodeLine> shownLines = findShownCodeLines();

      expect(shownLines, hasLength(splitTextLines(text).length));
      for (final ShownCodeLine line in shownLines) {
        final int drawnRowCount = _countDrawnRows(line.code);
        expect(drawnRowCount, lessThanOrEqualTo(1), reason: text);
      }
      expect(tester.takeException(), isNull);
    }
  });
}
