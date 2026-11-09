import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/random_inputs.dart';
import '../support/gone_projects_scene.dart';

Future<AppDependencies> _pumpJobs(WidgetTester tester, Random random) async {
  final AppDependencies dependencies = buildWithSomeProjectsGone(random);
  await pumpSectionAtRandomSize(
    tester,
    random: random,
    dependencies: dependencies,
    section: AppSection.jobs,
  );
  return dependencies;
}

void main() {
  testWidgets('test_jobs_screen_build_row_property_jobs_of_unknown_'
      'projects_never_crash', (WidgetTester tester) async {
    final Random random = seededRandom(5312501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpJobs(tester, random);

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_jobs_screen_build_row_property_an_unknown_project_reads_'
      'as_its_short_identifier', (WidgetTester tester) async {
    final Random random = seededRandom(5312502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await _pumpJobs(tester, random);

      for (final Task task in dependencies.jobRepository.listJobs()) {
        final String? shortName = findGoneProjectShortName(dependencies, task);
        if (shortName != null) {
          expect(find.textContaining('$shortName · '), findsWidgets);
        }
      }
    }
  });

  testWidgets('test_jobs_screen_build_row_property_kept_projects_keep_their_'
      'names', (WidgetTester tester) async {
    final Random random = seededRandom(5312503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await _pumpJobs(tester, random);

      for (final Task task in dependencies.jobRepository.listJobs()) {
        final String? projectName = findKeptProjectName(dependencies, task);
        if (projectName != null) {
          expect(find.textContaining('$projectName · '), findsWidgets);
        }
      }
    }
  });
}
