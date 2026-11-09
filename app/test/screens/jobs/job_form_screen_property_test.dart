import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/jobs/job_form_screen.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/task_route_screens.dart';

import '../../support/list_harness.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'jobs_scene.dart';

const String _deleteLabel = 'Delete';

AppNavigation _navigationOnForm(Task? job) {
  final AppNavigation navigation = AppNavigation(initialRoute: jobsRoute);
  if (job == null) {
    navigation.openRoute(const NewJobRoute());
  } else {
    navigation.openRoute(EditJobRoute(job.id));
  }
  return navigation;
}

String _readFieldText(WidgetTester tester, int index) {
  final TextField field = tester.widget(find.byType(TextField).at(index));
  return field.controller!.text;
}

void main() {
  test('test_job_form_screen_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(1021701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final Task? job = random.nextBool() ? randomJob(random, i) : null;
      final AppNavigation navigation = _navigationOnForm(job);
      final TaskFormOptions options = buildTaskFormOptionsFor(
        dependencies: dependencies,
        chosenTarget: const AnyFreeRunner(),
      );

      final JobFormScreen screen = JobFormScreen(
        existingJob: job,
        options: options,
        jobRepository: dependencies.jobRepository,
        navigation: navigation,
      );

      expect(screen.existingJob, same(job));
      expect(screen.options, same(options));
      expect(screen.jobRepository, same(dependencies.jobRepository));
      expect(screen.navigation, same(navigation));
    }
  });

  test('test_job_form_screen_constructor_property_no_key_unless_given', () {
    final Random random = seededRandom(1021702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final Task? job = random.nextBool() ? randomJob(random, i) : null;

      final JobFormScreen screen = buildJobForm(
        dependencies: dependencies,
        existingJob: job,
        navigation: _navigationOnForm(job),
      );

      expect(screen.key, isNull);
    }
  });

  test('test_job_form_screen_constructor_property_offers_only_repeats', () {
    expect(jobRepeatChoices, isNot(contains(RepeatChoice.none)));
    expect(jobRepeatChoices.toSet(), hasLength(jobRepeatChoices.length));
    for (final RepeatChoice choice in jobRepeatChoices) {
      expect(choice.label, startsWith('Every '));
    }
  });

  testWidgets('test_job_form_screen_build_property_new_and_edit_wording', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1021703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Task? job = random.nextBool()
          ? randomOneAgentJob(random, i)
          : null;
      final AppDependencies dependencies = buildDependenciesWithJobs(<Task>[
        ?job,
      ]);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildJobForm(
          dependencies: dependencies,
          existingJob: job,
          navigation: _navigationOnForm(job),
        ),
      );

      final bool isNew = job == null;
      expect(tester.takeException(), isNull);
      expect(find.text(isNew ? 'New job' : 'Edit job'), findsOneWidget);
      expect(find.text(isNew ? 'Create job' : 'Save job'), findsOneWidget);
      expect(find.text(_deleteLabel), isNew ? findsNothing : findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text(RepeatChoice.none.label), findsNothing);
    }
  });

  testWidgets('test_job_form_screen_build_property_fields_start_from_the_'
      'job', (WidgetTester tester) async {
    final Random random = seededRandom(1021704);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Task job = randomOneAgentJob(random, i);
      final AppDependencies dependencies = buildDependenciesWithJobs(<Task>[
        job,
      ]);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildJobForm(
          dependencies: dependencies,
          existingJob: job,
          navigation: _navigationOnForm(job),
        ),
      );

      expect(_readFieldText(tester, 0), job.title);
      expect(_readFieldText(tester, 1), job.details);
      final TaskFormValues values = TaskFormValues.fromTask(job);
      expect(find.text(values.repeat.label), findsOneWidget);
    }
  });

  testWidgets('test_job_form_screen_build_property_new_job_starts_weekly_'
      'and_blank', (WidgetTester tester) async {
    final Random random = seededRandom(1021705);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildJobForm(
          dependencies: dependencies,
          existingJob: null,
          navigation: _navigationOnForm(null),
        ),
      );

      expect(_readFieldText(tester, 0), isEmpty);
      expect(find.text(RepeatChoice.weekly.label), findsOneWidget);
      expect(find.text(defaultScheduleTimeText), findsOneWidget);
    }
  });

  testWidgets('test_job_form_screen_review_deletion_property_confirmed_'
      'delete_removes_only_that_job', (WidgetTester tester) async {
    final Random random = seededRandom(1021706);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Task> jobs = <Task>[
        randomOneAgentJob(random, 0),
        randomOneAgentJob(random, 1),
      ];
      final AppDependencies dependencies = buildDependenciesWithJobs(jobs);
      final Task job = pickOne(random, jobs);
      final AppNavigation navigation = _navigationOnForm(job);
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildJobForm(
          dependencies: dependencies,
          existingJob: job,
          navigation: navigation,
        ),
      );

      await tapShownText(tester, _deleteLabel);
      await tester.pump(const Duration(milliseconds: 300));
      await tapShownText(tester, 'Delete job');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      final List<Task> left = dependencies.jobRepository.listJobs();
      expect(left.map((Task listed) => listed.id), isNot(contains(job.id)));
      expect(left, hasLength(jobs.length - 1));
      expect(navigation.routes, const <AppRoute>[jobsRoute]);
    }
  });
}
