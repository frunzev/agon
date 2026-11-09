import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/person_answers.dart';

import '../../support/people_facing_refusal_matchers.dart';
import '../../support/random_inputs.dart';
import 'support/mirrored_rule_tables.dart';

const List<String> _surroundingWhiteSpace = <String>[
  '',
  ' ',
  '\t',
  '\r\n',
  '\u00A0',
  '\u2028',
  '\u3000',
];

void _expectBlankVerdict(String answer, {required bool isBlank}) {
  final Matcher verdict = isBlank ? throwsPeopleFacingRefusal : returnsNormally;
  final String reason = answer.runes.toString();
  expect(() => refuseBlankAnswer(answer), verdict, reason: reason);
}

void main() {
  final List<SharedAnswerCase> sharedCases = readSharedAnswerCases();

  test('test_match_choice_property_agrees_with_shared_table', () {
    for (final SharedAnswerCase sharedCase in sharedCases) {
      final String? choice = matchChoice(
        sharedCase.answer,
        sharedCase.choices,
      );

      final String reason = sharedCase.answer.runes.toString();
      expect(choice, sharedCase.choice, reason: reason);
    }
  });

  test('test_match_choice_property_shared_table_ignores_padding', () {
    final Random random = seededRandom(87021);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SharedAnswerCase sharedCase = pickOne(random, sharedCases);
      final String leading = pickOne(random, _surroundingWhiteSpace);
      final String trailing = pickOne(random, _surroundingWhiteSpace);
      final String padded = '$leading${sharedCase.answer}$trailing';

      final String? choice = matchChoice(padded, sharedCase.choices);

      expect(choice, sharedCase.choice, reason: padded.runes.toString());
    }
  });

  test('test_refuse_blank_answer_property_agrees_with_shared_table', () {
    for (final SharedAnswerCase sharedCase in sharedCases) {
      _expectBlankVerdict(sharedCase.answer, isBlank: sharedCase.isBlank);
    }
  });

  test('test_refuse_blank_answer_property_shared_table_ignores_padding', () {
    final Random random = seededRandom(87022);

    for (int i = 0; i < propertyIterations; i += 1) {
      final SharedAnswerCase sharedCase = pickOne(random, sharedCases);
      final String leading = pickOne(random, _surroundingWhiteSpace);
      final String trailing = pickOne(random, _surroundingWhiteSpace);

      final String padded = '$leading${sharedCase.answer}$trailing';

      _expectBlankVerdict(padded, isBlank: sharedCase.isBlank);
    }
  });
}
