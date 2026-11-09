import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/random_inputs.dart';
import '../support/gone_projects_scene.dart';

Future<AppDependencies> _pumpTasks(WidgetTester tester, Random random) async {
  final AppDependencies dependencies = buildWithSomeProjectsGone(random);
  await pumpSectionAtRandomSize(
    tester,
    random: random,
    dependencies: dependencies,
    section: AppSection.tasks,
  );
  return dependencies;
}

void main() {
  testWidgets('test_tasks_screen_build_row_property_tasks_of_unknown_'
      'projects_never_crash', (WidgetTester tester) async {
    final Random random = seededRandom(5312401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpTasks(tester, random);

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_tasks_screen_build_row_property_an_unknown_project_reads_'
      'as_its_short_identifier', (WidgetTester tester) async {
    final Random random = seededRandom(5312402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await _pumpTasks(tester, random);

      for (final Task task in dependencies.taskRepository.listTasks()) {
        final String? shortName = findGoneProjectShortName(dependencies, task);
        if (shortName != null) {
          expect(find.textContaining('$shortName · '), findsWidgets);
        }
      }
    }
  });

  testWidgets('test_tasks_screen_build_row_property_kept_projects_keep_their_'
      'names', (WidgetTester tester) async {
    final Random random = seededRandom(5312403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await _pumpTasks(tester, random);

      for (final Task task in dependencies.taskRepository.listTasks()) {
        final String? projectName = findKeptProjectName(dependencies, task);
        if (projectName != null) {
          expect(find.textContaining('$projectName · '), findsWidgets);
        }
      }
    }
  });
}
