import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/screens/task_run/task_run_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/run_page_retry_harness.dart';
import 'support/run_steps_section_scenes.dart';
import 'support/task_run_screen_scenes.dart';

TaskRunScreen _buildScreen(
  AppDependencies dependencies, {
  required RunId runId,
  required Key? key,
}) {
  return TaskRunScreen(
    key: key,
    runId: runId,
    taskRepository: dependencies.taskRepository,
    workflowRepository: dependencies.workflowRepository,
    projectRepository: dependencies.projectRepository,
    deviceRepository: dependencies.deviceRepository,
    approvalRepository: dependencies.approvalRepository,
    personStepRepository: dependencies.personStepRepository,
    runnerRepository: dependencies.runnerRepository,
    clock: dependencies.clock,
    navigation: AppNavigation(initialRoute: TaskRunRoute(runId)),
    runWindowOpener: null,
  );
}

List<String> _readShownStepNames(WidgetTester tester) {
  return <String>[
    for (final ListRowData row in readStepRows(tester)) readRowMain(row).title,
  ];
}

List<String> _listStepNames(Run run) {
  return <String>[for (final RunStep step in run.steps) step.name];
}

void main() {
  test('test_task_run_screen_property_keeps_every_field', () {
    final Random random = seededRandom(115601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final RunId runId = RunId(randomText(random));
      final TaskRunScreen screen = _buildScreen(
        dependencies,
        runId: runId,
        key: null,
      );

      expect(screen.runId, runId);
      expect(
        identical(screen.taskRepository, dependencies.taskRepository),
        isTrue,
      );
      expect(
        identical(screen.workflowRepository, dependencies.workflowRepository),
        isTrue,
      );
      expect(
        identical(screen.projectRepository, dependencies.projectRepository),
        isTrue,
      );
      expect(
        identical(screen.deviceRepository, dependencies.deviceRepository),
        isTrue,
      );
      expect(
        identical(screen.approvalRepository, dependencies.approvalRepository),
        isTrue,
      );
      expect(
        identical(
          screen.personStepRepository,
          dependencies.personStepRepository,
        ),
        isTrue,
      );
      expect(
        identical(screen.runnerRepository, dependencies.runnerRepository),
        isTrue,
      );
      expect(identical(screen.clock, dependencies.clock), isTrue);
      expect(screen.runWindowOpener, isNull);
    }
  });

  test('test_task_run_screen_property_keeps_the_given_key', () {
    final Random random = seededRandom(115602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomText(random));
      final TaskRunScreen screen = _buildScreen(
        buildGalleryDependencies(),
        runId: RunId(randomText(random)),
        key: key,
      );

      expect(screen.key, key);
    }
  });

  test('test_task_run_screen_property_constructing_reads_no_run', () {
    final Random random = seededRandom(115603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunId unknownRun = RunId('missing ${randomText(random)}');

      expect(
        () => _buildScreen(
          buildGalleryDependencies(),
          runId: unknownRun,
          key: null,
        ),
        returnsNormally,
      );
    }
  });

  testWidgets('test_task_run_screen_build_property_random_runs_render_whole', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(115604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageScene scene = randomRunPageScene(random);
      await openRunPage(
        tester,
        random: random,
        dependencies: scene.dependencies,
        runId: scene.run.id,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(TaskRunScreen), findsOneWidget);
      expect(_readShownStepNames(tester), _listStepNames(scene.run));
    }
  });

  testWidgets('test_task_run_screen_build_property_watches_only_while_open', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(115605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageScene scene = randomRunPageScene(random);
      final AppNavigation navigation = await openRunPage(
        tester,
        random: random,
        dependencies: scene.dependencies,
        runId: scene.run.id,
      );
      expect(scene.tasks.isWatchingRun(scene.run.id), isTrue);

      navigation.openSection(const SectionRoute(AppSection.tasks));
      await pumpFrames(tester);

      expect(find.byType(TaskRunScreen), findsNothing);
      expect(scene.tasks.isWatchingRun(scene.run.id), isFalse);
    }
  });

  testWidgets('test_task_run_screen_build_property_steps_read_top_to_bottom', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(115606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageScene scene = randomRunPageScene(random);
      await openRunPage(
        tester,
        random: random,
        dependencies: scene.dependencies,
        runId: scene.run.id,
      );

      double previousTop = double.negativeInfinity;
      for (final ListRowData row in readStepRows(tester)) {
        final double top = tester.getTopLeft(find.byWidget(row.main)).dy;
        expect(top, greaterThan(previousTop));
        previousTop = top;
      }
    }
  });
}
