import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/code_view.dart';
import 'package:agent_orchestration/screens/files/syntax_highlighting.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';
import 'package:agent_orchestration/screens/files/text_lines.dart';
import 'package:agent_orchestration/theme/app_colors.dart';

import '../../support/random_inputs.dart';
import 'shown_code_lines.dart';

typedef _HighlightedPart = ({SyntaxToken token, TextSpan span});

final SyntaxLanguage _scriptLanguage = findSyntaxLanguage('ts')!;

Future<List<_HighlightedPart>> _pumpHighlightedParts(
  WidgetTester tester,
  Random random,
) async {
  final String text = randomCode(random);
  await pumpCodeView(
    tester,
    random,
    CodeView(text: text, language: _scriptLanguage),
  );
  final List<String> lines = splitTextLines(text);
  final List<ShownCodeLine> shown = findShownCodeLines();
  final List<_HighlightedPart> parts = <_HighlightedPart>[];

  final List<List<SyntaxToken>> tokensByLine = highlightLines(
    lines,
    _scriptLanguage,
  );

  for (int index = 0; index < lines.length; index += 1) {
    final List<TextSpan> spans = readCodeSpans(shown[index]);
    final List<SyntaxToken> tokens = tokensByLine[index];
    expect(spans, hasLength(tokens.length));
    for (int part = 0; part < tokens.length; part += 1) {
      parts.add((token: tokens[part], span: spans[part]));
    }
  }
  return parts;
}

void main() {
  testWidgets('test_build_spans_property_spans_match_the_highlighter', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99808);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<_HighlightedPart> parts = await _pumpHighlightedParts(
        tester,
        random,
      );

      for (final _HighlightedPart part in parts) {
        expect(part.span.text, part.token.text);
      }
    }
  });

  testWidgets('test_build_spans_property_plain_text_is_one_unstyled_span', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99809);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String text = randomCode(random);
      await pumpCodeView(tester, random, CodeView(text: text, language: null));
      final List<String> lines = splitTextLines(text);
      final List<ShownCodeLine> shown = findShownCodeLines();

      for (int index = 0; index < lines.length; index += 1) {
        final List<TextSpan> spans = readCodeSpans(shown[index]);

        expect(spans, hasLength(1));
        expect(spans.single.text, lines[index]);
        expect(spans.single.style, isNull);
      }
    }
  });

  testWidgets('test_build_spans_property_spell_the_line_in_any_language', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99810);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String text = randomCode(random);
      final SyntaxLanguage? language = randomSyntaxLanguage(random);
      await pumpCodeView(
        tester,
        random,
        CodeView(text: text, language: language),
      );
      final List<String> lines = splitTextLines(text);
      final List<ShownCodeLine> shown = findShownCodeLines();

      for (int index = 0; index < lines.length; index += 1) {
        final StringBuffer spelled = StringBuffer();
        for (final TextSpan span in readCodeSpans(shown[index])) {
          spelled.write(span.text);
        }

        expect(spelled.toString(), lines[index]);
      }
    }
  });

  testWidgets('test_style_for_property_matches_the_design_tokens', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99811);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<_HighlightedPart> parts = await _pumpHighlightedParts(
        tester,
        random,
      );

      for (final _HighlightedPart part in parts) {
        final TextStyle? style = part.span.style;
        switch (part.token.kind) {
          case SyntaxKind.keyword:
            expect(style?.color, AppColors.action);
          case SyntaxKind.string:
            expect(style?.color, AppColors.attention);
          case SyntaxKind.function:
            expect(style?.fontWeight, FontWeight.w700);
          case SyntaxKind.plain:
            expect(style, isNull);
        }
      }
    }
  });

  testWidgets('test_style_for_property_one_kind_one_style', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99812);
    final Map<SyntaxKind, Set<TextStyle?>> stylesByKind =
        <SyntaxKind, Set<TextStyle?>>{};

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<_HighlightedPart> parts = await _pumpHighlightedParts(
        tester,
        random,
      );
      for (final _HighlightedPart part in parts) {
        final Set<TextStyle?> styles = stylesByKind.putIfAbsent(
          part.token.kind,
          () => <TextStyle?>{},
        );
        styles.add(part.span.style);
      }
    }

    final Set<TextStyle?> distinctStyles = <TextStyle?>{};
    for (final Set<TextStyle?> styles in stylesByKind.values) {
      expect(styles, hasLength(1));
      distinctStyles.addAll(styles);
    }
    expect(distinctStyles, hasLength(stylesByKind.length));
  });

  testWidgets('test_style_for_property_highlighting_keeps_the_text', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(99813);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<_HighlightedPart> parts = await _pumpHighlightedParts(
        tester,
        random,
      );

      for (final _HighlightedPart part in parts) {
        expect(part.span.text, isNotEmpty);
        expect(part.span.children, isNull);
      }
    }
  });
}
