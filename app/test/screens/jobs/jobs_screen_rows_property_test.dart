import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/list_harness.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'jobs_scene.dart';

const String _newJobLabel = 'New job';

Future<List<String>> _readNextRunsAt(
  WidgetTester tester, {
  required Random random,
  required AppDependencies dependencies,
  required Clock clock,
}) async {
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: buildJobsScreen(
      dependencies: dependencies,
      clock: clock,
      navigation: AppNavigation(initialRoute: jobsRoute),
    ),
  );
  return <String>[
    for (final Task job in dependencies.jobRepository.listJobs())
      ...readJobRowTexts(job),
  ];
}

void main() {
  testWidgets('test_jobs_screen_build_row_property_tap_edits_that_job', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1021601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildDependenciesWithJobs(<Task>[
        randomJob(random, 0),
        ...randomJobs(random).skip(1),
      ]);
      final AppNavigation navigation = AppNavigation(initialRoute: jobsRoute);
      final Task job = pickOne(random, dependencies.jobRepository.listJobs());
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildJobsScreen(
          dependencies: dependencies,
          clock: dependencies.clock,
          navigation: navigation,
        ),
      );

      await tapShownText(tester, job.title);

      expect(navigation.routes, <AppRoute>[jobsRoute, EditJobRoute(job.id)]);
    }
  });

  testWidgets('test_jobs_screen_build_row_property_same_moment_same_next_'
      'run_in_utc_or_local', (WidgetTester tester) async {
    final Random random = seededRandom(1021602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildDependenciesWithJobs(
        randomJobs(random),
      );
      final DateTime moment = randomMomentNearDaylightChange(random);
      final int windowSeed = random.nextInt(1 << 30);

      final List<String> localTexts = await _readNextRunsAt(
        tester,
        random: seededRandom(windowSeed),
        dependencies: dependencies,
        clock: FixedClock(moment.toLocal()),
      );
      final List<String> utcTexts = await _readNextRunsAt(
        tester,
        random: seededRandom(windowSeed),
        dependencies: dependencies,
        clock: FixedClock(moment.toUtc()),
      );

      expect(utcTexts, localTexts, reason: '$moment');
    }
  });

  testWidgets('test_jobs_screen_build_row_property_next_run_is_the_first_'
      'local_slot', (WidgetTester tester) async {
    final Random random = seededRandom(1021603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildDependenciesWithJobs(
        randomJobs(random),
      );
      final DateTime now = randomMomentNearDaylightChange(random);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildJobsScreen(
          dependencies: dependencies,
          clock: FixedClock(now),
          navigation: AppNavigation(initialRoute: jobsRoute),
        ),
      );

      for (final Task job in dependencies.jobRepository.listJobs()) {
        final Schedule schedule = job.schedule!;
        final DateTime shownRun = findNextRunAfter(schedule, now);
        final DateTime? modelRun = findModelNextRun(schedule, now);
        final List<String> rowTexts = readJobRowTexts(job);
        expect(rowTexts, contains(describeUpcomingTime(shownRun, now)));
        expect(shownRun.isAfter(now), isTrue, reason: '$now');
        if (schedule is HourlySchedule) {
          expect(shownRun.minute, schedule.minute);
          expect(shownRun.difference(now).inMinutes, lessThan(61));
        } else if (modelRun != null && shownRun.hour == modelRun.hour) {
          expect(shownRun, modelRun, reason: '$now');
        }
      }
    }
  });

  testWidgets('test_jobs_screen_build_new_job_button_property_one_primary_'
      'button', (WidgetTester tester) async {
    final Random random = seededRandom(1021604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildDependenciesWithJobs(
        randomJobs(random),
      );
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildJobsScreen(
          dependencies: dependencies,
          clock: dependencies.clock,
          navigation: AppNavigation(initialRoute: jobsRoute),
        ),
      );

      final AppButton button = tester.widget(
        find.widgetWithText(AppButton, _newJobLabel),
      );
      expect(button.tone, ButtonTone.primary);
      expect(button.onPressed, isNotNull);
    }
  });

  testWidgets('test_jobs_screen_build_new_job_button_property_never_edits_'
      'a_job', (WidgetTester tester) async {
    final Random random = seededRandom(1021605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildDependenciesWithJobs(
        randomJobs(random),
      );
      final int jobCount = dependencies.jobRepository.listJobs().length;
      final AppNavigation navigation = AppNavigation(initialRoute: jobsRoute);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildJobsScreen(
          dependencies: dependencies,
          clock: dependencies.clock,
          navigation: navigation,
        ),
      );

      await tapShownText(tester, _newJobLabel);

      expect(navigation.currentRoute, isNot(isA<EditJobRoute>()));
      expect(dependencies.jobRepository.listJobs(), hasLength(jobCount));
    }
  });
}
