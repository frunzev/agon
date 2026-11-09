import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/syntax_highlighting.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';

import '../../support/random_inputs.dart';
import 'syntax_highlighting_inputs.dart';

const String _escape = r'\';
const String _asciiWordStart = r'abcXYZ_$';
const String _asciiWordRest = r'abcXYZ_$019';
const List<String> _foreignLetters = <String>['é', 'ñ', 'Ω', 'ж', 'e\u0301'];
const List<String> _notCallingFollowers = <String>[
  ' (',
  '.',
  ';',
  ' ',
  '[',
  '',
];
const int _largestWordLength = 8;

String _randomStringBody(Random random, String delimiter) {
  final StringBuffer body = StringBuffer();
  final int length = random.nextInt(12);
  for (int index = 0; index < length; index += 1) {
    final String piece = randomHostileCodeLine(random);
    final String safePiece = piece
        .replaceAll(_escape, '$_escape$_escape')
        .replaceAll(delimiter, '$_escape$delimiter');
    body.write(safePiece);
  }
  return body.toString();
}

String _randomAsciiWord(Random random) {
  final StringBuffer word = StringBuffer(
    _asciiWordStart[random.nextInt(_asciiWordStart.length)],
  );
  final int restLength = random.nextInt(_largestWordLength);
  for (int index = 0; index < restLength; index += 1) {
    word.write(_asciiWordRest[random.nextInt(_asciiWordRest.length)]);
  }
  return word.toString();
}

List<SyntaxToken> _markedWords(List<SyntaxToken> tokens) {
  return <SyntaxToken>[
    for (final SyntaxToken token in tokens)
      if (token.kind == SyntaxKind.keyword ||
          token.kind == SyntaxKind.function)
        token,
  ];
}

void main() {
  test('test_find_string_end_property_escaped_delimiters_stay_inside', () {
    final Random random = seededRandom(733001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = randomSyntaxLanguage(random);
      final String delimiter = pickOne(
        random,
        language.stringDelimiters.toList(),
      );
      final String literal =
          '$delimiter${_randomStringBody(random, delimiter)}$delimiter';
      final List<SyntaxToken> tokens = highlightLine(literal, language);

      expect(tokens.length, 1, reason: literal);
      expect(tokens.single.kind, SyntaxKind.string, reason: literal);
    }
  });

  test('test_find_string_end_property_open_string_runs_to_line_end', () {
    final Random random = seededRandom(733002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = randomSyntaxLanguage(random);
      final String delimiter = pickOne(
        random,
        language.stringDelimiters.toList(),
      );
      final String opening =
          '= $delimiter${_randomStringBody(random, delimiter)}';
      final String line = random.nextBool() ? opening : '$opening$_escape';
      final List<SyntaxToken> tokens = highlightLine(line, language);

      expect(tokens.last.kind, SyntaxKind.string, reason: line);
      expect(tokens.last.text, line.substring(2), reason: line);
    }
  });

  test('test_find_string_end_property_closes_at_an_unescaped_twin', () {
    final Random random = seededRandom(733003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String line = randomHostileCodeLine(random);
      final SyntaxLanguage language = randomSyntaxLanguage(random);
      final List<SyntaxToken> tokens = highlightLine(line, language);

      for (int index = 0; index < tokens.length - 1; index += 1) {
        final String text = tokens[index].text;
        if (tokens[index].kind != SyntaxKind.string) {
          continue;
        }
        final String delimiter = text[0];
        expect(language.stringDelimiters, contains(delimiter));
        expect(text.length, greaterThan(1), reason: line);
        expect(text[text.length - 1], delimiter, reason: line);
        final String inside = text.substring(1, text.length - 1);
        final String unescaped = inside.replaceAll(RegExp(r'\\[\s\S]'), '');
        expect(unescaped.contains(delimiter), isFalse, reason: line);
      }
    }
  });

  test('test_find_identifier_end_property_marked_words_are_whole', () {
    final Random random = seededRandom(733004);

    for (int i = 0; i < propertyIterations * 4; i += 1) {
      final String line = randomHostileCodeLine(random);
      final SyntaxLanguage language = randomSyntaxLanguage(random);
      int offset = 0;

      for (final SyntaxToken token in highlightLine(line, language)) {
        final int end = offset + token.text.length;
        final bool isMarked =
            token.kind == SyntaxKind.keyword ||
            token.kind == SyntaxKind.function;
        if (isMarked && offset > 0) {
          expect(canStartWord(line[offset - 1]), isFalse, reason: line);
        }
        if (isMarked && end < line.length) {
          expect(canContinueWord(line[end]), isFalse, reason: line);
        }
        offset = end;
      }
    }
  });

  test('test_find_identifier_end_property_ascii_call_is_one_token', () {
    final Random random = seededRandom(733005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = randomSyntaxLanguage(random);
      final String word = _randomAsciiWord(random);
      final List<SyntaxToken> marked = _markedWords(
        highlightLine(' $word(x)', language),
      );

      expect(marked.length, 1, reason: word);
      expect(marked.single.text, word);
    }
  });

  test('test_find_identifier_end_property_foreign_letters_join_words', () {
    for (final String extension in everySyntaxExtension) {
      final SyntaxLanguage language = findEverySyntaxLanguage(extension);
      for (final String keyword in language.keywords) {
        for (final String letter in _foreignLetters) {
          final List<String> lines = <String>[
            '$letter$keyword',
            '$keyword$letter',
            'x$letter$keyword(1)',
          ];
          for (final String line in lines) {
            final List<SyntaxToken> tokens = highlightLine(line, language);
            expect(_markedWords(tokens).length, lessThan(2), reason: line);
            for (final SyntaxToken token in _markedWords(tokens)) {
              expect(token.text, isNot(keyword), reason: line);
            }
          }
        }
      }
    }
  });

  test('test_classify_word_property_every_keyword_is_marked', () {
    for (final String extension in everySyntaxExtension) {
      final SyntaxLanguage language = findEverySyntaxLanguage(extension);
      for (final String keyword in language.keywords) {
        for (final String line in <String>[
          keyword,
          ' $keyword(',
          '{$keyword;',
        ]) {
          final List<SyntaxToken> marked = _markedWords(
            highlightLine(line, language),
          );

          expect(marked.length, 1, reason: '$extension: $line');
          expect(marked.single.kind, SyntaxKind.keyword, reason: line);
          expect(marked.single.text, keyword, reason: line);
        }
      }
    }
  });

  test('test_classify_word_property_calls_need_an_adjacent_parenthesis', () {
    final Random random = seededRandom(733006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = randomSyntaxLanguage(random);
      final String word = _randomAsciiWord(random);
      if (language.keywords.contains(word)) {
        continue;
      }
      final String follower = pickOne(random, _notCallingFollowers);

      final List<SyntaxToken> called = highlightLine('$word()', language);
      final List<SyntaxToken> named = highlightLine(
        '$word$follower',
        language,
      );

      expect(called.first.kind, SyntaxKind.function, reason: word);
      expect(_markedWords(named), isEmpty, reason: '$word$follower');
    }
  });

  test('test_classify_word_property_keywords_match_letter_case', () {
    for (final String extension in everySyntaxExtension) {
      final SyntaxLanguage language = findEverySyntaxLanguage(extension);
      for (final String keyword in language.keywords) {
        final String shouted = keyword.toUpperCase();
        if (language.keywords.contains(shouted)) {
          continue;
        }
        final List<SyntaxToken> tokens = highlightLine(shouted, language);

        expect(tokens.single.kind, SyntaxKind.plain, reason: shouted);
      }
    }
  });
}
