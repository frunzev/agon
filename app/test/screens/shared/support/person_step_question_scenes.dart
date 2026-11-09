import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/screens/shared/person_step_questions.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../data/fakes/support/workflow_usage_inputs.dart';
import '../../../support/person_step_dependencies.dart';
import '../../../support/random_inputs.dart';
import '../../../support/workflow_repositories.dart';

const int _largestMinutesAgo = 60 * 24 * 9;

final class QuestionScene {
  QuestionScene({required List<Task> tasks, required List<Run> runs})
    : workflowRepository = buildGalleryWorkflowRepository() {
    taskRepository = FakeTaskRepository(
      tasks: tasks,
      runs: runs,
      clock: FixedClock(galleryNow),
      currentDeviceId: GalleryDeviceIds.airLaptop,
      workflowRepository: workflowRepository,
    );
    personStepRepository = FakePersonStepRepository(
      openSteps: const <OpenPersonStep>[],
      taskRepository: taskRepository,
    );
    questions = PersonStepQuestions(
      taskRepository: taskRepository,
      workflowRepository: workflowRepository,
      personStepRepository: personStepRepository,
    );
  }

  final FakeWorkflowRepository workflowRepository;
  late final FakeTaskRepository taskRepository;
  late final FakePersonStepRepository personStepRepository;
  late final PersonStepQuestions questions;
}

List<Run> listQuestionSceneRuns() {
  return <Run>[
    buildRunWaitingForYou(notes: const <RunNote>[]),
    for (final Run run in galleryRuns)
      if (run.id != GalleryRunIds.release42) run,
  ];
}

QuestionScene buildGalleryQuestionScene() {
  return QuestionScene(
    tasks: <Task>[...galleryTasks, ...galleryJobs],
    runs: listQuestionSceneRuns(),
  );
}

DateTime? randomAskedAt(Random random) {
  if (random.nextInt(4) == 0) {
    return null;
  }
  final int minutesAgo = random.nextInt(_largestMinutesAgo);
  return galleryNow.subtract(Duration(minutes: minutesAgo));
}

OpenPersonStep randomQuestionOn(Random random, Run run) {
  final List<String> stepNames = <String>[
    for (final RunStep step in run.steps) step.name,
    randomHostileText(random),
  ];
  return OpenPersonStep(
    runId: run.id,
    taskId: run.taskId,
    workspaceId: GalleryWorkspaceIds.acme,
    stepName: pickOne(random, stepNames),
    question: randomHostileText(random),
    choices: randomHostileTexts(random),
    askedAt: randomAskedAt(random),
  );
}

OpenPersonStep randomQuestionWithIdentity(
  Random random, {
  required RunId runId,
  required String stepName,
}) {
  return OpenPersonStep(
    runId: runId,
    taskId: TaskId(randomHostileText(random)),
    workspaceId: GalleryWorkspaceIds.acme,
    stepName: stepName,
    question: randomHostileText(random),
    choices: randomHostileTexts(random),
    askedAt: randomAskedAt(random),
  );
}

Run pickSceneRun(Random random, QuestionScene scene) {
  final Run pickedRun = pickOne(random, listQuestionSceneRuns());
  return scene.taskRepository.findRun(pickedRun.id);
}

QuestionScene buildSceneWithoutTasks() {
  return QuestionScene(tasks: const <Task>[], runs: listQuestionSceneRuns());
}

QuestionScene buildSceneWithGoneWorkflows(Random random) {
  final List<Task> tasks = <Task>[
    for (final Task task in <Task>[...galleryTasks, ...galleryJobs])
      if (task.doer is WorkflowDoer)
        buildWorkWithDoer(
          random,
          identifier: task.id.value,
          doer: WorkflowDoer(WorkflowId('gone ${randomHostileText(random)}')),
          schedule: task.schedule,
        )
      else
        task,
  ];
  return QuestionScene(tasks: tasks, runs: listQuestionSceneRuns());
}

Workflow? findSceneWorkflow(QuestionScene scene, Run run) {
  return findWorkflowForDoer(
    scene.taskRepository.findTask(run.taskId).doer,
    scene.workflowRepository.listWorkflows(),
  );
}
