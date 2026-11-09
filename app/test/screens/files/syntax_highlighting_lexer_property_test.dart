import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/code_view.dart';
import 'package:agent_orchestration/screens/files/syntax_highlighting.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';
import 'package:agent_orchestration/theme/app_colors.dart';

import '../../support/random_inputs.dart';
import 'shown_code_lines.dart'
    show ShownCodeLine, findShownCodeLines, pumpCodeView, readCodeSpans;
import 'syntax_highlighting_inputs.dart';

const Map<String, CommentStyle> _expectedStyles = <String, CommentStyle>{
  'ts': CommentStyle.slashLinesAndBlocks,
  'dart': CommentStyle.slashLinesAndBlocks,
  'rs': CommentStyle.slashLinesAndBlocks,
  'go': CommentStyle.slashLinesAndBlocks,
  'java': CommentStyle.slashLinesAndBlocks,
  'swift': CommentStyle.slashLinesAndBlocks,
  'c': CommentStyle.slashLinesAndBlocks,
  'py': CommentStyle.hashAtWordStart,
  'rb': CommentStyle.hashAtWordStart,
  'sh': CommentStyle.hashAtWordStart,
  'yaml': CommentStyle.hashAtWordStart,
  'toml': CommentStyle.hashAtWordStart,
  'json': CommentStyle.none,
};
const List<String> _codeAroundMarkers = <String>['x', ' ', '"s"', 'f(', ';'];

List<SyntaxKind> _kindsOf(List<SyntaxToken> tokens) {
  return <SyntaxKind>[for (final SyntaxToken token in tokens) token.kind];
}

String _randomCodeWithMarkers(Random random) {
  final StringBuffer line = StringBuffer();
  for (int index = 0; index < random.nextInt(10); index += 1) {
    line.write(
      pickOne(random, <String>[
        ..._codeAroundMarkers,
        '//',
        '/*',
        '*/',
        '#',
        "'",
      ]),
    );
  }
  return line.toString();
}

void main() {
  test('test_comment_style_values_property_every_language_has_its_style', () {
    for (final MapEntry<String, CommentStyle> entry
        in _expectedStyles.entries) {
      expect(findEverySyntaxLanguage(entry.key).comments, entry.value);
    }
  });

  test('test_comment_style_values_property_names_are_distinct', () {
    final Set<String> names = <String>{
      for (final CommentStyle style in CommentStyle.values) style.name,
    };

    expect(names, hasLength(CommentStyle.values.length));
  });

  test('test_comment_style_values_property_every_style_is_used', () {
    final Set<CommentStyle> used = <CommentStyle>{
      for (final String extension in everySyntaxExtension)
        findEverySyntaxLanguage(extension).comments,
    };

    expect(used, CommentStyle.values.toSet());
  });

  test('test_highlight_one_line_property_comments_never_change_text', () {
    final Random random = seededRandom(1051901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String line = _randomCodeWithMarkers(random);
      final SyntaxLanguage language = randomSyntaxLanguage(random);

      expect(joinTokenTexts(highlightLine(line, language)), line);
    }
  });

  test('test_highlight_one_line_property_unclosed_block_runs_to_line_end', () {
    final Random random = seededRandom(1051902);
    final SyntaxLanguage script = findEverySyntaxLanguage('ts');

    for (int i = 0; i < propertyIterations; i += 1) {
      final String rest = _randomCodeWithMarkers(random).replaceAll('*', '');
      final List<SyntaxToken> tokens = highlightLine('/*$rest', script);

      expect(_kindsOf(tokens), <SyntaxKind>[SyntaxKind.plain]);
    }
  });

  test('test_highlight_one_line_property_code_after_a_closed_block_is_'
      'highlighted', () {
    final Random random = seededRandom(1051903);
    final SyntaxLanguage script = findEverySyntaxLanguage('ts');

    for (int i = 0; i < propertyIterations; i += 1) {
      final String inside = _randomCodeWithMarkers(random).replaceAll('*', '');
      final List<SyntaxToken> tokens = highlightLine(
        '/*$inside*/const',
        script,
      );

      expect(tokens.last.text, 'const');
      expect(tokens.last.kind, SyntaxKind.keyword);
    }
  });

  test('test_starts_block_comment_property_only_slash_languages', () {
    final Random random = seededRandom(1051904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String extension = pickOne(random, everySyntaxExtension);
      final SyntaxLanguage language = findEverySyntaxLanguage(extension);
      final List<List<SyntaxToken>> lines = highlightLines(<String>[
        "/* don't",
        "'a'",
      ], language);
      final bool hasBlocks =
          language.comments == CommentStyle.slashLinesAndBlocks;

      expect(
        _kindsOf(lines.last).contains(SyntaxKind.string),
        !hasBlocks && language.stringDelimiters.contains("'"),
      );
    }
  });

  test('test_starts_block_comment_property_needs_both_characters', () {
    final Random random = seededRandom(1051905);
    final SyntaxLanguage script = findEverySyntaxLanguage('ts');

    for (int i = 0; i < propertyIterations; i += 1) {
      final String split = pickOne(random, <String>['/ *', '/', '*', '* /']);
      final List<SyntaxToken> tokens = highlightLine("$split 'a'", script);

      expect(_kindsOf(tokens), contains(SyntaxKind.string));
    }
  });

  test('test_starts_block_comment_property_opener_in_a_line_comment_is_'
      'inert', () {
    final Random random = seededRandom(1051906);
    final SyntaxLanguage script = findEverySyntaxLanguage('ts');

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<List<SyntaxToken>> lines = highlightLines(<String>[
        '// ${_randomCodeWithMarkers(random)} /*',
        '"a"',
      ], script);

      expect(_kindsOf(lines.last), <SyntaxKind>[SyntaxKind.string]);
    }
  });

  test('test_starts_line_comment_property_slashes_start_anywhere', () {
    final Random random = seededRandom(1051907);
    final SyntaxLanguage script = findEverySyntaxLanguage('ts');

    for (int i = 0; i < propertyIterations; i += 1) {
      final String before = pickOne(random, <String>['x;', 'f()', '', 'a ']);
      final List<SyntaxToken> tokens = highlightLine("$before// 'b'", script);

      expect(_kindsOf(tokens), isNot(contains(SyntaxKind.string)));
    }
  });

  test('test_starts_line_comment_property_hash_needs_a_word_start', () {
    final Random random = seededRandom(1051908);
    final SyntaxLanguage python = findEverySyntaxLanguage('py');

    for (int i = 0; i < propertyIterations; i += 1) {
      final String before = pickOne(random, <String>[' ', '\t', '', 'x ']);
      final List<SyntaxToken> commented = highlightLine(
        "$before# 'b'",
        python,
      );
      final List<SyntaxToken> glued = highlightLine("x# 'b'", python);

      expect(_kindsOf(commented), isNot(contains(SyntaxKind.string)));
      expect(_kindsOf(glued), contains(SyntaxKind.string));
    }
  });

  test('test_starts_line_comment_property_json_never_comments', () {
    final Random random = seededRandom(1051909);
    final SyntaxLanguage json = findEverySyntaxLanguage('json');

    for (int i = 0; i < propertyIterations; i += 1) {
      final String marker = pickOne(random, <String>['//', '#', ' # ']);
      final List<SyntaxToken> tokens = highlightLine('$marker"b"', json);

      expect(_kindsOf(tokens), contains(SyntaxKind.string));
    }
  });

  testWidgets('test_code_view_build_property_block_comment_lines_are_plain', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051910);
    final SyntaxLanguage script = findEverySyntaxLanguage('ts');

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<String> lines = <String>[
        '/**',
        for (int line = 0; line < 1 + random.nextInt(4); line += 1)
          " * don't use \"quotes\" here $line",
        ' */',
        'const x = "a";',
      ];
      await pumpCodeView(
        tester,
        random,
        CodeView(text: lines.join('\n'), language: script),
      );
      final List<ShownCodeLine> shown = findShownCodeLines();

      for (int index = 0; index < lines.length - 1; index += 1) {
        for (final TextSpan span in readCodeSpans(shown[index])) {
          expect(span.style, isNull, reason: lines[index]);
        }
      }
      final List<Color?> lastColors = <Color?>[
        for (final TextSpan span in readCodeSpans(shown.last))
          span.style?.color,
      ];
      expect(lastColors, contains(AppColors.attention));
    }
  });
}
