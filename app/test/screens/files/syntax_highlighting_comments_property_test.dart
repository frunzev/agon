import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/syntax_highlighting.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'syntax_highlighting_inputs.dart';

const List<String> _slashExtensions = <String>[
  'ts',
  'js',
  'dart',
  'rs',
  'go',
  'java',
  'kt',
  'swift',
  'c',
  'cpp',
  'cs',
];
const List<String> _hashExtensions = <String>[
  'py',
  'rb',
  'sh',
  'yaml',
  'toml',
];
const List<String> _commentWords = <String>[
  "don't",
  '"quoted',
  'it`s',
  "'",
  'call(x)',
  'const',
  ' ',
];

String _randomCommentText(Random random) {
  final StringBuffer text = StringBuffer();
  for (int index = 0; index < 1 + random.nextInt(5); index += 1) {
    text.write(pickOne(random, _commentWords));
    text.write(' ');
  }
  text.write(randomHostileText(random).replaceAll('\n', ' '));
  return text.toString();
}

String _plainTextFrom(List<SyntaxToken> tokens, int start) {
  final StringBuffer text = StringBuffer();
  int offset = 0;
  for (final SyntaxToken token in tokens) {
    final int end = offset + token.text.length;
    if (end > start) {
      expect(token.kind, SyntaxKind.plain, reason: token.text);
      text.write(token.text);
    }
    offset = end;
  }
  return text.toString();
}

List<SyntaxToken> _tokensOfKind(List<SyntaxToken> tokens, SyntaxKind kind) {
  return <SyntaxToken>[
    for (final SyntaxToken token in tokens)
      if (token.kind == kind) token,
  ];
}

void main() {
  test('test_highlight_line_property_slash_comments_hold_no_strings', () {
    final Random random = seededRandom(1051801);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = findEverySyntaxLanguage(
        pickOne(random, _slashExtensions),
      );
      const String code = 'const x = 1; ';
      final String line = '$code// ${_randomCommentText(random)}';
      final List<SyntaxToken> tokens = highlightLine(line, language);

      expect(joinTokenTexts(tokens), line);
      expect(
        _plainTextFrom(tokens, code.length),
        endsWith(line.substring(13)),
      );
    }
  });

  test('test_highlight_line_property_hash_comments_hold_no_strings', () {
    final Random random = seededRandom(1051802);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = findEverySyntaxLanguage(
        pickOne(random, _hashExtensions),
      );
      final String code = pickOne(random, <String>['x = 1 ', '', '\t']);
      final String line = '$code# ${_randomCommentText(random)}';
      final List<SyntaxToken> tokens = highlightLine(line, language);

      expect(joinTokenTexts(tokens), line);
      _plainTextFrom(tokens, code.length);
    }
  });

  test('test_highlight_line_property_hash_inside_a_word_is_code', () {
    final Random random = seededRandom(1051803);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = findEverySyntaxLanguage(
        pickOne(random, <String>['sh', 'bash', 'zsh', 'yaml']),
      );
      final String hashUse = pickOne(random, <String>[
        r'${#items[@]}',
        r'$#',
        r'${name#prefix}',
        'url/#anchor',
      ]);
      final String line = 'echo $hashUse "done"';
      final List<SyntaxToken> strings = _tokensOfKind(
        highlightLine(line, language),
        SyntaxKind.string,
      );

      expect(strings.map((SyntaxToken token) => token.text), <String>[
        '"done"',
      ]);
    }
  });

  test('test_highlight_line_property_closed_block_comment_ends_there', () {
    final Random random = seededRandom(1051804);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = findEverySyntaxLanguage(
        pickOne(random, _slashExtensions),
      );
      final String comment = _randomCommentText(random).replaceAll('*/', '');
      final String line = '/* $comment */ x = "a";';
      final List<SyntaxToken> tokens = highlightLine(line, language);

      expect(joinTokenTexts(tokens), line);
      expect(
        _tokensOfKind(
          tokens,
          SyntaxKind.string,
        ).map((SyntaxToken token) => token.text),
        <String>['"a"'],
      );
    }
  });

  test('test_highlight_line_property_markers_inside_strings_are_text', () {
    final Random random = seededRandom(1051805);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String extension = pickOne(random, <String>[
        ..._slashExtensions,
        ..._hashExtensions,
        'json',
      ]);
      final String marker = pickOne(random, <String>['//', '/*', '#', ' #']);
      final String line = 'x = "a${marker}b" + y';
      final List<SyntaxToken> tokens = highlightLine(
        line,
        findEverySyntaxLanguage(extension),
      );

      expect(
        _tokensOfKind(
          tokens,
          SyntaxKind.string,
        ).map((SyntaxToken token) => token.text),
        <String>['"a${marker}b"'],
      );
    }
  });

  test('test_highlight_line_property_json_has_no_comments', () {
    final Random random = seededRandom(1051806);
    final SyntaxLanguage json = findEverySyntaxLanguage('json');

    for (int i = 0; i < propertyIterations; i += 1) {
      final String marker = pickOne(random, <String>['//', '#', '/*']);
      final String line = '$marker "key": true';
      final List<SyntaxToken> tokens = highlightLine(line, json);

      expect(_tokensOfKind(tokens, SyntaxKind.string), hasLength(1));
      expect(_tokensOfKind(tokens, SyntaxKind.keyword), hasLength(1));
    }
  });

  test('test_highlight_lines_property_block_comments_span_lines', () {
    final Random random = seededRandom(1051807);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = findEverySyntaxLanguage(
        pickOne(random, _slashExtensions),
      );
      final List<String> inside = <String>[
        for (int line = 0; line < random.nextInt(4); line += 1)
          ' * ${_randomCommentText(random).replaceAll('*/', '')}',
      ];
      final List<String> lines = <String>[
        '/** ${_randomCommentText(random).replaceAll('*/', '')}',
        ...inside,
        ' */ const x = "a";',
      ];
      final List<List<SyntaxToken>> highlighted = highlightLines(
        lines,
        language,
      );

      for (int index = 0; index < lines.length - 1; index += 1) {
        expect(joinTokenTexts(highlighted[index]), lines[index]);
        _plainTextFrom(highlighted[index], 0);
      }
      expect(_tokensOfKind(highlighted.last, SyntaxKind.string), hasLength(1));
    }
  });

  test('test_highlight_lines_property_one_token_list_per_line', () {
    final Random random = seededRandom(1051808);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = randomSyntaxLanguage(random);
      final List<String> lines = <String>[
        for (int line = 0; line < random.nextInt(8); line += 1)
          randomHostileCodeLine(random),
      ];
      final List<List<SyntaxToken>> highlighted = highlightLines(
        lines,
        language,
      );

      expect(highlighted, hasLength(lines.length));
      for (int index = 0; index < lines.length; index += 1) {
        expect(joinTokenTexts(highlighted[index]), lines[index]);
      }
    }
  });

  test('test_highlight_lines_property_lines_without_block_openers_match_'
      'single_lines', () {
    final Random random = seededRandom(1051809);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = randomSyntaxLanguage(random);
      final List<String> lines = <String>[
        for (int line = 0; line < random.nextInt(8); line += 1)
          randomHostileCodeLine(random)
              .replaceAll('*', '+')
              .replaceAll('`', '+')
              .replaceAll('"""', '+')
              .replaceAll("'''", '+'),
      ];
      final List<List<SyntaxToken>> highlighted = highlightLines(
        lines,
        language,
      );

      for (int index = 0; index < lines.length; index += 1) {
        final List<SyntaxToken> alone = highlightLine(lines[index], language);
        expect(
          highlighted[index].map(
            (SyntaxToken token) => (token.text, token.kind),
          ),
          alone.map((SyntaxToken token) => (token.text, token.kind)),
        );
      }
    }
  });
}
