import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/list_harness.dart';
import '../../support/random_inputs.dart';
import '../new_items/change_request_composer_steps.dart';
import '../new_items/draft_record_fields.dart';
import '../support/random_page_windows.dart';
import 'jobs_scene.dart';

const String _blankTitleProblem = 'Write what should be done.';
const List<String> _lookAlikeCharacters = <String>[
  '\u200B',
  '\uFEFF',
  '\u180E',
  '\u2060',
];

Future<AppNavigation> _pumpNewJobForm(
  WidgetTester tester,
  Random random,
  AppDependencies dependencies,
) async {
  final AppNavigation navigation = AppNavigation(initialRoute: jobsRoute);
  navigation.openRoute(const NewJobRoute());
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: buildJobForm(
      dependencies: dependencies,
      existingJob: null,
      navigation: navigation,
    ),
  );
  return navigation;
}

Future<void> _createWithTitle(WidgetTester tester, String title) async {
  await tester.enterText(find.byType(TextField).first, title);
  await tester.pump();
  await tapShownText(tester, 'Create job');
  await tester.pump();
}

String _randomLookAlikeTitle(Random random) {
  final StringBuffer title = StringBuffer();
  for (int index = 0; index <= random.nextInt(3); index += 1) {
    title.write(pickOne(random, _lookAlikeCharacters));
  }
  return title.toString();
}

void main() {
  testWidgets('test_job_form_screen_save_job_property_unchanged_edit_keeps_'
      'every_field', (WidgetTester tester) async {
    final Random random = seededRandom(1021801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Task job = randomOneAgentJob(random, i);
      final AppDependencies dependencies = buildDependenciesWithJobs(<Task>[
        job,
      ]);
      final AppNavigation navigation = AppNavigation(initialRoute: jobsRoute);
      navigation.openRoute(EditJobRoute(job.id));
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildJobForm(
          dependencies: dependencies,
          existingJob: job,
          navigation: navigation,
        ),
      );

      await tapShownText(tester, 'Save job');
      await tester.pump();

      final Task saved = dependencies.jobRepository.findJob(job.id);
      expect(tester.takeException(), isNull);
      expect(describeSavedWorkFields(saved), describeSavedWorkFields(job));
      expect(dependencies.jobRepository.listJobs(), hasLength(1));
      expect(navigation.routes, const <AppRoute>[jobsRoute]);
    }
  });

  testWidgets('test_job_form_screen_save_job_property_new_job_repeats_'
      'weekly', (WidgetTester tester) async {
    final Random random = seededRandom(1021802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildDependenciesWithJobs(
        const <Task>[],
      );
      final String title = 'Rotate ${randomWordPhrase(random)} $i';
      final AppNavigation navigation = await _pumpNewJobForm(
        tester,
        random,
        dependencies,
      );

      await _createWithTitle(tester, title);

      final Task created = dependencies.jobRepository.listJobs().single;
      final Schedule schedule = created.schedule!;
      expect(created.title, title);
      expect(schedule, isA<WeeklySchedule>());
      expect(describeScheduleFields(schedule), <Object?>[
        'weekly',
        Weekday.monday,
        9,
        0,
      ]);
      expect(navigation.routes, const <AppRoute>[jobsRoute]);
    }
  });

  testWidgets('test_job_form_screen_save_job_property_white_space_titles_'
      'never_reach_the_repository', (WidgetTester tester) async {
    final Random random = seededRandom(1021803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildDependenciesWithJobs(
        const <Task>[],
      );
      final AppNavigation navigation = await _pumpNewJobForm(
        tester,
        random,
        dependencies,
      );

      await _createWithTitle(tester, randomBlankNote(random));

      expect(dependencies.jobRepository.listJobs(), isEmpty);
      expect(find.text(_blankTitleProblem), findsOneWidget);
      expect(navigation.currentRoute, const NewJobRoute());
    }
  });

  testWidgets('test_job_form_screen_save_job_property_look_alike_titles_'
      'are_saved_like_the_server_does', (WidgetTester tester) async {
    final Random random = seededRandom(1021804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildDependenciesWithJobs(
        const <Task>[],
      );
      final String title = _randomLookAlikeTitle(random);
      await _pumpNewJobForm(tester, random, dependencies);

      await _createWithTitle(tester, title);

      expect(find.text(_blankTitleProblem), findsNothing, reason: title);
      expect(dependencies.jobRepository.listJobs(), hasLength(1));
      expect(dependencies.jobRepository.listJobs().single.title, title);
    }
  });
}
