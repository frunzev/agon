import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/screens/tasks/created_task_start.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import 'task_form_screen_scene.dart';

const List<RepeatChoice> _repeats = <RepeatChoice>[
  RepeatChoice.hourly,
  RepeatChoice.daily,
  RepeatChoice.weekly,
];

Set<TaskId> _listJobIds(TaskFormScene scene) {
  return <TaskId>{
    for (final Task job in scene.dependencies.jobRepository.listJobs()) job.id,
  };
}

Task _findOnlyNewJob(TaskFormScene scene, Set<TaskId> jobIdsBefore) {
  return scene.dependencies.jobRepository.listJobs().singleWhere(
    (Task job) => !jobIdsBefore.contains(job.id),
  );
}

void main() {
  testWidgets('test_task_form_screen_start_stored_task_property_new_form', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54801);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormScene scene = await openTaskFormScene(
        tester,
        random: random,
        formRoute: NewItemFormRoute(DraftKind.task),
      );
      final ExplainedRefusal refusal = randomExplainedRefusal(random);
      scene.tasks.startProblem = refusal.problem;
      await typeTaskTitle(tester, 'New $i');

      await pressFormButton(tester, startNowLabel);

      expect(find.textContaining(createdTaskNotStartedPrefix), findsOneWidget);
      expect(scene.tasks.startAttempts, <TaskId>[
        scene.tasks.createdTasks.single.id,
      ]);
    }
  });

  testWidgets('test_task_form_screen_start_stored_task_property_edit_form', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54802);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Task existing = pickOne(random, galleryTasks);
      final TaskFormScene scene = await openTaskFormScene(
        tester,
        random: random,
        formRoute: EditTaskRoute(existing.id),
      );
      final ExplainedRefusal refusal = randomExplainedRefusal(random);
      scene.tasks.startProblem = refusal.problem;

      for (int attempt = 0; attempt < 1 + random.nextInt(2); attempt += 1) {
        await pressFormButton(tester, startNowLabel);
      }

      expect(find.textContaining(createdTaskNotStartedPrefix), findsNothing);
      expect(scene.tasks.createdTasks, isEmpty);
      expect(scene.tasks.startAttempts.toSet(), <TaskId>{existing.id});
    }
  });

  testWidgets('test_task_form_screen_start_stored_task_property_opens_run', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54803);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormScene scene = await openTaskFormScene(
        tester,
        random: random,
        formRoute: NewItemFormRoute(DraftKind.task),
      );
      await typeTaskTitle(tester, 'Run $i');

      await pressFormButton(tester, startNowLabel);

      final AppRoute shown = scene.navigation.currentRoute;
      expect(shown, isA<TaskRunRoute>());
      final Run run = scene.tasks.findRun((shown as TaskRunRoute).runId);
      expect(run.taskId, scene.tasks.createdTasks.single.id);
    }
  });

  testWidgets('test_task_form_screen_store_job_property_saving_keeps_one', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54804);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormScene scene = await openTaskFormScene(
        tester,
        random: random,
        formRoute: NewItemFormRoute(DraftKind.task),
      );
      final Set<TaskId> jobIdsBefore = _listJobIds(scene);
      scene.tasks.startProblem = randomExplainedRefusal(random).problem;
      await typeTaskTitle(tester, 'Nightly $i');
      await chooseTaskRepeat(tester, pickOne(random, _repeats));
      await pressFormButton(tester, startNowLabel);

      await pressFormButton(tester, saveForLaterLabel);

      expect(_listJobIds(scene).length, jobIdsBefore.length + 1);
      expect(scene.tasks.createdTasks, isEmpty);
    }
  });

  testWidgets('test_task_form_screen_store_job_property_retry_saves_words', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54805);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormScene scene = await openTaskFormScene(
        tester,
        random: random,
        formRoute: NewItemFormRoute(DraftKind.task),
      );
      final Set<TaskId> jobIdsBefore = _listJobIds(scene);
      scene.tasks.startProblem = randomExplainedRefusal(random).problem;
      await typeTaskTitle(tester, 'First $i');
      await chooseTaskRepeat(tester, pickOne(random, _repeats));
      await pressFormButton(tester, startNowLabel);
      final String changedTitle = 'Changed $i';
      await typeTaskTitle(tester, changedTitle);

      await pressFormButton(tester, startNowLabel);

      final Task job = _findOnlyNewJob(scene, jobIdsBefore);
      expect(job.title, changedTitle);
      expect(scene.tasks.startAttempts, <TaskId>[job.id, job.id]);
    }
  });
}
