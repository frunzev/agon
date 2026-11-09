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

void main() {
  testWidgets('test_task_form_screen_start_now_property_says_created', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53801);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormScene scene = await openTaskFormScene(
        tester,
        random: random,
        formRoute: NewItemFormRoute(DraftKind.task),
      );
      final ExplainedRefusal refusal = randomExplainedRefusal(random);
      scene.tasks.startProblem = refusal.problem;
      final List<AppRoute> routesBefore = scene.navigation.routes;
      await typeTaskTitle(tester, 'Ship $i');

      await pressFormButton(tester, startNowLabel);

      expect(
        find.text('$createdTaskNotStartedPrefix${refusal.explanation}'),
        findsOneWidget,
      );
      expect(scene.tasks.createdTasks, hasLength(1));
      expect(scene.navigation.routes, routesBefore);
    }
  });

  testWidgets('test_task_form_screen_start_now_property_retry_same_task', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53802);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormScene scene = await openTaskFormScene(
        tester,
        random: random,
        formRoute: NewItemFormRoute(DraftKind.task),
      );
      scene.tasks.startProblem = randomExplainedRefusal(random).problem;
      await typeTaskTitle(tester, 'Ship $i');
      final int refusedCount = 1 + random.nextInt(3);
      for (int refused = 0; refused < refusedCount; refused += 1) {
        await pressFormButton(tester, startNowLabel);
      }
      scene.tasks.startProblem = null;

      await pressFormButton(tester, startNowLabel);

      final TaskId createdId = scene.tasks.createdTasks.single.id;
      expect(scene.tasks.startAttempts, <TaskId>[
        for (int attempt = 0; attempt <= refusedCount; attempt += 1) createdId,
      ]);
      final AppRoute shown = scene.navigation.currentRoute;
      expect(shown, isA<TaskRunRoute>());
      final Run run = scene.tasks.findRun((shown as TaskRunRoute).runId);
      expect(run.taskId, createdId);
    }
  });

  testWidgets('test_task_form_screen_store_task_property_retry_saves_words', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53803);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormScene scene = await openTaskFormScene(
        tester,
        random: random,
        formRoute: NewItemFormRoute(DraftKind.task),
      );
      scene.tasks.startProblem = randomExplainedRefusal(random).problem;
      await typeTaskTitle(tester, 'First $i');
      await pressFormButton(tester, startNowLabel);
      final String changedTitle = 'Changed $i ${randomWordPhrase(random)}';
      await typeTaskTitle(tester, changedTitle);

      await pressFormButton(
        tester,
        pickOne(random, <String>[startNowLabel, saveForLaterLabel]),
      );

      final TaskId createdId = scene.tasks.createdTasks.single.id;
      expect(scene.tasks.findTask(createdId).title, changedTitle.trim());
    }
  });

  testWidgets('test_task_form_screen_store_job_property_retry_one_job', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53804);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormScene scene = await openTaskFormScene(
        tester,
        random: random,
        formRoute: NewItemFormRoute(DraftKind.task),
      );
      final int jobCountBefore = scene.dependencies.jobRepository
          .listJobs()
          .length;
      scene.tasks.startProblem = randomExplainedRefusal(random).problem;
      await typeTaskTitle(tester, 'Nightly $i');
      await chooseTaskRepeat(
        tester,
        pickOne(random, <RepeatChoice>[
          RepeatChoice.daily,
          RepeatChoice.weekly,
          RepeatChoice.hourly,
        ]),
      );

      for (int attempt = 0; attempt < 2 + random.nextInt(2); attempt += 1) {
        await pressFormButton(tester, startNowLabel);
      }

      final List<Task> jobs = scene.dependencies.jobRepository.listJobs();
      expect(jobs.length, jobCountBefore + 1);
      expect(scene.tasks.startAttempts.toSet(), hasLength(1));
      expect(scene.tasks.createdTasks, isEmpty);
    }
  });

  testWidgets('test_task_form_screen_start_now_property_edit_reads_plain', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53805);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Task existing = pickOne(random, galleryTasks);
      final TaskFormScene scene = await openTaskFormScene(
        tester,
        random: random,
        formRoute: EditTaskRoute(existing.id),
      );
      final ExplainedRefusal refusal = randomExplainedRefusal(random);
      scene.tasks.startProblem = refusal.problem;

      await pressFormButton(tester, startNowLabel);

      expect(find.text(refusal.explanation), findsOneWidget);
      expect(find.textContaining(createdTaskNotStartedPrefix), findsNothing);
      expect(scene.tasks.createdTasks, isEmpty);
      expect(scene.tasks.startAttempts, <TaskId>[existing.id]);
    }
  });
}
