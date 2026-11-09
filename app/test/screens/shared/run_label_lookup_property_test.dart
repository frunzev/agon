import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/shared/run_label_lookup.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/person_step_question_scenes.dart';

String? _findSceneRunLabel(QuestionScene scene, RunId runId) {
  return findRunLabel(
    runId: runId,
    taskRepository: scene.taskRepository,
    workflows: scene.workflowRepository.listWorkflows(),
  );
}

void main() {
  test('test_find_run_label_property_names_the_doer_and_run_number', () {
    final Random random = seededRandom(111301);
    final QuestionScene scene = buildGalleryQuestionScene();
    final List<Workflow> workflows = scene.workflowRepository.listWorkflows();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = pickSceneRun(random, scene);
      final Task task = scene.taskRepository.findTask(run.taskId);
      final TaskDoer doer = task.doer;
      final String expectedName = switch (doer) {
        OneAgentDoer() => task.title,
        WorkflowDoer(:final WorkflowId workflowId) =>
          workflows
              .firstWhere((Workflow workflow) => workflow.id == workflowId)
              .name,
      };

      final String? label = _findSceneRunLabel(scene, run.id);

      expect(label, '$expectedName #${run.number}');
    }
  });

  test('test_find_run_label_property_unlisted_task_or_run_has_no_label', () {
    final Random random = seededRandom(111302);
    final QuestionScene emptyScene = buildSceneWithoutTasks();
    final QuestionScene gallery = buildGalleryQuestionScene();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Run run = pickSceneRun(random, emptyScene);
      final RunId unknownRunId = RunId('unknown ${randomHostileText(random)}');

      expect(_findSceneRunLabel(emptyScene, run.id), isNull);
      expect(_findSceneRunLabel(gallery, unknownRunId), isNull);
    }
  });

  test('test_find_run_label_property_a_gone_workflow_never_throws', () {
    final Random random = seededRandom(111303);

    for (int i = 0; i < 60; i += 1) {
      final QuestionScene scene = buildSceneWithGoneWorkflows(random);
      final Run run = pickSceneRun(random, scene);
      final Task task = scene.taskRepository.findTask(run.taskId);

      final String? label = _findSceneRunLabel(scene, run.id);

      if (task.doer is WorkflowDoer) {
        expect(label, isNull);
      } else {
        expect(label, '${task.title} #${run.number}');
      }
    }
  });
}
