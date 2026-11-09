import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/syntax_highlighting.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';

import '../../support/random_inputs.dart';
import 'syntax_highlighting_inputs.dart';

String _randomLineOrOpeners(Random random) {
  if (random.nextBool()) {
    return randomHostileCodeLine(random);
  }
  return '"""``\'\'\'';
}

List<SyntaxKind> _listKinds(List<SyntaxToken> tokens) {
  return <SyntaxKind>[for (final SyntaxToken token in tokens) token.kind];
}

void main() {
  test('test_add_text_property_spans_never_split_plain_runs', () {
    final Random random = seededRandom(54912);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = randomSyntaxLanguage(random);
      final List<String> lines = <String>[
        for (int line = 0; line < 1 + random.nextInt(6); line += 1)
          '${randomHostileCodeLine(random)}/*"""`',
      ];

      final List<List<SyntaxToken>> highlighted = highlightLines(
        lines,
        language,
      );

      for (final List<SyntaxToken> tokens in highlighted) {
        for (int index = 1; index < tokens.length; index += 1) {
          final bool bothPlain =
              tokens[index].kind == SyntaxKind.plain &&
              tokens[index - 1].kind == SyntaxKind.plain;
          expect(bothPlain, isFalse);
        }
      }
    }
  });

  test('test_add_text_property_never_adds_an_empty_token', () {
    final Random random = seededRandom(54913);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = randomSyntaxLanguage(random);
      final List<String> lines = <String>[
        for (int line = 0; line < random.nextInt(8); line += 1)
          _randomLineOrOpeners(random),
      ];

      final List<List<SyntaxToken>> highlighted = highlightLines(
        lines,
        language,
      );

      for (final List<SyntaxToken> tokens in highlighted) {
        for (final SyntaxToken token in tokens) {
          expect(token.text, isNotEmpty);
        }
      }
    }
  });

  test('test_add_text_property_keywords_inside_strings_stay_strings', () {
    final Random random = seededRandom(54914);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = findEverySyntaxLanguage('py');
      final String keyword = pickOne(random, language.keywords.toList());

      final List<List<SyntaxToken>> highlighted = highlightLines(<String>[
        'x = """',
        '$keyword call() $keyword',
        '"""',
      ], language);

      expect(_listKinds(highlighted[1]), <SyntaxKind>[SyntaxKind.string]);
    }
  });
}
