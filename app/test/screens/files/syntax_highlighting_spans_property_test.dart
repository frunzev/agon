import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/syntax_highlighting.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';

import '../../support/random_inputs.dart';
import 'syntax_highlighting_inputs.dart';

const List<String> _slashExtensions = <String>['ts', 'dart', 'go', 'c', 'rs'];
const List<String> _codeWords = <String>[
  'x',
  'return',
  'call(y)',
  "it's",
  '1',
  ' ',
  'é',
];

String _randomCode(Random random) {
  final StringBuffer code = StringBuffer();
  for (int index = 0; index < 1 + random.nextInt(5); index += 1) {
    code.write(pickOne(random, _codeWords));
    code.write(' ');
  }
  return code.toString();
}

String _randomCommentWords(Random random) {
  return _randomCode(random).replaceAll("'", ' ');
}

List<SyntaxKind> _listKinds(List<SyntaxToken> tokens) {
  return <SyntaxKind>[for (final SyntaxToken token in tokens) token.kind];
}

SyntaxLanguage _randomSlashLanguage(Random random) {
  return findEverySyntaxLanguage(pickOne(random, _slashExtensions));
}

void main() {
  test('test_find_opened_span_property_block_comment_carries_plain', () {
    final Random random = seededRandom(54901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = _randomSlashLanguage(random);
      final List<String> lines = <String>[
        'x /* ${_randomCommentWords(random)}',
        _randomCode(random),
        '${_randomCommentWords(random)} */',
      ];

      final List<List<SyntaxToken>> highlighted = highlightLines(
        lines,
        language,
      );

      expect(_listKinds(highlighted[1]), <SyntaxKind>[SyntaxKind.plain]);
      expect(_listKinds(highlighted[2]), <SyntaxKind>[SyntaxKind.plain]);
    }
  });

  test('test_find_opened_span_property_only_own_delimiters_carry', () {
    final Random random = seededRandom(54902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String extension = pickOne(random, everySyntaxExtension);
      final SyntaxLanguage language = findEverySyntaxLanguage(extension);
      final String delimiter = pickOne(random, <String>['"""', "'''", '`']);
      final String nextLine = _randomCode(random).replaceAll("'", ' ');

      final List<List<SyntaxToken>> highlighted = highlightLines(<String>[
        'x = $delimiter',
        nextLine,
      ], language);

      final bool isCarried = language.multiLineStringDelimiters.contains(
        delimiter,
      );
      final List<SyntaxKind> alone = _listKinds(
        highlightLine(nextLine, language),
      );
      expect(
        _listKinds(highlighted.last),
        isCarried ? <SyntaxKind>[SyntaxKind.string] : alone,
        reason: '$extension $delimiter',
      );
    }
  });

  test('test_find_opened_span_property_closed_only_by_its_own_kind', () {
    final Random random = seededRandom(54903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = findEverySyntaxLanguage(
        pickOne(random, <String>['py', 'dart']),
      );
      final bool opensDouble = random.nextBool();
      final String opening = opensDouble ? '"""' : "'''";
      final String other = opensDouble ? "'''" : '"""';

      final List<List<SyntaxToken>> highlighted = highlightLines(<String>[
        'x = $opening',
        'a $other b',
        'c',
      ], language);

      expect(_listKinds(highlighted[1]), <SyntaxKind>[SyntaxKind.string]);
      expect(_listKinds(highlighted[2]), <SyntaxKind>[SyntaxKind.string]);
    }
  });

  test('test_find_span_end_property_comments_ignore_backslashes', () {
    final Random random = seededRandom(54904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = _randomSlashLanguage(random);
      final String code = '"${_randomCommentWords(random)}"';

      final List<List<SyntaxToken>> highlighted = highlightLines(<String>[
        '/* open',
        'text \\*/ $code',
      ], language);

      final List<SyntaxToken> strings = <SyntaxToken>[
        for (final SyntaxToken token in highlighted.last)
          if (token.kind == SyntaxKind.string) token,
      ];
      expect(strings.single.text, code);
    }
  });

  test('test_find_span_end_property_strings_honor_backslashes', () {
    final Random random = seededRandom(54905);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = findEverySyntaxLanguage(
        pickOne(random, <String>['js', 'go']),
      );

      final List<List<SyntaxToken>> highlighted = highlightLines(<String>[
        'x = `open',
        '${_randomCode(random)}\\`',
        _randomCode(random),
      ], language);

      expect(_listKinds(highlighted[1]), <SyntaxKind>[SyntaxKind.string]);
      expect(_listKinds(highlighted[2]), <SyntaxKind>[SyntaxKind.string]);
    }
  });

  test('test_find_span_end_property_closing_frees_the_rest_of_line', () {
    final Random random = seededRandom(54906);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = findEverySyntaxLanguage('py');
      final String after = _randomCode(random).replaceAll("'", ' ');

      final List<List<SyntaxToken>> highlighted = highlightLines(<String>[
        'x = """open',
        'end"""$after',
      ], language);

      expect(highlighted.last.first.text, 'end"""');
      expect(highlighted.last.first.kind, SyntaxKind.string);
      expect(
        _listKinds(highlighted.last.sublist(1)),
        _listKinds(highlightLine(after, language)),
      );
    }
  });

  test('test_find_comment_closing_end_property_closer_at_line_start', () {
    final Random random = seededRandom(54907);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = _randomSlashLanguage(random);

      final List<List<SyntaxToken>> highlighted = highlightLines(<String>[
        '/*',
        '*/"s"',
      ], language);

      expect(highlighted.last.first.text, '*/');
      expect(highlighted.last.last.text, '"s"');
      expect(highlighted.last.last.kind, SyntaxKind.string);
    }
  });

  test('test_find_comment_closing_end_property_no_closer_all_plain', () {
    final Random random = seededRandom(54908);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = _randomSlashLanguage(random);
      final String inside = '${_randomCode(random)} "q" return';

      final List<List<SyntaxToken>> highlighted = highlightLines(<String>[
        '/* a',
        inside,
      ], language);

      expect(_listKinds(highlighted.last), <SyntaxKind>[SyntaxKind.plain]);
      expect(highlighted.last.single.text, inside);
    }
  });

  test('test_find_comment_closing_end_property_first_closer_wins', () {
    final Random random = seededRandom(54909);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = _randomSlashLanguage(random);
      final int closerCount = 2 + random.nextInt(3);
      final String closers = List<String>.filled(closerCount, '*/ "z"').join();

      final List<List<SyntaxToken>> highlighted = highlightLines(<String>[
        '/* a',
        closers,
      ], language);

      final int stringCount = <SyntaxToken>[
        for (final SyntaxToken token in highlighted.last)
          if (token.kind == SyntaxKind.string) token,
      ].length;
      expect(stringCount, closerCount);
    }
  });

  test('test_find_string_closing_end_property_closer_first_on_line', () {
    final Random random = seededRandom(54910);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = findEverySyntaxLanguage(
        pickOne(random, <String>['py', 'dart', 'kt', 'swift']),
      );

      final List<List<SyntaxToken>> highlighted = highlightLines(<String>[
        'x = """',
        '""" + y',
      ], language);

      expect(highlighted.last.first.text, '"""');
      expect(highlighted.last.first.kind, SyntaxKind.string);
      expect(joinTokenTexts(highlighted.last), '""" + y');
    }
  });

  test('test_find_string_closing_end_property_trailing_escape_stays_open', () {
    final Random random = seededRandom(54911);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = findEverySyntaxLanguage(
        pickOne(random, <String>['js', 'ts', 'go']),
      );
      final String empty = random.nextBool() ? '' : ' ';

      final List<List<SyntaxToken>> highlighted = highlightLines(<String>[
        'x = `a\\',
        empty,
        'b',
      ], language);

      expect(_listKinds(highlighted.last), <SyntaxKind>[SyntaxKind.string]);
      expect(highlighted[1], empty.isEmpty ? isEmpty : hasLength(1));
    }
  });
}
