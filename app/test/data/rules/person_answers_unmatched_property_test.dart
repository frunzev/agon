import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/person_answers.dart';

import '../../support/random_branching_workflows.dart';
import '../../support/random_inputs.dart';

const String _messageStart = 'the answer names none of the choices: ';
const String _choiceSeparator = ', ';

List<String> _randomChoices(Random random) {
  final List<String> choices = List<String>.of(sampleOutcomes);
  choices.shuffle(random);
  return choices.sublist(0, random.nextInt(choices.length + 1));
}

void main() {
  test('test_describe_unmatched_answer_property_round_trips_choices', () {
    final Random random = seededRandom(87901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> choices = _randomChoices(random);
      if (choices.isEmpty) {
        continue;
      }

      final String problem = describeUnmatchedAnswer(choices);

      final String listed = problem.substring(_messageStart.length);
      expect(listed.split(_choiceSeparator), choices);
    }
  });

  test('test_describe_unmatched_answer_property_a_new_choice_extends_it', () {
    final Random random = seededRandom(87902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> choices = _randomChoices(random);
      final String addedChoice = pickOne(random, sampleOutcomes);

      final String problem = describeUnmatchedAnswer(choices);
      final String extended = describeUnmatchedAnswer(<String>[
        ...choices,
        addedChoice,
      ]);

      expect(extended, startsWith(problem));
      expect(extended, endsWith(addedChoice));
    }
  });
}
