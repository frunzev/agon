import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/tasks/tasks_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'random_listed_tasks.dart';
import 'tasks_screen_scene.dart';

const String _newTaskLabel = 'New task';

Finder _findNewTaskButton() {
  return find.descendant(
    of: find.byType(TasksScreen),
    matching: find.widgetWithText(AppButton, _newTaskLabel),
  );
}

void main() {
  testWidgets(
    'test_tasks_screen_build_new_task_button_property_always_one_primary',
    (WidgetTester tester) async {
      final Random random = seededRandom(116208);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 0);
        await openTasksPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
        );

        expect(_findNewTaskButton(), findsOneWidget);
        final AppButton button = tester.widget<AppButton>(
          _findNewTaskButton(),
        );
        expect(button.tone, ButtonTone.primary);
        expect(button.icon, AppIconKind.plus);
        expect(button.onPressed, isNotNull);
      }
    },
  );

  testWidgets(
    'test_tasks_screen_build_new_task_button_property_opens_the_new_task_form',
    (WidgetTester tester) async {
      final Random random = seededRandom(116209);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 0);
        final AppNavigation navigation = await openTasksPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
        );

        await tester.ensureVisible(_findNewTaskButton());
        await tester.tap(_findNewTaskButton());
        await pumpFrames(tester);

        expect(navigation.currentRoute, const NewTaskRoute());
        expect(find.text(_newTaskLabel), findsWidgets);
      }
    },
  );

  testWidgets(
    'test_tasks_screen_build_new_task_button_property_creates_nothing_itself',
    (WidgetTester tester) async {
      final Random random = seededRandom(116210);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final TasksScene scene = buildTasksScene(random, leastTaskCount: 0);
        await openTasksPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
        );
        final int before = scene.tasks.listTasksAndJobs().length;

        tester.widget<AppButton>(_findNewTaskButton()).onPressed!();
        await pumpFrames(tester);

        expect(scene.tasks.listTasksAndJobs(), hasLength(before));
      }
    },
  );
}
