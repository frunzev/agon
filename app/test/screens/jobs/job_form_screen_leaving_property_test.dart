import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/jobs/jobs_screen.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../support/form_leaving_scene.dart';

const SectionRoute _jobsRoute = SectionRoute(AppSection.jobs);
const String _createJobLabel = 'Create job';
const String _saveJobLabel = 'Save job';
const String _cancelLabel = 'Cancel';
const String _titleLabel = 'What should be done?';

List<AppRoute> _randomNewJobRoutes(Random random) {
  final AppRoute form = NewItemFormRoute(DraftKind.job);
  if (random.nextBool()) {
    return <AppRoute>[_jobsRoute, form];
  }
  return <AppRoute>[_jobsRoute, const NewJobRoute(), form];
}

List<Task> _listOneAgentJobs() {
  final List<Task> jobs = buildGalleryDependencies().jobRepository.listJobs();
  return <Task>[
    for (final Task job in jobs)
      if (job.doer is OneAgentDoer) job,
  ];
}

Future<void> _leaveForm(WidgetTester tester, Random random) async {
  if (random.nextBool()) {
    await pressBackLink(tester);
    return;
  }
  await pressShownButton(tester, _cancelLabel);
  await pumpFrames(tester);
}

Future<void> _typeJobTitle(WidgetTester tester, String title) async {
  await enterFieldText(tester, label: _titleLabel, text: title);
}

void main() {
  testWidgets('test_job_form_screen_build_property_a_new_job_form_leaves_'
      'to_the_jobs_list_its_back_link_names', (WidgetTester tester) async {
    final Random random = seededRandom(5310701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewJobRoutes(random),
      );
      final String backLabel = readBackLinkLabel(tester);

      await _leaveForm(tester, random);

      expect(tester.takeException(), isNull);
      expect(backLabel, AppSection.jobs.label);
      expect(scene.navigation.routes, const <AppRoute>[_jobsRoute]);
      expect(find.byType(JobsScreen), findsOneWidget);
    }
  });

  testWidgets('test_job_form_screen_build_property_an_edit_leaves_to_the_'
      'jobs_list', (WidgetTester tester) async {
    final Random random = seededRandom(5310702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Task job = pickOne(random, _listOneAgentJobs());
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: <AppRoute>[_jobsRoute, EditJobRoute(job.id)],
      );
      final String backLabel = readBackLinkLabel(tester);

      await _leaveForm(tester, random);

      expect(backLabel, AppSection.jobs.label);
      expect(scene.navigation.routes, const <AppRoute>[_jobsRoute]);
      expect(scene.saveHold.saveCount, 0);
    }
  });

  testWidgets('test_job_form_screen_build_property_leaving_stores_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(5310703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewJobRoutes(random),
      );
      final int jobCount = scene.dependencies.jobRepository.listJobs().length;
      await _typeJobTitle(tester, 'Typed ${randomText(random)}');

      await _leaveForm(tester, random);

      expect(scene.dependencies.jobRepository.listJobs(), hasLength(jobCount));
      expect(scene.saveHold.saveCount, 0);
    }
  });

  testWidgets('test_job_form_screen_save_job_property_a_person_who_moved_on_'
      'stays_where_they_went', (WidgetTester tester) async {
    final Random random = seededRandom(5310704);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewJobRoutes(random),
      );
      await _typeJobTitle(tester, 'Held job $i');

      final List<AppRoute> wentTo = await saveWhileMovingOn(
        tester,
        random: random,
        scene: scene,
        saveLabel: _createJobLabel,
      );

      expect(tester.takeException(), isNull);
      expect(scene.navigation.routes, wentTo);
      expect(scene.navigation.routes, isNotEmpty);
    }
  });

  testWidgets('test_job_form_screen_save_job_property_moving_on_still_'
      'stores_the_edit', (WidgetTester tester) async {
    final Random random = seededRandom(5310705);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Task job = pickOne(random, _listOneAgentJobs());
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: <AppRoute>[_jobsRoute, EditJobRoute(job.id)],
      );
      final String title = 'Edited job $i';
      await _typeJobTitle(tester, title);

      final List<AppRoute> wentTo = await saveWhileMovingOn(
        tester,
        random: random,
        scene: scene,
        saveLabel: _saveJobLabel,
      );

      final Task stored = scene.dependencies.jobRepository.findJob(job.id);
      expect(stored.title, title);
      expect(scene.navigation.routes, wentTo);
      expect(scene.saveHold.saveCount, 1);
    }
  });

  testWidgets('test_job_form_screen_save_job_property_a_shown_form_closes_'
      'to_the_jobs_list', (WidgetTester tester) async {
    final Random random = seededRandom(5310706);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewJobRoutes(random),
      );
      await _typeJobTitle(tester, 'Shown job $i');

      await pressShownButton(tester, _createJobLabel);
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(scene.navigation.routes, const <AppRoute>[_jobsRoute]);
    }
  });
}
