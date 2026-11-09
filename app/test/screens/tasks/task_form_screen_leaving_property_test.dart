import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/screens/tasks/tasks_screen.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/form_leaving_scene.dart';
import 'task_form_screen_scene.dart';

const SectionRoute _tasksRoute = SectionRoute(AppSection.tasks);
const List<RepeatChoice> _repeats = <RepeatChoice>[
  RepeatChoice.hourly,
  RepeatChoice.daily,
  RepeatChoice.weekly,
];

List<AppRoute> _randomNewTaskRoutes(Random random) {
  final AppRoute form = NewItemFormRoute(DraftKind.task);
  if (random.nextBool()) {
    return <AppRoute>[_tasksRoute, form];
  }
  return <AppRoute>[_tasksRoute, const NewTaskRoute(), form];
}

void main() {
  testWidgets('test_task_form_screen_build_property_a_new_task_form_leaves_'
      'to_the_tasks_list_its_back_link_names', (WidgetTester tester) async {
    final Random random = seededRandom(5310801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewTaskRoutes(random),
      );
      final String backLabel = readBackLinkLabel(tester);
      await typeTaskTitle(tester, 'Typed ${randomText(random)}');

      await pressBackLink(tester);

      expect(tester.takeException(), isNull);
      expect(backLabel, AppSection.tasks.label);
      expect(scene.navigation.routes, const <AppRoute>[_tasksRoute]);
      expect(find.byType(TasksScreen), findsOneWidget);
      expect(scene.saveHold.saveCount, 0);
    }
  });

  testWidgets('test_task_form_screen_build_property_an_edit_leaves_to_the_'
      'tasks_list', (WidgetTester tester) async {
    final Random random = seededRandom(5310802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Task> tasks = buildGalleryDependencies().taskRepository
          .listTasks();
      final Task task = pickOne(random, tasks);
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: <AppRoute>[_tasksRoute, EditTaskRoute(task.id)],
      );
      final String backLabel = readBackLinkLabel(tester);

      await pressBackLink(tester);

      expect(backLabel, AppSection.tasks.label);
      expect(scene.navigation.routes, const <AppRoute>[_tasksRoute]);
      expect(scene.saveHold.saveCount, 0);
    }
  });

  testWidgets('test_save_for_later_property_a_person_who_moved_on_stays_'
      'where_they_went', (WidgetTester tester) async {
    final Random random = seededRandom(5310803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewTaskRoutes(random),
      );
      await typeTaskTitle(tester, 'Held task $i');
      if (random.nextBool()) {
        await chooseTaskRepeat(tester, pickOne(random, _repeats));
      }

      final List<AppRoute> wentTo = await saveWhileMovingOn(
        tester,
        random: random,
        scene: scene,
        saveLabel: saveForLaterLabel,
      );

      expect(tester.takeException(), isNull);
      expect(scene.navigation.routes, wentTo);
      expect(scene.saveHold.saveCount, 1);
    }
  });

  testWidgets('test_save_for_later_property_a_shown_form_closes_to_tasks_or_'
      'jobs', (WidgetTester tester) async {
    final Random random = seededRandom(5310804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewTaskRoutes(random),
      );
      await typeTaskTitle(tester, 'Shown task $i');
      final bool repeats = random.nextBool();
      if (repeats) {
        await chooseTaskRepeat(tester, pickOne(random, _repeats));
      }

      await pressShownButton(tester, saveForLaterLabel);
      await pumpFrames(tester);

      final SectionRoute expected = repeats
          ? const SectionRoute(AppSection.jobs)
          : _tasksRoute;
      expect(tester.takeException(), isNull);
      expect(scene.navigation.routes, <AppRoute>[expected]);
    }
  });

  testWidgets('test_start_now_property_a_person_who_moved_on_stays_where_'
      'they_went', (WidgetTester tester) async {
    final Random random = seededRandom(5310805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewTaskRoutes(random),
      );
      await typeTaskTitle(tester, 'Started task $i');

      final List<AppRoute> wentTo = await saveWhileMovingOn(
        tester,
        random: random,
        scene: scene,
        saveLabel: startNowLabel,
      );

      expect(tester.takeException(), isNull);
      expect(scene.navigation.routes, wentTo);
      expect(scene.saveHold.saveCount, 1);
    }
  });

  testWidgets('test_start_now_property_a_shown_form_opens_the_run_above_'
      'the_tasks_list', (WidgetTester tester) async {
    final Random random = seededRandom(5310806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewTaskRoutes(random),
      );
      await typeTaskTitle(tester, 'Run task $i');

      await pressShownButton(tester, startNowLabel);
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(scene.navigation.routes, hasLength(2));
      expect(scene.navigation.routes.first, _tasksRoute);
      expect(scene.navigation.currentRoute, isA<TaskRunRoute>());
    }
  });
}
