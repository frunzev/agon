import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/tasks/task_form_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/task_route_screens.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../../support/widget_harness.dart';
import '../shared/support/watch_counting_task_repository.dart';
import '../support/planned_refusal.dart';
import 'task_form_screen_inputs.dart';
import 'task_form_screen_scene.dart';

TaskFormScreen _buildScreen(
  AppDependencies dependencies, {
  required Task? existingTask,
  required TaskDoer initialDoer,
  required Key? key,
}) {
  return TaskFormScreen(
    key: key,
    existingTask: existingTask,
    initialDoer: initialDoer,
    options: buildTaskFormOptionsFor(
      dependencies: dependencies,
      chosenTarget: const AnyFreeRunner(),
    ),
    taskRepository: dependencies.taskRepository,
    jobRepository: dependencies.jobRepository,
    navigation: AppNavigation(initialRoute: const NewTaskRoute()),
  );
}

Future<void> _leaveAndReopenNewForm(
  WidgetTester tester,
  TaskFormScene scene,
) async {
  scene.navigation.closeRoute();
  await pumpFrames(tester);
  scene.navigation.openRoute(NewItemFormRoute(DraftKind.task));
  await pumpFrames(tester);
}

void main() {
  test('test_task_form_screen_property_keeps_every_field', () {
    final Random random = seededRandom(116401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final Task? existingTask = randomExistingTask(random);
      final TaskDoer doer = randomTaskDoer(random);

      final TaskFormScreen screen = _buildScreen(
        dependencies,
        existingTask: existingTask,
        initialDoer: doer,
        key: null,
      );

      expect(identical(screen.existingTask, existingTask), isTrue);
      expect(screen.initialDoer, doer);
      expect(
        identical(screen.taskRepository, dependencies.taskRepository),
        isTrue,
      );
      expect(
        identical(screen.jobRepository, dependencies.jobRepository),
        isTrue,
      );
    }
  });

  test('test_task_form_screen_property_keeps_the_given_key', () {
    final Random random = seededRandom(116402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomText(random));
      final TaskFormScreen screen = _buildScreen(
        buildGalleryDependencies(),
        existingTask: randomExistingTask(random),
        initialDoer: defaultTaskDoer,
        key: key,
      );

      expect(screen.key, key);
    }
  });

  test('test_task_form_screen_property_constructing_stores_nothing', () {
    final Random random = seededRandom(116403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WatchCountingTaskRepository untouchable =
          WatchCountingTaskRepository();
      final AppDependencies dependencies = replaceRepositories(
        buildGalleryDependencies(),
        taskRepository: untouchable,
      );

      expect(
        () => _buildScreen(
          dependencies,
          existingTask: randomExistingTask(random),
          initialDoer: defaultTaskDoer,
          key: null,
        ),
        returnsNormally,
      );
      expect(untouchable.watchCalls, 0);
    }
  });

  testWidgets(
    'test_task_form_screen_create_state_property_each_form_own_task',
    (WidgetTester tester) async {
      final Random random = seededRandom(116404);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TaskFormScene scene = await openTaskFormScene(
          tester,
          random: random,
          formRoute: NewItemFormRoute(DraftKind.task),
        );
        scene.tasks.startProblem = randomExplainedRefusal(random).problem;
        await typeTaskTitle(tester, 'First $i');
        await pressFormButton(tester, startNowLabel);

        await _leaveAndReopenNewForm(tester, scene);
        await typeTaskTitle(tester, 'Second $i');
        await pressFormButton(tester, startNowLabel);

        final List<TaskId> created = <TaskId>[
          for (final Task task in scene.tasks.createdTasks) task.id,
        ];
        expect(created, hasLength(2));
        expect(created.toSet(), hasLength(2));
        expect(scene.tasks.startAttempts, created);
      }
    },
  );

  testWidgets(
    'test_task_form_screen_create_state_property_edit_starts_as_it',
    (WidgetTester tester) async {
      final Random random = seededRandom(116405);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Task existing = pickOne(random, galleryTasks);
        final TaskFormScene scene = await openTaskFormScene(
          tester,
          random: random,
          formRoute: EditTaskRoute(existing.id),
        );
        final String changedTitle = 'Edited $i ${randomWordPhrase(random)}';
        await typeTaskTitle(tester, changedTitle);

        await pressFormButton(tester, saveForLaterLabel);

        expect(scene.tasks.createdTasks, isEmpty);
        expect(scene.tasks.findTask(existing.id).title, changedTitle.trim());
      }
    },
  );

  testWidgets(
    'test_task_form_screen_create_state_property_resize_keeps_task',
    (WidgetTester tester) async {
      final Random random = seededRandom(116406);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TaskFormScene scene = await openTaskFormScene(
          tester,
          random: random,
          formRoute: NewItemFormRoute(DraftKind.task),
        );
        scene.tasks.startProblem = randomExplainedRefusal(random).problem;
        await typeTaskTitle(tester, 'Resized $i');
        await pressFormButton(tester, startNowLabel);

        final double width = randomWidth(
          random,
          least: phoneWidth,
          most: widestWidth,
        );
        useViewSize(tester, Size(width, desktopHeight));
        await pumpFrames(tester);
        scene.tasks.startProblem = null;
        await pressFormButton(tester, startNowLabel);

        expect(scene.tasks.createdTasks, hasLength(1));
        expect(scene.tasks.startAttempts.toSet(), <TaskId>{
          scene.tasks.createdTasks.single.id,
        });
      }
    },
  );
}
