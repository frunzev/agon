import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/icon_path_parser.dart';

import '../support/random_inputs.dart';
import 'support/random_icon_paths.dart';

const int _smallestOverflowingExponent = 309;
const int _overflowingExponentSpan = 700;
const int _mostExtraPairs = 4;
const List<String> _numberLikeGarbage = <String>[
  '1e',
  '1e+',
  '.',
  '-',
  '+',
  '--1',
  '+-1',
  '1..',
  'NaN',
  'Infinity',
  '٣',
  '1_000',
  '0x10',
  'e5',
  '1f',
];
const List<IconPathStep> _stepsWithNumbers = <IconPathStep>[
  IconPathStep.move,
  IconPathStep.line,
  IconPathStep.horizontal,
  IconPathStep.vertical,
  IconPathStep.curve,
  IconPathStep.arc,
];

String _spellGridNumbers(Random random, int count) {
  final List<String> spelled = <String>[];
  for (int i = 0; i < count; i += 1) {
    spelled.add(spellIconPathNumber(random, randomGridNumber(random)));
  }
  return spelled.join(' ');
}

String _spellCommandArguments(IconPathCommand command) {
  final List<String> spelled = <String>[];
  for (final double number in command.numbers) {
    spelled.add(spellPlainNumber(number));
  }
  return spelled.join(' ');
}

void main() {
  test('test_read_number_property_every_spelling_reads_the_same_value', () {
    final Random random = seededRandom(90501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double number = randomGridNumber(random);
      for (final String spelling in listNumberSpellings(number)) {
        final Rect bounds = parseIconPath('M0 0H$spelling').getBounds();

        expect(bounds.left, min(0, number), reason: spelling);
        expect(bounds.right, max(0, number), reason: spelling);
      }
    }
  });

  test('test_read_number_property_overflowing_numbers_never_reach_the_'
      'path', () {
    final Random random = seededRandom(90502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int exponent =
          _smallestOverflowingExponent +
          random.nextInt(_overflowingExponentSpan);
      final String sign = pickOne(random, <String>['', '-', '+']);
      final String pathData = 'M0 0L${sign}1e$exponent 4';

      expect(
        () => parseIconPath(pathData),
        throwsFormatException,
        reason: pathData,
      );
    }
  });

  test('test_read_number_property_number_like_garbage_fails_with_a_format_'
      'exception', () {
    final Random random = seededRandom(90503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String garbage = pickOne(random, _numberLikeGarbage);
      final String pathData = 'M0 0L$garbage 4';

      expect(
        () => parseIconPath(pathData),
        throwsFormatException,
        reason: pathData,
      );
    }
  });

  test('test_read_point_property_every_separator_spelling_draws_the_same_'
      'point', () {
    final Random random = seededRandom(90504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final double horizontal = randomGridNumber(random);
      final double vertical = randomGridNumber(random);
      final List<String> spelled = <String>[
        spellIconPathNumber(random, horizontal),
        spellIconPathNumber(random, vertical),
      ];
      final String pathData = 'M0 0L${joinIconPathNumbers(random, spelled)}';
      final String plainData =
          'M0 0L${spellPlainNumber(horizontal)} ${spellPlainNumber(vertical)}';

      expect(
        describePathGeometry(parseIconPath(pathData)),
        describePathGeometry(parseIconPath(plainData)),
        reason: pathData,
      );
    }
  });

  test('test_read_point_property_an_odd_coordinate_count_fails', () {
    final Random random = seededRandom(90505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String letter = pickOne(random, <String>['M', 'm', 'L', 'l']);
      final int count = 1 + 2 * random.nextInt(_mostExtraPairs);
      final String pathData =
          'M0 0$letter${_spellGridNumbers(random, count)}';

      expect(
        () => parseIconPath(pathData),
        throwsFormatException,
        reason: pathData,
      );
    }
  });

  test('test_read_point_property_pairs_after_a_move_are_lines_from_it', () {
    final Random random = seededRandom(90506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<IconPathCommand> commands = <IconPathCommand>[
        randomIconPathCommand(random, IconPathStep.move),
      ];
      final int pairCount = 1 + random.nextInt(_mostExtraPairs);
      final StringBuffer implicitText = StringBuffer(
        'M${_spellCommandArguments(commands.first)}',
      );
      for (int j = 0; j < pairCount; j += 1) {
        final IconPathCommand line = randomIconPathCommand(
          random,
          IconPathStep.line,
        );
        commands.add(line);
        implicitText.write(' ${_spellCommandArguments(line)}');
      }

      expect(
        describePathGeometry(parseIconPath(implicitText.toString())),
        describePathGeometry(buildModelIconPath(commands)),
        reason: implicitText.toString(),
      );
    }
  });

  test('test_require_numbers_property_a_command_cut_short_by_the_next_'
      'letter_fails', () {
    final Random random = seededRandom(90507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final IconPathStep step = pickOne(random, _stepsWithNumbers);
      final int count = random.nextInt(step.numberCount);
      final String letter = random.nextBool()
          ? step.letter
          : step.letter.toLowerCase();
      final String pathData =
          'M0 0$letter${_spellGridNumbers(random, count)}L4 4';

      expect(
        () => parseIconPath(pathData),
        throwsFormatException,
        reason: pathData,
      );
    }
  });

  test('test_require_numbers_property_a_text_cut_inside_a_command_'
      'fails', () {
    final Random random = seededRandom(90508);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<IconPathCommand> commands = randomIconPathCommands(random);
      final IconPathStep step = pickOne(random, <IconPathStep>[
        IconPathStep.move,
        IconPathStep.line,
        IconPathStep.curve,
        IconPathStep.arc,
      ]);
      final IconPathCommand cutCommand = randomIconPathCommand(random, step);
      final int keptCount = 1 + random.nextInt(step.numberCount - 1);
      final List<String> keptNumbers = <String>[];
      for (int j = 0; j < keptCount; j += 1) {
        keptNumbers.add(spellPlainNumber(cutCommand.numbers[j]));
      }
      final String wholeCommands = spellIconPath(
        random,
        commands,
        relativity: IconPathRelativity.mixed,
        letters: IconPathLetters.everyCommand,
      );
      final String pathData =
          '$wholeCommands${step.letter}${keptNumbers.join(' ')}';

      expect(
        () => parseIconPath(pathData),
        throwsFormatException,
        reason: pathData,
      );
    }
  });

  test('test_require_numbers_property_whole_groups_parse_and_partial_groups_'
      'fail', () {
    final Random random = seededRandom(90509);

    for (int i = 0; i < propertyIterations; i += 1) {
      final IconPathStep step = pickOne(random, _stepsWithNumbers);
      final int groupCount = 1 + random.nextInt(_mostExtraPairs);
      final int extraCount = random.nextInt(step.numberCount);
      final int count = groupCount * step.numberCount + extraCount;
      final String pathData =
          'M0 0${step.letter}${_spellGridNumbers(random, count)}';

      if (extraCount == 0) {
        expect(parseIconPath(pathData).getBounds().isFinite, isTrue);
      } else {
        expect(() => parseIconPath(pathData), throwsFormatException);
      }
    }
  });
}
