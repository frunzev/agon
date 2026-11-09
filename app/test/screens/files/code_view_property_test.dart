import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/code_view.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';
import 'package:agent_orchestration/screens/files/text_lines.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_property_inputs.dart';
import 'shown_code_lines.dart';

const List<int> _lineCountsAroundDigitChanges = <int>[1, 9, 10, 99, 100, 1000];

String _randomLongText(Random random) {
  final int lineCount =
      pickOne(random, _lineCountsAroundDigitChanges) + random.nextInt(3);
  return List<String>.filled(lineCount, 'x').join('\n');
}

void main() {
  test('test_code_view_new_property_keeps_text_and_language', () {
    final Random random = seededRandom(99801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = randomFileText(random);
      final SyntaxLanguage? language = randomSyntaxLanguage(random);
      final CodeView view = CodeView(text: text, language: language);

      expect(view.text, text);
      expect(view.language, same(language));
    }
  });

  test('test_code_view_new_property_keeps_the_key', () {
    final Random random = seededRandom(99802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(1 << 30));

      expect(CodeView(text: '', language: null, key: key).key, key);
    }
  });

  test('test_code_view_new_property_keeps_huge_text_verbatim', () {
    final Random random = seededRandom(99814);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = randomFileText(random) * random.nextInt(50);

      expect(CodeView(text: text, language: null).text, same(text));
    }
  });

  testWidgets('test_code_view_build_property_shows_every_line_whole', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String text = randomCode(random);
      final SyntaxLanguage? language = randomSyntaxLanguage(random);
      await pumpCodeView(
        tester,
        random,
        CodeView(text: text, language: language),
      );
      final List<String> shown = <String>[
        for (final ShownCodeLine line in findShownCodeLines())
          line.code.text.toPlainText(),
      ];

      expect(shown, splitTextLines(text));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_code_view_build_property_renders_hostile_text', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 99804,
      buildChild: (Random random) => CodeView(
        text: randomFileText(random),
        language: randomSyntaxLanguage(random),
      ),
    );
  });

  testWidgets('test_build_line_property_numbers_count_up_from_one', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String text = randomCode(random);
      await pumpCodeView(tester, random, CodeView(text: text, language: null));
      final List<String> numbers = <String>[
        for (final ShownCodeLine line in findShownCodeLines())
          line.number.text.toPlainText().trim(),
      ];
      final int lineCount = splitTextLines(text).length;

      expect(numbers, <String>[
        for (int index = 1; index <= lineCount; index += 1) '$index',
      ]);
    }
  });

  testWidgets('test_build_line_property_numbers_are_never_cut_off', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String text = _randomLongText(random);
      await pumpCodeView(tester, random, CodeView(text: text, language: null));

      for (final ShownCodeLine line in findShownCodeLines()) {
        final double wholeWidth = line.number.getMaxIntrinsicWidth(
          double.infinity,
        );

        expect(
          line.number.size.width,
          greaterThanOrEqualTo(wholeWidth - 0.01),
        );
      }
    }
  });

  testWidgets('test_build_line_property_code_starts_in_one_column', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99807);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String text = _randomLongText(random);
      await pumpCodeView(tester, random, CodeView(text: text, language: null));
      final Set<double> codeStarts = <double>{
        for (final ShownCodeLine line in findShownCodeLines())
          line.code.localToGlobal(Offset.zero).dx,
      };

      expect(codeStarts, hasLength(1));
    }
  });
}
