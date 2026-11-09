import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'start_refusing_task_repository.dart';

const String startNowLabel = 'Start now';
const String saveForLaterLabel = 'Save for later';
const String _titleLabel = 'What should be done?';

typedef TaskFormScene = ({
  StartRefusingTaskRepository tasks,
  AppDependencies dependencies,
  AppNavigation navigation,
});

Future<TaskFormScene> openTaskFormScene(
  WidgetTester tester, {
  required Random random,
  required AppRoute formRoute,
}) async {
  final StartRefusingTaskRepository tasks = StartRefusingTaskRepository(
    buildGalleryDependencies().taskRepository,
  );
  final AppDependencies dependencies = replaceRepositories(
    buildGalleryDependencies(),
    taskRepository: tasks,
  );
  final AppNavigation navigation = await pumpApp(
    tester,
    size: pickOne(random, <Size>[phoneSize, desktopSize]),
    route: const SectionRoute(AppSection.tasks),
    dependencies: dependencies,
  );
  navigation.openRoute(formRoute);
  await pumpFrames(tester);
  return (tasks: tasks, dependencies: dependencies, navigation: navigation);
}

Future<void> typeTaskTitle(WidgetTester tester, String title) async {
  await tester.enterText(findFieldInput(_titleLabel), title);
  await tester.pump();
}

Future<void> pressFormButton(WidgetTester tester, String label) async {
  final AppButton button = tester.widget(
    find.widgetWithText(AppButton, label),
  );
  button.onPressed!();
  await pumpFrames(tester);
}

Future<void> chooseTaskRepeat(WidgetTester tester, RepeatChoice repeat) async {
  final SelectField<RepeatChoice> field = tester.widget(
    find.byType(SelectField<RepeatChoice>),
  );
  field.onChanged(repeat);
  await tester.pump();
}
