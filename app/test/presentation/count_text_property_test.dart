import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/count_text.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_display_counts.dart';
import '../support/random_inputs.dart';

const List<int> _boundaryCounts = <int>[
  0,
  1,
  2,
  999,
  1000,
  1001,
  largestDisplayedCount,
];
final RegExp _groupedNumberPattern = RegExp(r'^\d{1,3}(,\d{3})*$');

int _pickCount(Random random, int iteration) {
  if (iteration < _boundaryCounts.length) {
    return _boundaryCounts[iteration];
  }
  return randomCountOfAnySize(random);
}

void main() {
  test('test_describe_count_property_singular_only_for_exactly_one', () {
    final Random random = seededRandom(97211);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = _pickCount(random, i);
      final String singular = 'one${randomHostileText(random)}';
      final String plural = 'many${randomHostileText(random)}';

      final String text = describeCount(
        count,
        singular: singular,
        plural: plural,
      );

      final String expectedNoun = count == 1 ? singular : plural;
      expect(text.endsWith(' $expectedNoun'), isTrue, reason: text);
    }
  });

  test('test_describe_count_property_number_round_trips_in_groups', () {
    final Random random = seededRandom(97212);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = _pickCount(random, i);

      final String text = describeCount(
        count,
        singular: 'task',
        plural: 'tasks',
      );
      final String number = text.split(' ').first;

      expect(_groupedNumberPattern.hasMatch(number), isTrue, reason: text);
      expect(int.parse(number.replaceAll(',', '')), count);
    }
  });

  test('test_describe_count_property_hostile_nouns_kept_verbatim', () {
    final Random random = seededRandom(97213);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = _pickCount(random, i);
      final String noun = randomHostileText(random);

      final String text = describeCount(count, singular: noun, plural: noun);
      final int nounStart = text.length - noun.length;

      expect(text.substring(nounStart), noun);
      expect(text.substring(0, nounStart).endsWith(' '), isTrue);
      expect(describeCount(count, singular: noun, plural: noun), text);
    }
  });

  test('test_describe_count_property_negative_counts_are_refused', () {
    final Random random = seededRandom(97214);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = -1 - randomCountOfAnySize(random);

      expect(
        () => describeCount(count, singular: 'repo', plural: 'repos'),
        throwsArgumentError,
      );
    }
  });
}
