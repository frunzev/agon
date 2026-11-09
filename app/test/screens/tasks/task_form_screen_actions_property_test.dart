import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_tasks.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/screens/tasks/task_form_screen.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'task_form_screen_scene.dart';

const List<RepeatChoice> _repeats = <RepeatChoice>[
  RepeatChoice.hourly,
  RepeatChoice.daily,
  RepeatChoice.weekly,
];
const String _runningRefusal = 'the task is running; cancel its run first';

List<Task> _listIdleGalleryTasks() {
  return <Task>[
    for (final Task task in galleryTasks)
      if (task.id != GalleryTaskIds.shipRelease24) task,
  ];
}

Future<void> _pressVisibleButton(WidgetTester tester, String label) async {
  await tapVisible(tester, find.widgetWithText(AppButton, label).last);
  await pumpFrames(tester);
}

bool _isStored(TaskFormScene scene, TaskId taskId) {
  return scene.tasks.stored.listTasks().any((Task task) => task.id == taskId);
}

void main() {
  testWidgets(
    'test_task_form_screen_review_deletion_property_confirm_leaves',
    (WidgetTester tester) async {
      final Random random = seededRandom(116501);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Task task = pickOne(random, _listIdleGalleryTasks());
        final TaskFormScene scene = await openTaskFormScene(
          tester,
          random: random,
          formRoute: EditTaskRoute(task.id),
        );

        await _pressVisibleButton(tester, 'Delete');
        expect(find.text('Delete "${task.title}"?'), findsOneWidget);
        await _pressVisibleButton(tester, 'Delete task');

        expect(
          scene.navigation.currentRoute,
          const SectionRoute(AppSection.tasks),
        );
        expect(_isStored(scene, task.id), isFalse);
        expect(find.byType(TaskFormScreen), findsNothing);
      }
    },
  );

  testWidgets(
    'test_task_form_screen_review_deletion_property_keeping_changes_nothing',
    (WidgetTester tester) async {
      final Random random = seededRandom(116502);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Task task = pickOne(random, galleryTasks);
        final TaskFormScene scene = await openTaskFormScene(
          tester,
          random: random,
          formRoute: EditTaskRoute(task.id),
        );
        final List<AppRoute> routesBefore = scene.navigation.routes;

        await _pressVisibleButton(tester, 'Delete');
        await _pressVisibleButton(tester, 'Keep task');

        expect(scene.navigation.routes, routesBefore);
        expect(_isStored(scene, task.id), isTrue);
        expect(find.byType(TaskFormScreen), findsOneWidget);
      }
    },
  );

  testWidgets(
    'test_task_form_screen_review_deletion_property_refusal_keeps_task',
    (WidgetTester tester) async {
      final Random random = seededRandom(116503);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Task task = pickOne(random, _listIdleGalleryTasks());
        final TaskFormScene scene = await openTaskFormScene(
          tester,
          random: random,
          formRoute: EditTaskRoute(task.id),
        );
        await scene.tasks.stored.startTask(task.id);
        await pumpFrames(tester);
        final List<AppRoute> routesBefore = scene.navigation.routes;

        await _pressVisibleButton(tester, 'Delete');
        await _pressVisibleButton(tester, 'Delete task');

        expect(find.textContaining(_runningRefusal), findsOneWidget);
        expect(scene.navigation.routes, routesBefore);
        expect(_isStored(scene, task.id), isTrue);
        await _pressVisibleButton(tester, 'Keep task');
        expect(find.textContaining(_runningRefusal), findsNothing);
        expect(find.byType(TaskFormScreen), findsOneWidget);
      }
    },
  );

  testWidgets(
    'test_task_form_screen_save_for_later_property_new_task_lands_unstarted',
    (WidgetTester tester) async {
      final Random random = seededRandom(116504);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TaskFormScene scene = await openTaskFormScene(
          tester,
          random: random,
          formRoute: NewItemFormRoute(DraftKind.task),
        );
        final String title = 'Later $i ${randomWordPhrase(random)}';
        await typeTaskTitle(tester, title);

        await pressFormButton(tester, saveForLaterLabel);

        expect(scene.tasks.listTasks().first.title, title.trim());
        expect(scene.tasks.startAttempts, isEmpty);
        expect(scene.navigation.routes, const <AppRoute>[
          SectionRoute(AppSection.tasks),
        ]);
      }
    },
  );

  testWidgets(
    'test_task_form_screen_save_for_later_property_repeat_saves_job',
    (WidgetTester tester) async {
      final Random random = seededRandom(116505);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TaskFormScene scene = await openTaskFormScene(
          tester,
          random: random,
          formRoute: NewItemFormRoute(DraftKind.task),
        );
        final int tasksBefore = scene.tasks.listTasks().length;
        final int jobsBefore = scene.dependencies.jobRepository
            .listJobs()
            .length;
        final String title = 'Nightly later $i';
        await typeTaskTitle(tester, title);
        await chooseTaskRepeat(tester, pickOne(random, _repeats));

        await pressFormButton(tester, saveForLaterLabel);

        final List<Task> jobs = scene.dependencies.jobRepository.listJobs();
        expect(jobs, hasLength(jobsBefore + 1));
        expect(jobs.any((Task job) => job.title == title), isTrue);
        expect(scene.tasks.listTasks(), hasLength(tasksBefore));
        expect(scene.tasks.startAttempts, isEmpty);
        expect(
          scene.navigation.currentRoute,
          const SectionRoute(AppSection.jobs),
        );
      }
    },
  );

  testWidgets(
    'test_task_form_screen_save_for_later_property_vanished_task_closes_'
    'the_form_unsaved',
    (WidgetTester tester) async {
      final Random random = seededRandom(116506);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Task task = pickOne(random, _listIdleGalleryTasks());
        final TaskFormScene scene = await openTaskFormScene(
          tester,
          random: random,
          formRoute: EditTaskRoute(task.id),
        );

        await scene.tasks.stored.deleteTask(task.id);
        await pumpFrames(tester);

        expect(tester.takeException(), isNull);
        expect(find.widgetWithText(AppButton, saveForLaterLabel), findsNothing);
        expect(
          scene.navigation.routes,
          const <AppRoute>[SectionRoute(AppSection.tasks)],
        );
        expect(_isStored(scene, task.id), isFalse);
      }
    },
  );

  testWidgets('test_task_form_screen_store_task_property_keeps_form_values', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(116507);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormScene scene = await openTaskFormScene(
        tester,
        random: random,
        formRoute: NewItemFormRoute(DraftKind.task),
      );
      final String title = '  Values $i ${randomWordPhrase(random)}  ';
      await typeTaskTitle(tester, title);

      await pressFormButton(tester, saveForLaterLabel);

      final Task created = scene.tasks.createdTasks.single;
      expect(created.title, title.trim());
      expect(created.doer, defaultTaskDoer);
      expect(created.status, TaskStatus.toDo);
      expect(created.schedule, isNull);
      expect(_isStored(scene, created.id), isTrue);
    }
  });

  testWidgets(
    'test_task_form_screen_store_task_property_edit_keeps_identity',
    (WidgetTester tester) async {
      final Random random = seededRandom(116508);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final Task task = pickOne(random, _listIdleGalleryTasks());
        final TaskFormScene scene = await openTaskFormScene(
          tester,
          random: random,
          formRoute: EditTaskRoute(task.id),
        );
        final int countBefore = scene.tasks.stored.listTasks().length;
        await typeTaskTitle(tester, 'Renamed $i');

        await pressFormButton(
          tester,
          pickOne(random, <String>[saveForLaterLabel, startNowLabel]),
        );

        final Task stored = scene.tasks.stored.findTask(task.id);
        expect(scene.tasks.createdTasks, isEmpty);
        expect(stored.title, 'Renamed $i');
        expect(stored.createdAt, task.createdAt);
        expect(scene.tasks.stored.listTasks(), hasLength(countBefore));
      }
    },
  );
}
