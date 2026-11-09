import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/syntax_highlighting.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'syntax_highlighting_inputs.dart';

typedef _MultiLineCase = ({String extension, String delimiter});

const List<_MultiLineCase> _multiLineCases = <_MultiLineCase>[
  (extension: 'py', delimiter: '"""'),
  (extension: 'py', delimiter: "'''"),
  (extension: 'dart', delimiter: '"""'),
  (extension: 'dart', delimiter: "'''"),
  (extension: 'js', delimiter: '`'),
  (extension: 'ts', delimiter: '`'),
  (extension: 'go', delimiter: '`'),
  (extension: 'java', delimiter: '"""'),
  (extension: 'kt', delimiter: '"""'),
  (extension: 'swift', delimiter: '"""'),
];
const List<String> _singleLineExtensions = <String>[
  'rs',
  'c',
  'cpp',
  'rb',
  'sh',
  'json',
  'yaml',
];
const List<String> _insidePieces = <String>[
  "don't",
  "it's",
  '"',
  "'",
  'call(x)',
  'return',
  'def',
  'const',
  '#',
  '//',
  ' ',
  'é',
];

String _randomInsideText(Random random, String delimiter) {
  final StringBuffer text = StringBuffer();
  for (int index = 0; index < 1 + random.nextInt(6); index += 1) {
    text.write(pickOne(random, _insidePieces));
    text.write(' ');
  }
  text.write(randomHostileText(random).replaceAll('\n', ' '));
  return text
      .toString()
      .replaceAll(delimiter[0], ' ')
      .replaceAll(r'\', ' ')
      .replaceAll('`', ' ')
      .replaceAll('"""', ' ')
      .replaceAll("'''", ' ');
}

List<String> _buildStringLines(Random random, String delimiter) {
  return <String>[
    'value = $delimiter${_randomInsideText(random, delimiter)}',
    for (int line = 0; line < random.nextInt(4); line += 1)
      _randomInsideText(random, delimiter),
    '${_randomInsideText(random, delimiter)}$delimiter + after',
  ];
}

String _randomLineWithOpeners(Random random) {
  final String line = randomHostileCodeLine(random);
  if (random.nextBool()) {
    return line;
  }
  return '$line"""`\'\'\'';
}

List<SyntaxKind> _listKinds(List<SyntaxToken> tokens) {
  return <SyntaxKind>[for (final SyntaxToken token in tokens) token.kind];
}

void main() {
  test('test_highlight_lines_property_multi_line_strings_carry_on', () {
    final Random random = seededRandom(53901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _MultiLineCase multiLine = pickOne(random, _multiLineCases);
      final SyntaxLanguage language = findEverySyntaxLanguage(
        multiLine.extension,
      );
      final List<String> lines = _buildStringLines(
        random,
        multiLine.delimiter,
      );

      final List<List<SyntaxToken>> highlighted = highlightLines(
        lines,
        language,
      );

      for (int index = 1; index < lines.length - 1; index += 1) {
        expect(_listKinds(highlighted[index]), <SyntaxKind>[
          SyntaxKind.string,
        ], reason: lines[index]);
        expect(highlighted[index].single.text, lines[index]);
      }
      final SyntaxToken opened = highlighted.first.last;
      expect(opened.kind, SyntaxKind.string);
      expect(opened.text, startsWith(multiLine.delimiter));
      final SyntaxToken closed = highlighted.last.first;
      expect(closed.kind, SyntaxKind.string);
      expect(closed.text, endsWith(multiLine.delimiter));
      expect(joinTokenTexts(highlighted.last.sublist(1)), ' + after');
    }
  });

  test('test_highlight_lines_property_multi_line_text_never_changes', () {
    final Random random = seededRandom(53902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = randomSyntaxLanguage(random);
      final List<String> lines = <String>[
        for (int line = 0; line < random.nextInt(8); line += 1)
          _randomLineWithOpeners(random),
      ];

      final List<List<SyntaxToken>> highlighted = highlightLines(
        lines,
        language,
      );

      expect(highlighted, hasLength(lines.length));
      for (int index = 0; index < lines.length; index += 1) {
        expect(joinTokenTexts(highlighted[index]), lines[index]);
        for (final SyntaxToken token in highlighted[index]) {
          expect(token.text, isNotEmpty);
        }
      }
    }
  });

  test('test_highlight_lines_property_closed_string_frees_later_lines', () {
    final Random random = seededRandom(53903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _MultiLineCase multiLine = pickOne(random, _multiLineCases);
      final SyntaxLanguage language = findEverySyntaxLanguage(
        multiLine.extension,
      );
      final List<String> stringLines = _buildStringLines(
        random,
        multiLine.delimiter,
      );
      final String laterLine = _randomInsideText(random, multiLine.delimiter);

      final List<List<SyntaxToken>> highlighted = highlightLines(<String>[
        ...stringLines,
        laterLine,
      ], language);

      final List<SyntaxToken> alone = highlightLine(laterLine, language);
      expect(
        _listKinds(highlighted.last),
        _listKinds(alone),
        reason: laterLine,
      );
    }
  });

  test('test_find_string_closing_end_property_escaped_closer_stays_open', () {
    final Random random = seededRandom(53904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _MultiLineCase multiLine = pickOne(random, _multiLineCases);
      final SyntaxLanguage language = findEverySyntaxLanguage(
        multiLine.extension,
      );
      final String inside = _randomInsideText(random, multiLine.delimiter);
      final List<String> lines = <String>[
        'value = ${multiLine.delimiter}$inside',
        '$inside\\${multiLine.delimiter}',
        inside,
      ];

      final List<List<SyntaxToken>> highlighted = highlightLines(
        lines,
        language,
      );

      for (int index = 1; index < lines.length; index += 1) {
        expect(_listKinds(highlighted[index]), <SyntaxKind>[
          SyntaxKind.string,
        ], reason: lines[index]);
      }
    }
  });

  test('test_highlight_lines_property_single_line_quotes_never_carry', () {
    final Random random = seededRandom(53905);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = findEverySyntaxLanguage(
        pickOne(random, _singleLineExtensions),
      );
      final String openLine = 'value = "${_randomInsideText(random, '"')}';
      final String nextLine = _randomInsideText(random, '"');

      final List<List<SyntaxToken>> highlighted = highlightLines(<String>[
        openLine,
        nextLine,
      ], language);

      final List<SyntaxToken> alone = highlightLine(nextLine, language);
      expect(_listKinds(highlighted.last), _listKinds(alone));
    }
  });

  test('test_highlight_one_line_property_closed_on_one_line_is_one_token', () {
    final Random random = seededRandom(53906);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _MultiLineCase multiLine = pickOne(random, _multiLineCases);
      final SyntaxLanguage language = findEverySyntaxLanguage(
        multiLine.extension,
      );
      final String inside = _randomInsideText(random, multiLine.delimiter);
      final String literal =
          '${multiLine.delimiter}$inside'
          '${multiLine.delimiter}';

      final List<List<SyntaxToken>> highlighted = highlightLines(<String>[
        'x = $literal;',
        'after',
      ], language);

      final List<SyntaxToken> strings = <SyntaxToken>[
        for (final SyntaxToken token in highlighted.first)
          if (token.kind == SyntaxKind.string) token,
      ];
      expect(strings, hasLength(1));
      expect(strings.single.text, literal);
      expect(_listKinds(highlighted.last), <SyntaxKind>[SyntaxKind.plain]);
    }
  });

  test('test_syntax_language_constructor_property_keeps_multi_line_set', () {
    final Random random = seededRandom(53907);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Set<String> multiLine = <String>{
        for (int index = 0; index < random.nextInt(3); index += 1)
          pickOne(random, <String>['"""', "'''", '`']),
      };

      final SyntaxLanguage language = SyntaxLanguage(
        keywords: const <String>{},
        stringDelimiters: const <String>{'"'},
        multiLineStringDelimiters: multiLine,
        comments: pickOne(random, CommentStyle.values),
      );

      expect(language.multiLineStringDelimiters, same(multiLine));
    }
  });

  test('test_find_syntax_language_property_multi_line_opens_with_a_quote', () {
    for (final String extension in everySyntaxExtension) {
      final SyntaxLanguage language = findEverySyntaxLanguage(extension);

      for (final String delimiter in language.multiLineStringDelimiters) {
        expect(language.stringDelimiters, contains(delimiter[0]));
        expect(delimiter.split('').toSet(), <String>{
          delimiter[0],
        }, reason: '$extension $delimiter');
      }
    }
  });
}
