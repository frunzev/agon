import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/presentation/step_round_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/shared/person_step_card.dart';
import 'package:agent_orchestration/screens/shared/person_step_questions.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/person_step_question_scenes.dart';

const String _askedPrefix = 'Asked ';
const String _waitingText = 'Waiting for your answer';
const int _largestMinutesInAnHour = 59;

List<OpenPersonStep> _randomQuestions(Random random, List<RunId> runIds) {
  final int count = random.nextInt(8);
  return <OpenPersonStep>[
    for (int index = 0; index < count; index += 1)
      randomQuestionWithIdentity(
        random,
        runId: pickOne(random, runIds),
        stepName: randomHostileText(random),
      ),
  ];
}

List<RunId> _randomRunIds(Random random) {
  final int count = 1 + random.nextInt(4);
  return <RunId>[
    for (int index = 0; index < count; index += 1)
      RunId('run ${random.nextInt(5)}'),
  ];
}

PersonStepCard _buildRunPageCard(
  QuestionScene scene,
  OpenPersonStep openStep,
  Run run,
) {
  return scene.questions.buildCardOnRunPage(
    openStep: openStep,
    run: run,
    workflow: findSceneWorkflow(scene, run),
    now: galleryNow,
  ) as PersonStepCard;
}

void main() {
  test('test_describe_asked_time_property_no_moment_waits_for_answer', () {
    final Random random = seededRandom(111101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);

      expect(describeAskedTime(null, now), _waitingText);
    }
  });

  test('test_describe_asked_time_property_reads_asked_then_lowercase', () {
    final Random random = seededRandom(111102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final DateTime askedAt = randomLocalMoment(random);

      final String shown = describeAskedTime(askedAt, now);
      final String phrase = shown.substring(_askedPrefix.length);
      final String timeSince = describeTimeSince(askedAt, now);

      expect(shown, startsWith(_askedPrefix));
      expect(phrase[0], phrase[0].toLowerCase(), reason: shown);
      expect(phrase.toLowerCase(), timeSince.toLowerCase());
      expect(phrase.substring(1), timeSince.substring(1));
    }
  });

  test('test_describe_asked_time_property_recent_reads_minutes_ago', () {
    final Random random = seededRandom(111103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomLocalMoment(random);
      final int minutes = 1 + random.nextInt(_largestMinutesInAnHour);
      final DateTime askedAt = now.subtract(Duration(minutes: minutes));

      expect(describeAskedTime(askedAt, now), 'Asked $minutes min ago');
    }
  });

  test('test_find_questions_for_run_property_keeps_only_that_run', () {
    final Random random = seededRandom(111104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RunId> runIds = _randomRunIds(random);
      final List<OpenPersonStep> openSteps = _randomQuestions(random, runIds);
      final RunId runId = pickOne(random, runIds);

      final List<OpenPersonStep> found = findQuestionsForRun(openSteps, runId);

      final List<OpenPersonStep> expected = <OpenPersonStep>[];
      for (final OpenPersonStep openStep in openSteps) {
        if (openStep.runId == runId) {
          expected.add(openStep);
        }
      }
      expect(found, orderedEquals(expected));
    }
  });

  test('test_find_questions_for_run_property_runs_partition_the_list', () {
    final Random random = seededRandom(111105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<RunId> runIds = _randomRunIds(random);
      final List<OpenPersonStep> openSteps = _randomQuestions(random, runIds);

      int foundCount = 0;
      for (final RunId runId in runIds.toSet()) {
        foundCount += findQuestionsForRun(openSteps, runId).length;
      }

      expect(foundCount, openSteps.length);
    }
  });

  test(
    'test_find_questions_for_run_property_idempotent_and_unknown_empty',
    () {
      final Random random = seededRandom(111106);

      for (int i = 0; i < propertyIterations; i += 1) {
        final List<RunId> runIds = _randomRunIds(random);
        final List<OpenPersonStep> openSteps = _randomQuestions(
          random,
          runIds,
        );
        final RunId runId = pickOne(random, runIds);
        final RunId unknownRunId = RunId('unknown ${randomText(random)}');

        final List<OpenPersonStep> once = findQuestionsForRun(
          openSteps,
          runId,
        );
        final List<OpenPersonStep> twice = findQuestionsForRun(once, runId);

        expect(twice, orderedEquals(once));
        expect(findQuestionsForRun(openSteps, unknownRunId), isEmpty);
      }
    },
  );

  test('test_person_step_questions_property_keeps_every_repository', () {
    for (int i = 0; i < 20; i += 1) {
      final QuestionScene scene = buildGalleryQuestionScene();

      expect(scene.questions.taskRepository, same(scene.taskRepository));
      expect(
        scene.questions.workflowRepository,
        same(scene.workflowRepository),
      );
      expect(
        scene.questions.personStepRepository,
        same(scene.personStepRepository),
      );
    }
  });

  test('test_person_step_questions_property_cards_answer_through_it', () {
    final Random random = seededRandom(111108);

    for (int i = 0; i < 40; i += 1) {
      final QuestionScene scene = buildGalleryQuestionScene();
      final Run run = pickOne(random, listQuestionSceneRuns());
      final OpenPersonStep openStep = randomQuestionOn(random, run);

      final PersonStepCard runPageCard = _buildRunPageCard(
        scene,
        openStep,
        run,
      );
      final PersonStepCard approvalsCard =
          scene.questions.buildCardInApprovals(
            openStep: openStep,
            now: galleryNow,
          ) as PersonStepCard;

      expect(
        runPageCard.personStepRepository,
        same(scene.personStepRepository),
      );
      expect(
        approvalsCard.personStepRepository,
        same(scene.personStepRepository),
      );
    }
  });

  test('test_person_step_questions_property_builders_stay_apart', () {
    final Random random = seededRandom(111109);

    for (int i = 0; i < 40; i += 1) {
      final QuestionScene first = buildGalleryQuestionScene();
      final QuestionScene second = buildGalleryQuestionScene();
      final Run run = pickOne(random, listQuestionSceneRuns());
      final OpenPersonStep openStep = randomQuestionOn(random, run);

      final PersonStepCard firstCard = _buildRunPageCard(first, openStep, run);
      final PersonStepCard secondCard = _buildRunPageCard(
        second,
        openStep,
        run,
      );

      final FakePersonStepRepository firstRepository =
          firstCard.personStepRepository as FakePersonStepRepository;
      expect(firstRepository, same(first.personStepRepository));
      expect(secondCard.personStepRepository, isNot(same(firstRepository)));
    }
  });

  test('test_build_card_on_run_page_property_context_is_the_asked_time', () {
    final Random random = seededRandom(111110);
    final QuestionScene scene = buildGalleryQuestionScene();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = pickOne(random, listQuestionSceneRuns());
      final OpenPersonStep openStep = randomQuestionOn(random, run);

      final PersonStepCard card = _buildRunPageCard(scene, openStep, run);

      expect(card.openStep, same(openStep));
      expect(
        card.contextLine,
        describeAskedTime(openStep.askedAt, galleryNow),
      );
    }
  });

  test('test_build_card_on_run_page_property_shows_what_came_in', () {
    final Random random = seededRandom(111111);
    final QuestionScene scene = buildGalleryQuestionScene();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = pickOne(random, listQuestionSceneRuns());
      final OpenPersonStep openStep = randomQuestionOn(random, run);

      final PersonStepCard card = _buildRunPageCard(scene, openStep, run);

      expect(
        card.incomingResults,
        orderedEquals(
          findIncomingResults(
            run: run,
            workflow: findSceneWorkflow(scene, run),
            stepName: openStep.stepName,
          ),
        ),
      );
      for (final RunStep step in card.incomingResults) {
        expect(run.steps, contains(step));
        expect(step.result, isNotNull);
      }
    }
  });

  test('test_build_card_on_run_page_property_one_key_per_question', () {
    final Random random = seededRandom(111112);
    final QuestionScene scene = buildGalleryQuestionScene();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = pickOne(random, listQuestionSceneRuns());
      final OpenPersonStep first = randomQuestionOn(random, run);
      final OpenPersonStep again = randomQuestionWithIdentity(
        random,
        runId: first.runId,
        stepName: first.stepName,
      );

      final PersonStepCard firstCard = _buildRunPageCard(scene, first, run);
      final PersonStepCard againCard = _buildRunPageCard(scene, again, run);

      expect(firstCard.key, isNotNull);
      expect(againCard.key, firstCard.key);
    }
  });
}
