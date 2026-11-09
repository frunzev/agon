import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_kinds.dart';
import 'package:agent_orchestration/screens/files/syntax_highlighting.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'file_property_inputs.dart';

const List<List<String>> _languageFamilies = <List<String>>[
  <String>['ts', 'tsx', 'js', 'jsx', 'mjs', 'cjs'],
  <String>['dart'],
  <String>['rs'],
  <String>['py'],
  <String>['go'],
  <String>['java', 'kt', 'kts'],
  <String>['swift'],
  <String>['c', 'h', 'cc', 'cpp', 'hpp', 'cs', 'm'],
  <String>['rb'],
  <String>['sh', 'bash', 'zsh'],
  <String>['json'],
  <String>['yaml', 'yml', 'toml'],
];
const Set<String> _quoteCharacters = <String>{'"', "'", '`'};
final RegExp _identifierWord = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

List<String> _listCodeExtensions() {
  final List<String> extensions = <String>[];
  for (final List<String> family in _languageFamilies) {
    extensions.addAll(family);
  }
  return extensions;
}

List<SyntaxLanguage> _listBuiltInLanguages() {
  final List<SyntaxLanguage> languages = <SyntaxLanguage>[];
  for (final String extension in _listCodeExtensions()) {
    final SyntaxLanguage language = findSyntaxLanguage(extension)!;
    if (!languages.any((SyntaxLanguage seen) => identical(seen, language))) {
      languages.add(language);
    }
  }
  return languages;
}

Set<String> _randomWordSet(Random random) {
  final Set<String> words = <String>{};
  final int count = random.nextInt(6);
  for (int index = 0; index < count; index += 1) {
    words.add(randomHostileText(random));
  }
  return words;
}

void main() {
  test('test_syntax_language_constructor_property_keeps_both_sets', () {
    final Random random = seededRandom(1020101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Set<String> keywords = _randomWordSet(random);
      final Set<String> delimiters = _randomWordSet(random);
      final CommentStyle comments = pickOne(random, CommentStyle.values);

      final SyntaxLanguage language = SyntaxLanguage(
        keywords: keywords,
        stringDelimiters: delimiters,
        multiLineStringDelimiters: const <String>{},
        comments: comments,
      );

      expect(language.keywords, same(keywords));
      expect(language.stringDelimiters, same(delimiters));
      expect(language.comments, comments);
    }
  });

  test('test_syntax_language_constructor_property_const_values_are_'
      'canonical', () {
    const SyntaxLanguage first = SyntaxLanguage(
      keywords: <String>{'let'},
      stringDelimiters: <String>{'"'},
      multiLineStringDelimiters: <String>{},
      comments: CommentStyle.none,
    );
    const SyntaxLanguage second = SyntaxLanguage(
      keywords: <String>{'let'},
      stringDelimiters: <String>{'"'},
      multiLineStringDelimiters: <String>{},
      comments: CommentStyle.none,
    );

    expect(identical(first, second), isTrue);
    expect(first.keywords, <String>{'let'});
  });

  test('test_syntax_language_constructor_property_built_in_languages_'
      'never_change', () {
    for (final SyntaxLanguage language in _listBuiltInLanguages()) {
      expect(() => language.keywords.add('x'), throwsUnsupportedError);
      expect(() => language.stringDelimiters.add('x'), throwsUnsupportedError);
      expect(language.stringDelimiters, isNot(contains('x')));
    }
  });

  test('test_find_syntax_language_property_one_language_per_family', () {
    final List<SyntaxLanguage> languages = <SyntaxLanguage>[];

    for (final List<String> family in _languageFamilies) {
      final SyntaxLanguage? language = findSyntaxLanguage(family.first);
      expect(language, isNotNull, reason: family.first);
      for (final String extension in family) {
        expect(findSyntaxLanguage(extension), same(language));
        expect(findSyntaxLanguage(extension), same(language));
      }
      languages.add(language!);
    }

    expect(languages.toSet(), hasLength(_languageFamilies.length));
  });

  test('test_find_syntax_language_property_non_extensions_find_nothing', () {
    final Random random = seededRandom(1020102);
    final List<String> extensions = _listCodeExtensions();

    for (int i = 0; i < propertyIterations; i += 1) {
      final String extension = pickOne(random, extensions);
      final String hostile = randomHostileText(random);

      expect(findSyntaxLanguage('.$extension'), isNull);
      expect(findSyntaxLanguage(' $extension'), isNull);
      expect(findSyntaxLanguage('$extension '), isNull);
      expect(findSyntaxLanguage('$extension.'), isNull);
      if (!extensions.contains(hostile)) {
        expect(findSyntaxLanguage(hostile), isNull, reason: hostile);
      }
    }
    expect(findSyntaxLanguage(''), isNull);
  });

  test('test_find_syntax_language_property_agrees_with_file_names', () {
    final Random random = seededRandom(1020103);
    final List<String> extensions = _listCodeExtensions();

    for (int i = 0; i < propertyIterations; i += 1) {
      final String extension = pickOne(random, extensions);
      final String stem = randomHostileFileStem(random);
      final SyntaxLanguage? language = findSyntaxLanguage(extension);

      expect(findSyntaxLanguageFor('$stem.$extension'), same(language));
      expect(
        findSyntaxLanguageFor('$stem.${extension.toUpperCase()}'),
        same(language),
      );
      expect(chooseTextViewer('$stem.$extension'), TextViewer.code);
    }
  });

  test('test_split_words_property_keywords_are_whole_words', () {
    for (final SyntaxLanguage language in _listBuiltInLanguages()) {
      expect(language.keywords, isNotEmpty);
      for (final String keyword in language.keywords) {
        expect(_identifierWord.hasMatch(keyword), isTrue, reason: keyword);
      }
    }
  });

  test('test_split_words_property_every_keyword_highlights_alone', () {
    for (final SyntaxLanguage language in _listBuiltInLanguages()) {
      for (final String keyword in language.keywords) {
        final List<SyntaxToken> tokens = highlightLine(keyword, language);

        expect(tokens, hasLength(1), reason: keyword);
        expect(tokens.single.kind, SyntaxKind.keyword);
        expect(tokens.single.text, keyword);
      }
    }
  });

  test('test_split_words_property_keywords_survive_padding_and_calls', () {
    final Random random = seededRandom(1020104);
    final List<SyntaxLanguage> languages = _listBuiltInLanguages();

    for (int i = 0; i < propertyIterations; i += 1) {
      final SyntaxLanguage language = pickOne(random, languages);
      final String keyword = pickOne(random, language.keywords.toList());
      final String line = '  $keyword ($keyword) ';

      final List<SyntaxToken> keywordTokens = <SyntaxToken>[
        for (final SyntaxToken token in highlightLine(line, language))
          if (token.kind == SyntaxKind.keyword) token,
      ];

      expect(keywordTokens, hasLength(2), reason: line);
      for (final SyntaxToken token in keywordTokens) {
        expect(token.text, keyword);
      }
    }
  });

  test('test_find_syntax_language_property_delimiters_are_quotes', () {
    for (final SyntaxLanguage language in _listBuiltInLanguages()) {
      expect(language.stringDelimiters, isNotEmpty);
      expect(language.stringDelimiters, contains('"'));
      for (final String delimiter in language.stringDelimiters) {
        expect(_quoteCharacters, contains(delimiter));
      }
    }
  });
}
