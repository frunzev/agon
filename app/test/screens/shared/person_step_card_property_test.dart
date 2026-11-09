import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/shared/person_step_card.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/person_step_card_harness.dart';

const String _questionTitleEnd = ' asks you';

void main() {
  test('test_describe_question_title_property_names_the_step_first', () {
    final Random random = seededRandom(111401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String stepName = randomHostileText(random);

      final String title = describeQuestionTitle(stepName);

      expect(title, startsWith(stepName));
      expect(title, endsWith(_questionTitleEnd));
      expect(title.length, stepName.length + _questionTitleEnd.length);
    }
  });

  test('test_describe_question_title_property_distinct_steps_differ', () {
    final Random random = seededRandom(111402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String first = randomHostileText(random);
      final String second = randomHostileText(random);

      final bool titlesMatch =
          describeQuestionTitle(first) == describeQuestionTitle(second);

      expect(titlesMatch, first == second);
    }
  });

  test('test_describe_question_title_property_round_trips_the_name', () {
    final Random random = seededRandom(111403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String stepName = randomHostileText(random);

      final String title = describeQuestionTitle(stepName);
      final String recovered = title.substring(
        0,
        title.length - _questionTitleEnd.length,
      );

      expect(recovered, stepName);
    }
  });

  test('test_describe_answer_problem_property_keeps_all_but_the_first', () {
    final Random random = seededRandom(111404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String problem = randomHostileText(random);

      final String shown = describeAnswerProblem(problem);

      if (problem.isEmpty) {
        expect(shown, isEmpty);
      } else {
        expect(shown, endsWith(problem.substring(1)));
        expect(shown.length, greaterThanOrEqualTo(problem.length));
      }
    }
  });

  test('test_describe_answer_problem_property_starts_upper_case', () {
    final Random random = seededRandom(111405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String problem = randomHostileText(random);

      final String shown = describeAnswerProblem(problem);

      if (shown.isNotEmpty) {
        expect(shown[0], shown[0].toUpperCase(), reason: problem);
      }
      final bool startsUpperCase =
          problem.isNotEmpty && problem[0] == problem[0].toUpperCase();
      if (startsUpperCase) {
        expect(shown, problem);
      }
    }
  });

  test('test_describe_answer_problem_property_is_idempotent', () {
    final Random random = seededRandom(111406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String problem = randomHostileText(random);

      final String once = describeAnswerProblem(problem);

      expect(describeAnswerProblem(once), once);
    }
  });

  test('test_person_step_card_property_keeps_every_field', () {
    final Random random = seededRandom(111407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final HeldPersonStepRepository repository = HeldPersonStepRepository();
      final PersonStepCard built = buildRandomCard(random, repository);

      final PersonStepCard card = PersonStepCard(
        openStep: built.openStep,
        incomingResults: built.incomingResults,
        contextLine: built.contextLine,
        personStepRepository: repository,
      );

      expect(card.openStep, same(built.openStep));
      expect(card.incomingResults, same(built.incomingResults));
      expect(card.contextLine, built.contextLine);
      expect(card.personStepRepository, same(repository));
    }
  });

  test('test_person_step_card_property_keeps_the_given_key', () {
    final Random random = seededRandom(111408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomHostileText(random));
      final PersonStepCard built = buildRandomCard(
        random,
        HeldPersonStepRepository(),
      );

      final PersonStepCard card = PersonStepCard(
        key: key,
        openStep: built.openStep,
        incomingResults: built.incomingResults,
        contextLine: built.contextLine,
        personStepRepository: built.personStepRepository,
      );

      expect(card.key, key);
    }
  });

  testWidgets('test_person_step_card_property_shows_the_given_question', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111409);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PersonStepCard card = buildRandomCard(
        random,
        HeldPersonStepRepository(),
      );

      await pumpCard(tester, width: randomCardWidth(random), card: card);

      final PersonStepCard shown = tester.widget<PersonStepCard>(
        find.byType(PersonStepCard),
      );
      expect(shown.openStep, same(card.openStep));
      expect(tester.takeException(), isNull);
    }
  });
}
