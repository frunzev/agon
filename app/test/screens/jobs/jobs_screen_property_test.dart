import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/screens/jobs/jobs_screen.dart';
import 'package:agent_orchestration/data/rules/schedule_rules.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/theme/layout_size.dart';

import '../../support/list_harness.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'jobs_scene.dart';

const String _emptyTitle = 'No jobs yet';
const String _summary = 'Tasks that repeat on a schedule.';
const String _newJobLabel = 'New job';
const List<String> _columnLabels = <String>['Repeats', 'Next run', 'Last run'];

String _describeProjectAndDoer(AppDependencies dependencies, Task job) {
  final String project = dependencies.projectRepository
      .findProject(job.projectId)
      .name;
  final String doer = describeDoer(
    job.doer,
    dependencies.workflowRepository.listWorkflows(),
  );
  return '$project · $doer';
}

void main() {
  test('test_jobs_screen_constructor_property_keeps_every_field', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = AppNavigation(initialRoute: jobsRoute);

    final JobsScreen screen = buildJobsScreen(
      dependencies: dependencies,
      clock: dependencies.clock,
      navigation: navigation,
    );

    expect(screen.jobRepository, same(dependencies.jobRepository));
    expect(screen.workflowRepository, same(dependencies.workflowRepository));
    expect(screen.projectRepository, same(dependencies.projectRepository));
    expect(screen.clock, same(dependencies.clock));
    expect(screen.navigation, same(navigation));
  });

  test('test_jobs_screen_constructor_property_keeps_its_own_clock', () {
    final Random random = seededRandom(1021501);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final Clock clock = FixedClock(randomLocalMoment(random));

      final JobsScreen screen = buildJobsScreen(
        dependencies: dependencies,
        clock: clock,
        navigation: AppNavigation(initialRoute: jobsRoute),
      );

      expect(screen.clock, same(clock));
      expect(screen.key, isNull);
    }
  });

  test('test_jobs_screen_constructor_property_wording_matches_design', () {
    expect(_emptyTitle, 'No jobs yet');
    expect(_summary, endsWith('.'));
    expect(_newJobLabel, isNot(_emptyTitle));
  });

  testWidgets('test_jobs_screen_build_property_empty_state_only_without_'
      'jobs', (WidgetTester tester) async {
    final Random random = seededRandom(1021502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Task> jobs = randomJobs(random);
      final AppDependencies dependencies = buildDependenciesWithJobs(jobs);
      final List<Task> listed = dependencies.jobRepository.listJobs();
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildJobsScreen(
          dependencies: dependencies,
          clock: dependencies.clock,
          navigation: AppNavigation(initialRoute: jobsRoute),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_emptyTitle), listed.isEmpty ? findsOne : findsNothing);
      expect(
        find.text(_summary, findRichText: true),
        listed.isEmpty ? findsNothing : findsOneWidget,
      );
      expect(find.text(_newJobLabel), findsOneWidget);
    }
  });

  testWidgets('test_jobs_screen_build_property_new_jobs_appear_at_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1021503);
    final AppDependencies dependencies = buildDependenciesWithJobs(
      const <Task>[],
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

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Task sample = randomJob(random, i);
      final Task created = await dependencies.jobRepository.createJob(
        JobDraft(task: sample.toDraft(), schedule: sample.schedule!),
      );
      await tester.pump();

      expect(find.text(created.title), findsOneWidget);
      expect(find.text(_emptyTitle), findsNothing);
    }
  });

  testWidgets('test_jobs_screen_build_page_property_rows_show_each_job', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1021504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildDependenciesWithJobs(
        randomJobs(random),
      );
      final Clock clock = FixedClock(randomLocalMoment(random));
      await pumpPageInRandomWindow(
        tester,
        random: random,
        page: buildJobsScreen(
          dependencies: dependencies,
          clock: clock,
          navigation: AppNavigation(initialRoute: jobsRoute),
        ),
      );

      for (final Task job in dependencies.jobRepository.listJobs()) {
        final List<String> rowTexts = readJobRowTexts(job);
        expect(rowTexts, contains(job.title));
        expect(rowTexts, contains(_describeProjectAndDoer(dependencies, job)));
        expect(rowTexts, contains(describeSchedule(job.schedule!)));
      }
    }
  });

  testWidgets('test_jobs_screen_build_page_property_rows_keep_the_'
      'repository_order', (WidgetTester tester) async {
    final Random random = seededRandom(1021505);

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

      double previousTop = double.negativeInfinity;
      for (final Task job in dependencies.jobRepository.listJobs()) {
        final double top = tester.getTopLeft(find.text(job.title)).dy;
        expect(top, greaterThan(previousTop));
        previousTop = top;
      }
    }
  });

  testWidgets('test_jobs_screen_build_page_property_column_labels_only_on_'
      'wide_lists', (WidgetTester tester) async {
    final Random random = seededRandom(1021507);

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

      final double windowWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final bool isWide = !LayoutSize.forWidth(windowWidth).isCompact;
      final bool showsLabels =
          isWide && dependencies.jobRepository.listJobs().isNotEmpty;
      for (final String label in _columnLabels) {
        expect(find.text(label), showsLabels ? findsOneWidget : findsNothing);
      }
    }
  });

  testWidgets('test_jobs_screen_build_new_job_button_property_opens_a_'
      'new_job', (WidgetTester tester) async {
    final Random random = seededRandom(1021506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildDependenciesWithJobs(
        randomJobs(random),
      );
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

      expect(navigation.routes, const <AppRoute>[jobsRoute, NewJobRoute()]);
    }
  });
}
