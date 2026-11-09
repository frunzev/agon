import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/workflows.dart';

import '../../data/fakes/support/task_inputs.dart';
import '../../data/fakes/support/workflow_usage_inputs.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../support/random_page_windows.dart';
import 'random_workflow_records.dart';
import 'workflows_screen_scene.dart';

const String _emptyTitle = 'No workflows yet';
const String _signedNote =
    'Runners only run versions signed with one of your keys.';
const String _summary =
    'Available in all your workspaces unless you limit it.';

bool _isUsableInAcme(Workflow workflow) {
  final WorkspaceScope availability = workflow.availability;
  switch (availability) {
    case AllWorkspaces():
      return true;
    case OnlyWorkspaces():
      return availability.workspaces.contains(GalleryWorkspaceIds.acme);
  }
}

Future<WorkflowsScene> _pumpScene(
  WidgetTester tester,
  Random random,
  List<Workflow> workflows,
) async {
  final WorkflowsScene scene = buildWorkflowsScene(random, workflows);
  await pumpPageInRandomWindow(tester, random: random, page: scene.screen);
  return scene;
}

SceneWork _buildJobOnlyWork(Random random, WorkflowId workflowId) {
  final Task job = buildWorkWithDoer(
    random,
    identifier: 'scene-job',
    doer: WorkflowDoer(workflowId),
    schedule: randomJobSchedule(random),
  );
  final Run run = buildSeededRun(
    random,
    runId: 'scene-job-run',
    taskId: job.id,
    number: 1,
    status: 'done',
  );
  return (work: <Task>[job], runs: <Run>[run]);
}

void main() {
  testWidgets('test_workflows_screen_build_page_property_rows_follow_the_'
      'listing_order', (WidgetTester tester) async {
    final Random random = seededRandom(12371);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowsScene scene = await pumpRandomWorkflowsScene(
        tester,
        random,
      );
      double previousTop = double.negativeInfinity;

      for (final Workflow workflow in scene.workflows.listWorkflows()) {
        final Finder name = findWorkflowName(workflow);
        expect(name, findsOneWidget);
        final double top = tester.getTopLeft(name).dy;
        expect(top, greaterThan(previousTop));
        previousTop = top;
      }
    }
  });

  testWidgets('test_workflows_screen_build_page_property_lists_only_this_'
      'workspaces_workflows', (WidgetTester tester) async {
    final Random random = seededRandom(12372);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workflow> workflows = randomSceneWorkflows(random);
      await _pumpScene(tester, random, workflows);

      for (final Workflow workflow in workflows) {
        expect(
          findWorkflowName(workflow),
          _isUsableInAcme(workflow) ? findsOneWidget : findsNothing,
        );
      }
    }
  });

  testWidgets('test_workflows_screen_build_page_property_empty_state_only_'
      'without_rows', (WidgetTester tester) async {
    final Random random = seededRandom(12373);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowsScene scene = await pumpRandomWorkflowsScene(
        tester,
        random,
      );
      final bool isEmpty = scene.workflows.listWorkflows().isEmpty;

      expect(tester.takeException(), isNull);
      expect(find.text(_emptyTitle), isEmpty ? findsOneWidget : findsNothing);
      expect(find.text(_signedNote), isEmpty ? findsNothing : findsOneWidget);
      expect(
        find.text(_summary, findRichText: true),
        isEmpty ? findsNothing : findsOneWidget,
      );
    }
  });

  testWidgets('test_workflows_screen_build_row_property_shows_its_workflow_'
      'facts', (WidgetTester tester) async {
    final Random random = seededRandom(12374);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowsScene scene = await pumpRandomWorkflowsScene(
        tester,
        random,
      );
      final List<Workspace> workspaces = scene.workspaces.listWorkspaces();

      for (final Workflow workflow in scene.workflows.listWorkflows()) {
        final DateTime? lastUse = findExpectedLastUse(scene, workflow.id);
        final SignatureState state = findExpectedState(scene, workflow);
        final List<String> facts = <String>[
          workflow.name,
          describeAgentNames(workflow),
          describeAvailability(workflow.availability, workspaces),
          describeLastUse(lastUse, galleryNow),
          describeSignatureState(state),
        ];

        final List<String> rowTexts = readWorkflowRowTexts(workflow);
        for (final String fact in facts) {
          expect(rowTexts, contains(fact));
        }
      }
    }
  });

  testWidgets('test_workflows_screen_build_row_property_tap_opens_the_page_'
      'for_its_signature', (WidgetTester tester) async {
    final Random random = seededRandom(12375);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowsScene scene = await pumpRandomWorkflowsScene(
        tester,
        random,
      );
      final List<Workflow> listed = scene.workflows.listWorkflows();
      if (listed.isEmpty) {
        continue;
      }
      final Workflow tapped = pickOne(random, listed);
      final SignatureState state = findExpectedState(scene, tapped);

      await tester.ensureVisible(findWorkflowName(tapped));
      await tester.tap(findWorkflowName(tapped));
      await tester.pump();

      expect(
        scene.navigation.currentRoute,
        findWorkflowRoute(tapped.id, state),
      );
    }
  });

  testWidgets('test_workflows_screen_build_row_property_job_runs_count_as_'
      'last_use', (WidgetTester tester) async {
    final Random random = seededRandom(12376);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Workflow workflow = randomSignableWorkflow(random);
      final SceneWork sceneWork = _buildJobOnlyWork(random, workflow.id);
      final WorkflowsScene scene = buildWorkflowsSceneWithWork(
        random,
        workflows: <Workflow>[workflow],
        sceneWork: sceneWork,
      );
      await pumpPageInRandomWindow(tester, random: random, page: scene.screen);

      final String expected = describeLastUse(
        sceneWork.runs.single.startedAt,
        galleryNow,
      );
      final List<String> rowTexts = readWorkflowRowTexts(workflow);
      expect(rowTexts, contains(expected));
      expect(rowTexts, isNot(contains('Never')));
    }
  });
}
