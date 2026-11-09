import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';

import '../../support/random_inputs.dart';
import '../fakes/support/person_step_rigs.dart';
import 'support/contract_step_failures.dart';
import 'support/person_step_contract_rigs.dart';

const String _typePrefix = 'test_person_step_repository';
const int _iterations = 30;
const int _longestSequence = 6;

typedef _AnswerOutcome = ({String name, Object? failure});

Future<List<_AnswerOutcome>> _answerEverywhere(
  PersonStepContractWorld world,
  OpenPersonStep openStep,
  String answer,
) async {
  final List<_AnswerOutcome> outcomes = <_AnswerOutcome>[];
  for (final NamedPersonStepRepository implementation
      in world.implementations) {
    final Object? failure = await findStepFailure(
      () => implementation.repository.answerPersonStep(
        runId: openStep.runId,
        stepName: openStep.stepName,
        answer: answer,
      ),
    );
    outcomes.add((name: implementation.name, failure: failure));
  }
  return outcomes;
}

Future<void> _answerRandomly(
  Random random,
  PersonStepContractWorld world,
) async {
  final OpenPersonStep openStep = pickAskedStep(random, world);
  final List<_AnswerOutcome> outcomes = await _answerEverywhere(
    world,
    openStep,
    pickAnyAnswer(random, openStep),
  );
  final bool isFirstRefused = outcomes.first.failure != null;
  for (final _AnswerOutcome outcome in outcomes) {
    expect(outcome.failure != null, isFirstRefused, reason: '$outcome');
  }
}

void _expectListingsAgree(PersonStepContractWorld world) {
  final List<PersonStepKey> expected = describeListedSteps(
    world.implementations.first.repository,
  );
  for (final NamedPersonStepRepository implementation
      in world.implementations) {
    expect(
      describeListedSteps(implementation.repository),
      orderedEquals(expected),
      reason: implementation.name,
    );
  }
}

Future<PersonStepContractWorld> _buildAfterRandomAnswers(Random random) async {
  final PersonStepContractWorld world = await buildPersonStepWorld(random);
  final int stepCount = random.nextInt(_longestSequence);
  for (int step = 0; step < stepCount; step += 1) {
    await _answerRandomly(random, world);
  }
  return world;
}

void main() {
  test('${_typePrefix}_list_open_person_steps_property_every_'
      'implementation_lists_the_same_steps', () async {
    final Random random = seededRandom(85501);
    for (int i = 0; i < _iterations; i += 1) {
      final PersonStepContractWorld world = await buildPersonStepWorld(random);
      _expectListingsAgree(world);
      final int stepCount = 1 + random.nextInt(_longestSequence);

      for (int step = 0; step < stepCount; step += 1) {
        await _answerRandomly(random, world);
        _expectListingsAgree(world);
      }
    }
  });

  test('${_typePrefix}_list_open_person_steps_property_callers_cannot_'
      'change_the_listing', () async {
    final Random random = seededRandom(85502);
    for (int i = 0; i < _iterations; i += 1) {
      final PersonStepContractWorld world = await _buildAfterRandomAnswers(
        random,
      );

      for (final NamedPersonStepRepository implementation
          in world.implementations) {
        final List<OpenPersonStep> listed = implementation.repository
            .listOpenPersonSteps();
        final List<PersonStepKey> before = describePersonSteps(listed);
        final Object? failure = await findStepFailure(
          () async => listed.clear(),
        );

        expect(failure, isA<UnsupportedError>(), reason: implementation.name);
        expect(
          describeListedSteps(implementation.repository),
          orderedEquals(before),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_list_open_person_steps_property_lists_each_asked_'
      'step_at_most_once', () async {
    final Random random = seededRandom(85503);
    for (int i = 0; i < _iterations; i += 1) {
      final PersonStepContractWorld world = await _buildAfterRandomAnswers(
        random,
      );
      final Set<PersonStepKey> asked = describePersonSteps(world.askedSteps)
          .toSet();

      for (final NamedPersonStepRepository implementation
          in world.implementations) {
        final List<PersonStepKey> listed = describeListedSteps(
          implementation.repository,
        );
        expect(listed.toSet(), hasLength(listed.length));
        expect(asked.containsAll(listed), isTrue, reason: implementation.name);
      }
    }
  });

  test('${_typePrefix}_answer_person_step_property_a_matching_answer_'
      'closes_exactly_that_step', () async {
    final Random random = seededRandom(85504);
    for (int i = 0; i < _iterations; i += 1) {
      final PersonStepContractWorld world = await _buildAfterRandomAnswers(
        random,
      );
      final List<OpenPersonStep> listed = world
          .implementations
          .first
          .repository
          .listOpenPersonSteps();
      if (listed.isEmpty) {
        continue;
      }
      final OpenPersonStep answered = pickOne(random, listed);
      final List<PersonStepKey> expected = <PersonStepKey>[
        for (final PersonStepKey key in describePersonSteps(listed))
          if (key != describePersonSteps(<OpenPersonStep>[answered]).single)
            key,
      ];

      final List<_AnswerOutcome> outcomes = await _answerEverywhere(
        world,
        answered,
        pickMatchingAnswer(random, answered),
      );

      for (final _AnswerOutcome outcome in outcomes) {
        expect(outcome.failure, isNull, reason: outcome.name);
      }
      for (final NamedPersonStepRepository implementation
          in world.implementations) {
        expect(
          describeListedSteps(implementation.repository),
          orderedEquals(expected),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_answer_person_step_property_blank_answers_are_'
      'refused_without_change', () async {
    final Random random = seededRandom(85505);
    for (int i = 0; i < _iterations; i += 1) {
      final PersonStepContractWorld world = await _buildAfterRandomAnswers(
        random,
      );
      final OpenPersonStep openStep = pickAskedStep(random, world);
      final List<PersonStepKey> before = describeListedSteps(
        world.implementations.first.repository,
      );

      final List<_AnswerOutcome> outcomes = await _answerEverywhere(
        world,
        openStep,
        pickOne(random, blankPersonAnswers),
      );

      for (final _AnswerOutcome outcome in outcomes) {
        expect(
          outcome.failure,
          isA<PeopleFacingRefusal>(),
          reason: outcome.name,
        );
      }
      _expectListingsAgree(world);
      expect(
        describeListedSteps(world.implementations.first.repository),
        orderedEquals(before),
      );
    }
  });

  test('${_typePrefix}_answer_person_step_property_steps_no_longer_asked_'
      'are_refused_alike', () async {
    final Random random = seededRandom(85506);
    for (int i = 0; i < _iterations; i += 1) {
      final PersonStepContractWorld world = await _buildAfterRandomAnswers(
        random,
      );
      final Set<PersonStepKey> listed = describeListedSteps(
        world.implementations.first.repository,
      ).toSet();
      final List<OpenPersonStep> closed = <OpenPersonStep>[
        for (final OpenPersonStep openStep in world.askedSteps)
          if (!listed.contains(
            describePersonSteps(<OpenPersonStep>[openStep]).single,
          ))
            openStep,
      ];
      if (closed.isEmpty) {
        continue;
      }
      final OpenPersonStep openStep = pickOne(random, closed);

      final List<_AnswerOutcome> outcomes = await _answerEverywhere(
        world,
        openStep,
        pickMatchingAnswer(random, openStep),
      );

      for (final _AnswerOutcome outcome in outcomes) {
        expect(outcome.failure, isNotNull, reason: outcome.name);
      }
      _expectListingsAgree(world);
    }
  });
}
