import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflow_builder.dart';

import '../../support/random_inputs.dart';

const int _roundReach = 1000;
const int _largestChoiceCount = 20;
const List<int> _documentedRounds = <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10];

int? _randomRounds(Random random) {
  if (random.nextInt(5) == 0) {
    return null;
  }
  return random.nextInt(2 * _roundReach) - _roundReach;
}

int? _randomValidLimit(Random random) {
  if (random.nextInt(4) == 0) {
    return null;
  }
  return pickOne(random, _documentedRounds);
}

void main() {
  test('test_round_limit_choice_constructor_property_keeps_rounds', () {
    final Random random = seededRandom(117901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int? rounds = _randomRounds(random);

      expect(RoundLimitChoice(rounds).rounds, rounds);
    }
  });

  test('test_round_limit_choice_constructor_property_no_choice_is_null', () {
    final Random random = seededRandom(117902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int rounds = random.nextInt(_roundReach);

      expect(const RoundLimitChoice(null).rounds, isNull);
      expect(RoundLimitChoice(rounds).rounds, isNotNull);
    }
  });

  test('test_round_limit_choice_constructor_property_const_is_shared', () {
    expect(
      identical(const RoundLimitChoice(3), const RoundLimitChoice(3)),
      isTrue,
    );
    expect(
      identical(const RoundLimitChoice(3), const RoundLimitChoice(4)),
      isFalse,
    );
  });

  test('test_round_limit_choice_equals_property_equal_iff_same_rounds', () {
    final Random random = seededRandom(117903);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int? first = _randomValidLimit(random);
      final int? second = _randomValidLimit(random);

      expect(
        RoundLimitChoice(first) == RoundLimitChoice(second),
        first == second,
      );
    }
  });

  test('test_round_limit_choice_equals_property_reflexive_and_symmetric', () {
    final Random random = seededRandom(117904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RoundLimitChoice first = RoundLimitChoice(_randomRounds(random));
      final RoundLimitChoice second = RoundLimitChoice(_randomRounds(random));

      expect(first == RoundLimitChoice(first.rounds), isTrue);
      expect(first == second, second == first);
    }
  });

  test('test_round_limit_choice_equals_property_other_types_differ', () {
    final Random random = seededRandom(117905);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int rounds = random.nextInt(_roundReach);
      final Object choice = RoundLimitChoice(rounds);

      expect(choice == rounds, isFalse);
      expect(choice == '$rounds', isFalse);
      expect(choice == const AgentKindChoice(null), isFalse);
    }
  });

  test('test_round_limit_choice_hash_code_property_equal_choices_match', () {
    final Random random = seededRandom(117906);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int? rounds = _randomRounds(random);

      expect(
        RoundLimitChoice(rounds).hashCode,
        RoundLimitChoice(rounds).hashCode,
      );
    }
  });

  test('test_round_limit_choice_hash_code_property_sets_drop_repeats', () {
    final Random random = seededRandom(117907);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = random.nextInt(_largestChoiceCount);
      final List<int?> rounds = <int?>[
        for (int index = 0; index < count; index += 1)
          _randomValidLimit(random),
      ];

      final Set<RoundLimitChoice> choices = <RoundLimitChoice>{
        for (final int? round in rounds) RoundLimitChoice(round),
      };

      expect(choices.length, rounds.toSet().length);
    }
  });

  test('test_round_limit_choice_hash_code_property_stable_between_reads', () {
    final Random random = seededRandom(117908);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RoundLimitChoice choice = RoundLimitChoice(_randomRounds(random));

      expect(choice.hashCode, choice.hashCode);
    }
  });
}
