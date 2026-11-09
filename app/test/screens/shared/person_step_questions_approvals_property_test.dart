import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/run_text.dart';
import 'package:agent_orchestration/presentation/step_round_text.dart';
import 'package:agent_orchestration/screens/shared/person_step_card.dart';
import 'package:agent_orchestration/screens/shared/person_step_questions.dart';
import 'package:agent_orchestration/screens/shared/run_label_lookup.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/person_step_question_scenes.dart';

const String _separator = ' · ';

PersonStepCard _buildApprovalsCard(
  QuestionScene scene,
  OpenPersonStep openStep,
) {
  return scene.questions.buildCardInApprovals(
    openStep: openStep,
    now: galleryNow,
  ) as PersonStepCard;
}

void _expectCardWithoutRun(PersonStepCard card, OpenPersonStep openStep) {
  expect(card.contextLine, describeAskedTime(openStep.askedAt, galleryNow));
  expect(card.incomingResults, isEmpty);
}

void main() {
  test('test_build_card_in_approvals_property_names_the_run_first', () {
    final Random random = seededRandom(111201);
    final QuestionScene scene = buildGalleryQuestionScene();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = pickSceneRun(random, scene);
      final OpenPersonStep openStep = randomQuestionOn(random, run);

      final PersonStepCard card = _buildApprovalsCard(scene, openStep);

      final String? runLabel = findRunLabel(
        runId: run.id,
        taskRepository: scene.taskRepository,
        workflows: scene.workflowRepository.listWorkflows(),
      );
      final String asked = describeAskedTime(openStep.askedAt, galleryNow);
      expect(runLabel, isNotNull);
      expect(
        card.contextLine,
        '$runLabel$_separator${lowercaseFirstLetter(asked)}',
      );
    }
  });

  test('test_build_card_in_approvals_property_unknown_runs_show_asked', () {
    final Random random = seededRandom(111202);
    final QuestionScene scene = buildGalleryQuestionScene();

    for (int i = 0; i < propertyIterations; i += 1) {
      final OpenPersonStep openStep = randomQuestionWithIdentity(
        random,
        runId: RunId('unknown ${randomHostileText(random)}'),
        stepName: randomHostileText(random),
      );

      _expectCardWithoutRun(_buildApprovalsCard(scene, openStep), openStep);
    }
  });

  test('test_build_card_in_approvals_property_unlisted_tasks_never_crash', () {
    final Random random = seededRandom(111203);
    final QuestionScene gallery = buildGalleryQuestionScene();
    final List<RunId> workflowRunIds = <RunId>[
      for (final Run run in listQuestionSceneRuns())
        if (gallery.taskRepository.findTask(run.taskId).doer is WorkflowDoer)
          run.id,
    ];

    for (int i = 0; i < propertyIterations; i += 1) {
      final QuestionScene scene = random.nextBool()
          ? buildSceneWithoutTasks()
          : buildSceneWithGoneWorkflows(random);
      final RunId runId = pickOne(random, workflowRunIds);
      final Run run = scene.taskRepository.findRun(runId);
      final OpenPersonStep openStep = randomQuestionOn(random, run);

      final PersonStepCard card = _buildApprovalsCard(scene, openStep);

      expect(card.openStep, same(openStep));
      _expectCardWithoutRun(card, openStep);
    }
  });

  test('test_build_card_property_distinct_questions_get_distinct_keys', () {
    final Random random = seededRandom(111204);
    final QuestionScene scene = buildGalleryQuestionScene();

    for (int i = 0; i < propertyIterations; i += 1) {
      final String word = randomWordPhrase(random);
      final OpenPersonStep first = randomQuestionWithIdentity(
        random,
        runId: RunId('run $word'),
        stepName: 'step',
      );
      final OpenPersonStep second = randomQuestionWithIdentity(
        random,
        runId: const RunId('run'),
        stepName: '$word step',
      );

      final Key? firstKey = _buildApprovalsCard(scene, first).key;
      final Key? secondKey = _buildApprovalsCard(scene, second).key;

      expect(firstKey, isNot(secondKey), reason: word);
    }
  });

  test('test_build_card_property_without_a_run_nothing_came_in', () {
    final Random random = seededRandom(111205);
    final QuestionScene scene = buildSceneWithoutTasks();

    for (int i = 0; i < propertyIterations; i += 1) {
      final OpenPersonStep openStep = randomQuestionWithIdentity(
        random,
        runId: RunId(randomHostileText(random)),
        stepName: randomHostileText(random),
      );

      _expectCardWithoutRun(_buildApprovalsCard(scene, openStep), openStep);
    }
  });

  test('test_build_card_property_carries_the_question_and_repository', () {
    final Random random = seededRandom(111206);
    final QuestionScene scene = buildGalleryQuestionScene();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = pickSceneRun(random, scene);
      final OpenPersonStep openStep = randomQuestionOn(random, run);

      final PersonStepCard card = _buildApprovalsCard(scene, openStep);

      expect(card.openStep, same(openStep));
      expect(card.personStepRepository, same(scene.personStepRepository));
    }
  });

  test(
    'test_build_card_in_approvals_property_incoming_results_follow_the_doer',
    () {
      final Random random = seededRandom(111207);
      final QuestionScene scene = buildGalleryQuestionScene();

      for (int i = 0; i < propertyIterations; i += 1) {
        final Run run = pickSceneRun(random, scene);
        final OpenPersonStep openStep = randomQuestionOn(random, run);

        final PersonStepCard card = _buildApprovalsCard(scene, openStep);

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
      }
    },
  );

  test(
    'test_build_card_in_approvals_property_one_agent_tasks_bring_nothing_in',
    () {
      final Random random = seededRandom(111208);
      final QuestionScene scene = buildGalleryQuestionScene();
      final List<Run> oneAgentRuns = <Run>[
        for (final Run run in listQuestionSceneRuns())
          if (scene.taskRepository.findTask(run.taskId).doer is OneAgentDoer)
            run,
      ];

      for (int i = 0; i < propertyIterations; i += 1) {
        final Run run = pickOne(random, oneAgentRuns);
        final OpenPersonStep openStep = randomQuestionOn(random, run);

        expect(_buildApprovalsCard(scene, openStep).incomingResults, isEmpty);
      }
    },
  );

  test(
    'test_build_card_in_approvals_property_a_gone_workflow_brings_nothing_in',
    () {
      final Random random = seededRandom(111209);

      for (int i = 0; i < 60; i += 1) {
        final QuestionScene scene = buildSceneWithGoneWorkflows(random);
        final Run run = pickSceneRun(random, scene);
        final OpenPersonStep openStep = randomQuestionOn(random, run);

        expect(_buildApprovalsCard(scene, openStep).incomingResults, isEmpty);
      }
    },
  );
}
