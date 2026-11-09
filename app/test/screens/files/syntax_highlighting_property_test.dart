import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/syntax_highlighting.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'syntax_highlighting_inputs.dart';

const int _hugeLineLength = 200000;
const int _hugeLineIterations = 3;
const String _plainOnlyCharacters = '0123456789 \t+-*/=<>!?.,;:{}[]()@%^&|~';
const int _largestPlainLength = 60;

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit < 0xDC00;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit < 0xE000;

String _randomHugeLine(Random random) {
  final StringBuffer line = StringBuffer();
  while (line.length < _hugeLineLength) {
    line.write(randomHostileCodeLine(random));
  }
  return line.toString();
}

String _randomPlainOnlyLine(Random random) {
  final StringBuffer line = StringBuffer();
  final int length = random.nextInt(_largestPlainLength);
  for (int index = 0; index < length; index += 1) {
    final int position = random.nextInt(_plainOnlyCharacters.length);
    line.write(_plainOnlyCharacters[position]);
  }
  return line.toString();
}

void main() {
  test('test_syntax_token_new_property_keeps_text_and_kind', () {
    final Random random = seededRandom(732001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = randomHostileText(random);
      final SyntaxKind kind = pickOne(random, SyntaxKind.values);
      final SyntaxToken token = SyntaxToken(text, kind);

      expect(token.text, text);
      expect(token.kind, kind);
    }
  });

  test('test_syntax_token_new_property_const_tokens_are_canonical', () {
    const SyntaxToken first = SyntaxToken('word', SyntaxKind.keyword);
    const SyntaxToken second = SyntaxToken('word', SyntaxKind.keyword);
    const SyntaxToken other = SyntaxToken('word', SyntaxKind.string);

    expect(identical(first, second), isTrue);
    expect(identical(first, other), isFalse);
    expect(other.kind, SyntaxKind.string);
  });

  test('test_syntax_token_new_property_kinds_are_distinct_names', () {
    final Set<String> names = <String>{
      for (final SyntaxKind kind in SyntaxKind.values) kind.name,
    };

    expect(names, <String>{'plain', 'keyword', 'string', 'function'});
    for (final SyntaxKind kind in SyntaxKind.values) {
      expect(SyntaxToken(kind.name, kind).kind.name, kind.name);
    }
  });

  test('test_highlight_line_property_every_language_keeps_the_text', () {
    final Random random = seededRandom(732002);

    for (final String extension in everySyntaxExtension) {
      final SyntaxLanguage language = findEverySyntaxLanguage(extension);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String line = randomHostileCodeLine(random);
        final List<SyntaxToken> tokens = highlightLine(line, language);

        expect(joinTokenTexts(tokens), line, reason: '$extension: $line');
      }
    }
  });

  test('test_highlight_line_property_huge_lines_finish_unchanged', () {
    final Random random = seededRandom(732003);

    for (int i = 0; i < _hugeLineIterations; i += 1) {
      final String line = _randomHugeLine(random);
      for (final String extension in everySyntaxExtension) {
        final SyntaxLanguage language = findEverySyntaxLanguage(extension);
        final List<SyntaxToken> tokens = highlightLine(line, language);

        expect(joinTokenTexts(tokens) == line, isTrue, reason: extension);
      }
    }
  });

  test('test_highlight_line_property_never_splits_a_surrogate_pair', () {
    final Random random = seededRandom(732004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String line = randomHostileCodeLine(random);
      final SyntaxLanguage language = randomSyntaxLanguage(random);

      for (final SyntaxToken token in highlightLine(line, language)) {
        final List<int> codeUnits = token.text.codeUnits;
        expect(_isLowSurrogate(codeUnits.first), isFalse, reason: line);
        expect(_isHighSurrogate(codeUnits.last), isFalse, reason: line);
      }
    }
  });

  test('test_highlight_line_property_hands_back_an_unmodifiable_list', () {
    final Random random = seededRandom(732005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SyntaxToken> tokens = highlightLine(
        randomHostileCodeLine(random),
        randomSyntaxLanguage(random),
      );

      expect(
        () => tokens.add(const SyntaxToken('x', SyntaxKind.plain)),
        throwsUnsupportedError,
      );
    }
  });

  test('test_add_plain_text_property_never_two_plain_tokens_in_a_row', () {
    final Random random = seededRandom(732006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String line = randomHostileCodeLine(random);
      final List<SyntaxToken> tokens = highlightLine(
        line,
        randomSyntaxLanguage(random),
      );

      for (int index = 1; index < tokens.length; index += 1) {
        final bool isPlainPair =
            tokens[index - 1].kind == SyntaxKind.plain &&
            tokens[index].kind == SyntaxKind.plain;
        expect(isPlainPair, isFalse, reason: line);
      }
    }
  });

  test('test_add_plain_text_property_never_adds_an_empty_token', () {
    final Random random = seededRandom(732007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String line = randomHostileCodeLine(random);
      final List<SyntaxToken> tokens = highlightLine(
        line,
        randomSyntaxLanguage(random),
      );

      expect(tokens.isEmpty, line.isEmpty, reason: line);
      for (final SyntaxToken token in tokens) {
        expect(token.text, isNotEmpty, reason: line);
      }
    }
  });

  test('test_add_plain_text_property_wordless_line_is_one_plain_token', () {
    final Random random = seededRandom(732008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String line = _randomPlainOnlyLine(random);
      final List<SyntaxToken> tokens = highlightLine(
        line,
        randomSyntaxLanguage(random),
      );

      if (line.isEmpty) {
        expect(tokens, isEmpty);
      } else {
        expect(tokens.length, 1, reason: line);
        expect(tokens.single.text, line);
        expect(tokens.single.kind, SyntaxKind.plain);
      }
    }
  });
}
