import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/icon_path_parser.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_inputs.dart';
import 'support/random_icon_paths.dart';

final RegExp _commandToken = RegExp(r'^[MmLlHhVvCcAaZz]$');
final RegExp _numberToken = RegExp(
  r'^[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?$',
);
const int _mostHostilePieces = 12;
const List<String> _hostilePieces = <String>[
  'M',
  'm',
  'L',
  'l',
  'H',
  'h',
  'V',
  'v',
  'C',
  'c',
  'A',
  'a',
  'Z',
  'z',
  'Q',
  'S',
  'T',
  'e',
  'E',
  '.',
  '-',
  '+',
  ',',
  ' ',
  '\n',
  '0',
  '1',
  '12.5',
  '-3',
  '.5',
  '1e3',
  '7E-1',
  '1e999',
  '-1e999',
  'NaN',
  '\u{1F600}',
  '٣',
];
const List<String> _separatorOnlyPaths = <String>[
  '',
  ' ',
  '\n\t',
  ',',
  ' , , ',
];

String _randomHostilePath(Random random) {
  if (random.nextInt(4) == 0) {
    return randomHostileText(random);
  }
  final StringBuffer buffer = StringBuffer();
  final int pieceCount = random.nextInt(_mostHostilePieces);
  for (int i = 0; i < pieceCount; i += 1) {
    buffer.write(pickOne(random, _hostilePieces));
  }
  return buffer.toString();
}

String _randomValidPath(Random random) {
  return spellIconPath(
    random,
    randomIconPathCommands(random),
    relativity: IconPathRelativity.mixed,
    letters: IconPathLetters.implicitRepeats,
  );
}

String _spellEveryLetterAbsolute(
  Random random,
  List<IconPathCommand> commands,
) {
  return spellIconPath(
    random,
    commands,
    relativity: IconPathRelativity.absolute,
    letters: IconPathLetters.everyCommand,
  );
}

void main() {
  test('test_tokenize_icon_path_property_hostile_text_fails_cleanly_or_gives_'
      'only_commands_and_numbers', () {
    final Random random = seededRandom(90401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String pathData = _randomHostilePath(random);
      final List<String> tokens;
      try {
        tokens = tokenizeIconPath(pathData);
      } on FormatException {
        continue;
      }
      for (final String token in tokens) {
        final bool isKnownToken =
            _commandToken.hasMatch(token) || _numberToken.hasMatch(token);
        expect(isKnownToken, isTrue, reason: '$token in $pathData');
      }
    }
  });

  test('test_tokenize_icon_path_property_tokenizing_the_tokens_again_changes_'
      'nothing', () {
    final Random random = seededRandom(90402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String pathData = _randomValidPath(random);
      final List<String> tokens = tokenizeIconPath(pathData);

      final List<String> again = tokenizeIconPath(tokens.join(' '));

      expect(again, tokens, reason: pathData);
    }
  });

  test('test_tokenize_icon_path_property_every_number_spelling_is_one_'
      'token', () {
    final Random random = seededRandom(90403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double number = randomGridNumber(random);
      for (final String spelling in listNumberSpellings(number)) {
        final List<String> tokens = tokenizeIconPath('M$spelling');

        expect(tokens, <String>['M', spelling]);
      }
    }
  });

  test('test_parse_icon_path_property_hostile_text_never_crashes_or_'
      'loops', () {
    final Random random = seededRandom(90404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String pathData = _randomHostilePath(random);
      try {
        final Rect bounds = parseIconPath(pathData).getBounds();
        expect(bounds.isFinite, isTrue, reason: pathData);
      } on FormatException {
        continue;
      }
    }
  });

  test('test_parse_icon_path_property_same_text_always_draws_the_same_'
      'path', () {
    final Random random = seededRandom(90405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String pathData = _randomValidPath(random);

      final String first = describePathGeometry(parseIconPath(pathData));
      final String second = describePathGeometry(parseIconPath(pathData));

      expect(second, first, reason: pathData);
    }
  });

  test('test_icon_path_builder_build_property_numbers_before_any_command_'
      'fail', () {
    final Random random = seededRandom(90406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String number = spellIconPathNumber(
        random,
        randomGridNumber(random),
      );
      final String pathData = '$number ${_randomValidPath(random)}';

      expect(() => parseIconPath(pathData), throwsFormatException);
    }
  });

  test('test_icon_path_builder_build_property_numbers_right_after_a_close_'
      'fail', () {
    final Random random = seededRandom(90407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String closeLetter = pickOne(random, <String>['Z', 'z']);
      final String number = spellIconPathNumber(
        random,
        randomGridNumber(random),
      );
      final String pathData =
          '${_randomValidPath(random)}$closeLetter $number 0';

      expect(
        () => parseIconPath(pathData),
        throwsFormatException,
        reason: pathData,
      );
    }
  });

  test('test_icon_path_builder_build_property_text_without_commands_draws_'
      'nothing', () {
    for (final String pathData in _separatorOnlyPaths) {
      final Path path = parseIconPath(pathData);

      expect(path.getBounds(), Rect.zero, reason: pathData);
      expect(path.computeMetrics().isEmpty, isTrue, reason: pathData);
    }
  });

  test('test_icon_path_builder_build_property_joined_paths_keep_every_'
      'contour', () {
    final Random random = seededRandom(90408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<IconPathCommand> first = randomIconPathCommands(random);
      final List<IconPathCommand> second = randomIconPathCommands(random);
      final String firstText = _spellEveryLetterAbsolute(random, first);
      final String secondText = _spellEveryLetterAbsolute(random, second);
      final String joinedText = '$firstText $secondText';

      final Path joined = parseIconPath(joinedText);
      final Path model = buildModelIconPath(<IconPathCommand>[
        ...first,
        ...second,
      ]);

      expect(
        describePathGeometry(joined),
        describePathGeometry(model),
        reason: joinedText,
      );
    }
  });
}
