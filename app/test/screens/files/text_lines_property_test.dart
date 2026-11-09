import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/text_lines.dart';

import '../../support/random_inputs.dart';

const List<String> _lineBreaks = <String>['\n', '\r\n', '\r'];
const List<String> _unicodeLineSeparators = <String>[
  '\u2028',
  '\u2029',
  '\u0085',
  '\u000B',
  '\u000C',
];
const List<String> _pageBreaks = <String>['\u000B', '\u000C'];
final RegExp _everyLineBreak = RegExp('[\r\n\u0085\u2028\u2029]');
const int _hugeLineCount = 200000;

String _randomLine(Random random) {
  final String text = randomText(random);
  return text.replaceAll(_everyLineBreak, '');
}

List<String> _randomLines(Random random) {
  final int count = 1 + random.nextInt(8);
  return <String>[
    for (int index = 0; index < count; index += 1) _randomLine(random),
  ];
}

String _appendLineBreak(Random random, String text) {
  final String lineBreak = pickOne(random, _lineBreaks);
  final bool wouldJoinTwoBreaks = text.endsWith('\r') && lineBreak == '\n';
  if (wouldJoinTwoBreaks) {
    return '$text\r';
  }
  return '$text$lineBreak';
}

String _joinWithRandomBreaks(Random random, List<String> lines) {
  String text = lines.first;
  for (final String line in lines.skip(1)) {
    text = '${_appendLineBreak(random, text)}$line';
  }
  final bool needsFinalBreak = lines.last.isEmpty || random.nextBool();
  if (needsFinalBreak) {
    return _appendLineBreak(random, text);
  }
  return text;
}

int _countLineBreaks(String text) {
  return RegExp('\r\n|\r|\n').allMatches(text).length;
}

void main() {
  test('test_split_text_lines_property_mixed_and_lone_carriage_returns_'
      'round_trip', () {
    final Random random = seededRandom(1020201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> lines = _randomLines(random);
      final String text = _joinWithRandomBreaks(random, lines);

      expect(splitTextLines(text), lines, reason: text);
    }
  });

  test('test_split_text_lines_property_counts_one_line_per_break', () {
    final Random random = seededRandom(1020202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = <String>[
        for (int index = 0; index < random.nextInt(10); index += 1)
          pickOne(random, <String>[..._lineBreaks, _randomLine(random)]),
      ].join();
      final int breakCount = _countLineBreaks(text);
      final bool endsWithBreak = text.endsWith('\n') || text.endsWith('\r');
      final int expectedCount = text.isEmpty
          ? 0
          : breakCount + (endsWithBreak ? 0 : 1);

      final List<String> lines = splitTextLines(text);

      expect(lines, hasLength(expectedCount), reason: text);
      for (final String line in lines) {
        expect(line.contains('\r'), isFalse);
        expect(line.contains('\n'), isFalse);
      }
    }
  });

  test('test_split_text_lines_property_unicode_separators_break_or_'
      'show_a_mark', () {
    final Random random = seededRandom(1020203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String separator = pickOne(random, _unicodeLineSeparators);
      final String line =
          'a${_randomLine(random)}${separator}b${_randomLine(random)}';
      final bool isPageBreak = _pageBreaks.contains(separator);
      final int expectedLineCount = isPageBreak ? 2 : 4;

      final List<String> lines = splitTextLines('$line\n$line');

      expect(lines, hasLength(expectedLineCount), reason: line);
      expect(lines.join().contains(separator), isFalse, reason: line);
    }
  });

  test('test_split_text_lines_property_huge_files_stay_line_exact', () {
    final List<String> lines = <String>[
      for (int index = 0; index < _hugeLineCount; index += 1) 'line $index',
    ];
    final String text = '${lines.join('\r\n')}\r\n';

    final List<String> splitLines = splitTextLines(text);

    expect(splitLines, hasLength(_hugeLineCount));
    expect(splitLines.first, 'line 0');
    expect(splitLines.last, 'line ${_hugeLineCount - 1}');
    expect(() => splitLines.add('more'), throwsUnsupportedError);
  });
}
