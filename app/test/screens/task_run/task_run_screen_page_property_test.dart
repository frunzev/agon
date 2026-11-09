import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/doer_text.dart';
import 'package:agent_orchestration/presentation/run_text.dart';

import '../../support/random_inputs.dart';
import 'support/run_page_retry_harness.dart';
import 'support/task_run_screen_scenes.dart';

final DeviceNames _deviceNames = DeviceNames(galleryDevices);

String? _describeExpectedFailureTitle(Run run) {
  final RunFailure? failure = run.failure;
  if (failure == null) {
    return null;
  }
  final DeviceId? runner = failure.runner;
  if (runner == null) {
    return '${failure.stepName} failed';
  }
  final String runnerName = _deviceNames.describeDevice(runner);
  return '${failure.stepName} failed on $runnerName';
}

void main() {
  testWidgets(
    'test_task_run_screen_build_page_property_label_names_workflow_or_task',
    (WidgetTester tester) async {
      final Random random = seededRandom(115607);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final RunPageScene scene = randomRunPageScene(random);
        await openRunPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
          runId: scene.run.id,
        );

        final Workflow? workflow = findWorkflowForDoer(
          scene.task.doer,
          galleryWorkflows,
        );
        final String name = workflow?.name ?? scene.task.title;
        expect(find.text('$name #${scene.run.number}'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'test_task_run_screen_build_page_property_summary_names_task_project_time',
    (WidgetTester tester) async {
      final Random random = seededRandom(115608);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final RunPageScene scene = randomRunPageScene(random);
        await openRunPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
          runId: scene.run.id,
        );

        final String projectName = scene.dependencies.projectRepository
            .findProject(scene.task.projectId)
            .name;
        final String timing = describeRunTiming(scene.run, galleryNow);
        final String summary = '${scene.task.title} · $projectName · $timing';
        expect(find.text(summary, findRichText: true), findsOneWidget);
      }
    },
  );

  testWidgets(
    'test_task_run_screen_build_page_property_failure_banner_only_on_failure',
    (WidgetTester tester) async {
      final Random random = seededRandom(115609);

      for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
        final RunPageScene scene = randomRunPageScene(random);
        await openRunPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
          runId: scene.run.id,
        );

        final String? title = _describeExpectedFailureTitle(scene.run);
        if (title == null) {
          expect(
            find.textContaining(RegExp(r' failed( on |$)')),
            findsNothing,
          );
        } else {
          expect(find.text(title), findsOneWidget);
          expect(find.text(scene.run.failure!.reason), findsOneWidget);
        }
      }
    },
  );
}
