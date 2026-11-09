import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';

import '../../support/random_inputs.dart';
import 'random_listed_tasks.dart';
import 'tasks_screen_scene.dart';

void main() {
  testWidgets(
    'test_tasks_screen_open_task_property_tasks_without_runs_open_the_form',
    (WidgetTester tester) async {
      final Random random = seededRandom(116307);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 1);
        final AppNavigation navigation = await openTasksPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
        );
        final List<Task> listed = scene.tasks.listTasks();
        if (listed.isEmpty) {
          continue;
        }
        final Task task = pickOne(random, listed);

        await tapTaskTitle(tester, task.title);

        final Run? latest = findLatestRun(scene, task);
        if (latest == null) {
          expect(navigation.currentRoute, EditTaskRoute(task.id));
        }
      }
    },
  );

  testWidgets(
    'test_tasks_screen_open_task_property_started_tasks_open_the_latest_run',
    (WidgetTester tester) async {
      final Random random = seededRandom(116308);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 1);
        final AppNavigation navigation = await openTasksPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
        );
        final List<ListRowData> rows = readTaskRows(tester);
        final List<Task> listed = scene.tasks.listTasks();

        for (int index = 0; index < rows.length; index += 1) {
          final Task task = listed[index];
          final Run? latest = findLatestRun(scene, task);
          final List<AppRoute> before = navigation.routes;
          rows[index].onTap!();
          final AppRoute expected =
              latest == null || task.status == TaskStatus.toDo
              ? EditTaskRoute(task.id)
              : TaskRunRoute(latest.id);
          expect(navigation.currentRoute, expected);
          navigation.returnTo(before.last);
        }
      }
    },
  );

  testWidgets(
    'test_tasks_screen_open_task_property_to_do_tasks_open_the_form',
    (WidgetTester tester) async {
      final Random random = seededRandom(116309);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 1);
        final AppNavigation navigation = await openTasksPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
        );
        final List<Task> toDo = <Task>[
          for (final Task task in scene.tasks.listTasks())
            if (task.status == TaskStatus.toDo) task,
        ];
        if (toDo.isEmpty) {
          continue;
        }
        final Task task = pickOne(random, toDo);

        await tapTaskTitle(tester, task.title);

        expect(navigation.currentRoute, EditTaskRoute(task.id));
        expect(find.text('Edit task'), findsOneWidget);
      }
    },
  );
}
