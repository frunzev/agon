import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_inputs.dart';

const List<String> _uppercaseLetters = <String>[
  'A',
  'Z',
  'Ü',
  'Σ',
  'Ж',
  '\u{10400}',
  '\u{1E900}',
];
const int _largestMinutesAgo = 60 * 24 * 30;

String _randomTextStartingUppercase(Random random) {
  return '${pickOne(random, _uppercaseLetters)}${randomHostileText(random)}';
}

String _dropFirstCharacter(String text) {
  return String.fromCharCodes(text.runes.skip(1));
}

void main() {
  test('test_lowercase_first_letter_property_keeps_the_rest', () {
    final Random random = seededRandom(930701);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = random.nextBool()
          ? _randomTextStartingUppercase(random)
          : randomHostileText(random);

      final String lowered = lowercaseFirstLetter(text);

      expect(lowered, endsWith(_dropFirstCharacter(text)));
      expect(lowered.isEmpty, text.isEmpty);
    }
  });

  test('test_lowercase_first_letter_property_is_idempotent', () {
    final Random random = seededRandom(930702);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = random.nextBool()
          ? _randomTextStartingUppercase(random)
          : randomHostileText(random);

      final String lowered = lowercaseFirstLetter(text);

      expect(lowercaseFirstLetter(lowered), lowered);
    }
  });

  test('test_lowercase_first_letter_property_first_letter_is_lowercase', () {
    final Random random = seededRandom(930703);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String letter = pickOne(random, _uppercaseLetters);
      final String rest = randomHostileText(random);

      final String lowered = lowercaseFirstLetter('$letter$rest');

      expect(lowered, '${letter.toLowerCase()}$rest');
    }
  });

  test('test_lowercase_first_letter_property_time_phrases_read_inline', () {
    final Random random = seededRandom(930704);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final DateTime moment = now.subtract(
        Duration(minutes: random.nextInt(_largestMinutesAgo)),
      );
      final String phrase = describeTimeSince(moment, now);

      final String lowered = lowercaseFirstLetter(phrase);

      expect(lowered, phrase.replaceFirst(phrase[0], phrase[0].toLowerCase()));
      expect(lowered, isNot(contains('Just')));
      expect(lowered, isNot(contains('Yesterday')));
    }
  });
}
