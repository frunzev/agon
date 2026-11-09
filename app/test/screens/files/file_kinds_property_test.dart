import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/file_kinds.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'file_property_inputs.dart';

const List<String> _codeExtensions = <String>[
  'ts',
  'dart',
  'rs',
  'py',
  'json',
];
const List<String> _markdownExtensions = <String>['md', 'markdown'];
const List<String> _mediaExtensions = <String>['mp4', 'mp3', 'zip', 'pdf'];
const Set<String> _articles = <String>{'a', 'an'};

String _randomExtension(Random random) {
  final String extension = randomHostileText(random).replaceAll('.', '');
  return pickOne(random, <String>[
    extension,
    ...sampleFileExtensions,
  ]).replaceAll('.', '');
}

String _randomCasing(Random random, String text) {
  final StringBuffer cased = StringBuffer();
  for (final String letter in text.split('')) {
    cased.write(random.nextBool() ? letter.toUpperCase() : letter);
  }
  return cased.toString();
}

void main() {
  test('test_read_file_extension_property_returns_the_last_part', () {
    final Random random = seededRandom(99201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String extension = _randomExtension(random);
      final String name = '${randomHostileFileStem(random)}.$extension';

      expect(readFileExtension(name), extension.toLowerCase(), reason: name);
    }
  });

  test('test_read_file_extension_property_dotfiles_and_bare_names_empty', () {
    final Random random = seededRandom(99202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String bare = randomHostileText(random).replaceAll('.', '');

      expect(readFileExtension(bare), isEmpty, reason: bare);
      expect(readFileExtension('.$bare'), isEmpty, reason: '.$bare');
    }
  });

  test('test_read_file_extension_property_is_idempotent_and_dotless', () {
    final Random random = seededRandom(99203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomHostileText(random);
      final String extension = readFileExtension(name);

      expect(extension, isNot(contains('.')));
      expect(readFileExtension('file.$extension'), extension);
    }
  });

  test('test_find_syntax_language_for_property_ignores_letter_case', () {
    final Random random = seededRandom(99204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String stem = randomHostileFileStem(random);
      final String extension = pickOne(random, _codeExtensions);
      final String cased = _randomCasing(random, extension);

      expect(
        findSyntaxLanguageFor('$stem.$cased'),
        same(findSyntaxLanguage(extension)),
      );
      expect(findSyntaxLanguageFor('$stem.$cased'), isNotNull);
    }
  });

  test('test_find_syntax_language_for_property_agrees_with_the_viewer', () {
    final Random random = seededRandom(99205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomHostileFileName(random);
      final SyntaxLanguage? language = findSyntaxLanguageFor(name);
      final TextViewer viewer = chooseTextViewer(name);

      expect(language != null, viewer == TextViewer.code, reason: name);
    }
  });

  test('test_find_syntax_language_for_property_only_the_last_part_counts', () {
    final Random random = seededRandom(99206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String stem = randomHostileFileStem(random);
      final String code = pickOne(random, _codeExtensions);

      expect(findSyntaxLanguageFor('$stem.$code.txt'), isNull);
      expect(findSyntaxLanguageFor('$stem.txt.$code'), isNotNull);
      expect(findSyntaxLanguageFor('.$code'), isNull);
    }
  });

  test('test_choose_text_viewer_property_markdown_in_any_letter_case', () {
    final Random random = seededRandom(99207);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String extension = pickOne(random, _markdownExtensions);
      final String name =
          '${randomHostileFileStem(random)}.'
          '${_randomCasing(random, extension)}';

      expect(chooseTextViewer(name), TextViewer.markdown, reason: name);
    }
  });

  test('test_choose_text_viewer_property_media_never_reads_as_code', () {
    final Random random = seededRandom(99208);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name =
          '${randomHostileFileStem(random)}.'
          '${pickOne(random, _mediaExtensions)}';

      expect(chooseTextViewer(name), TextViewer.plain, reason: name);
    }
  });

  test('test_describe_known_file_kind_property_ignores_letter_case', () {
    final Random random = seededRandom(99209);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String stem = randomHostileFileStem(random);
      final String extension = pickOne(random, _mediaExtensions);
      final String cased = _randomCasing(random, extension);

      expect(
        describeKnownFileKind('$stem.$cased'),
        describeKnownFileKind('file.$extension'),
      );
      expect(describeKnownFileKind('$stem.$cased'), isNotNull);
    }
  });

  test('test_describe_known_file_kind_property_reads_as_a_noun_phrase', () {
    final Random random = seededRandom(99210);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomHostileFileName(random);
      final String? kind = describeKnownFileKind(name);
      if (kind == null) {
        continue;
      }
      final List<String> words = kind.split(' ');

      expect(_articles, contains(words.first), reason: kind);
      expect(words.length, greaterThan(1), reason: kind);
      expect(kind.trim(), kind);
    }
  });

  test('test_describe_known_file_kind_property_text_files_are_unknown', () {
    final Random random = seededRandom(99211);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String name = randomHostileFileName(random);
      final bool isText = chooseTextViewer(name) != TextViewer.plain;

      if (isText) {
        expect(describeKnownFileKind(name), isNull, reason: name);
      }
      expect(describeKnownFileKind(randomHostileFileStem(random)), isNull);
    }
  });
}
