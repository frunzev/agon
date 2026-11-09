import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/screens/workflows/workflow_quick_start.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'random_workflow_records.dart';
import 'workflows_screen_scene.dart';

const String _newWorkflowLabel = 'New workflow';

WorkflowId _randomWorkflowId(Random random) {
  return WorkflowId('route-workflow-${random.nextInt(1000)}');
}

WorkflowId? _readRouteWorkflowId(AppRoute route) {
  if (route is WorkflowDetailRoute) {
    return route.workflowId;
  }
  if (route is WorkflowBuilderRoute) {
    return route.workflowId;
  }
  if (route is WorkflowChangeRoute) {
    return route.workflowId;
  }
  return null;
}

Finder _findNewWorkflowButton() {
  return find.widgetWithText(AppButton, _newWorkflowLabel);
}

Future<void> _tapNewWorkflow(WidgetTester tester) async {
  await tester.ensureVisible(_findNewWorkflowButton());
  await tester.tap(_findNewWorkflowButton());
  await tester.pump();
}

void main() {
  test('test_find_workflow_route_property_route_names_its_workflow', () {
    final Random random = seededRandom(12351);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowId workflowId = _randomWorkflowId(random);
      final SignatureState state = pickOne(random, SignatureState.values);

      final AppRoute route = findWorkflowRoute(workflowId, state);

      expect(_readRouteWorkflowId(route), workflowId);
      expect(route.section, AppSection.workflows);
    }
  });

  test('test_find_workflow_route_property_unsigned_opens_for_editing', () {
    final Random random = seededRandom(12352);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowId workflowId = _randomWorkflowId(random);
      final SignatureState state = pickOne(random, SignatureState.values);

      final AppRoute route = findWorkflowRoute(workflowId, state);

      expect(route, findWorkflowRoute(workflowId, state));
      if (state == SignatureState.notSignedYet) {
        expect(
          route,
          WorkflowBuilderRoute(workflowId, opening: BuilderOpening.forEditing),
        );
      }
    }
  });

  test('test_workflows_screen_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(12353);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowsScene scene = buildWorkflowsScene(
        random,
        randomSceneWorkflows(random),
      );

      expect(scene.screen.workflowRepository, same(scene.workflows));
      expect(scene.screen.workspaceRepository, same(scene.workspaces));
      expect(scene.screen.taskRepository, same(scene.tasks));
      expect(scene.screen.jobRepository, same(scene.jobs));
      expect(scene.screen.navigation, same(scene.navigation));
    }
  });

  test('test_workflows_screen_constructor_property_keeps_its_own_clock', () {
    final Random random = seededRandom(12354);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowsScene scene = buildWorkflowsScene(
        random,
        const <Workflow>[],
      );
      final Clock clock = FixedClock(randomLocalMoment(random));

      final WorkflowsScreen screen = WorkflowsScreen(
        workflowRepository: scene.workflows,
        workspaceRepository: scene.workspaces,
        taskRepository: scene.tasks,
        jobRepository: scene.jobs,
        clock: clock,
        navigation: scene.navigation,
      );

      expect(screen.clock, same(clock));
      expect(screen.key, isNull);
    }
  });

  test('test_workflows_screen_constructor_property_keeps_a_given_key', () {
    final Random random = seededRandom(12355);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowsScene scene = buildWorkflowsScene(
        random,
        const <Workflow>[],
      );
      final Key key = ValueKey<int>(random.nextInt(1000));

      final WorkflowsScreen screen = WorkflowsScreen(
        workflowRepository: scene.workflows,
        workspaceRepository: scene.workspaces,
        taskRepository: scene.tasks,
        jobRepository: scene.jobs,
        clock: scene.screen.clock,
        navigation: scene.navigation,
        key: key,
      );

      expect(screen.key, key);
    }
  });

  testWidgets('test_workflows_screen_build_property_renders_at_any_size', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(12356);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRandomWorkflowsScene(tester, random);

      expect(tester.takeException(), isNull);
      expect(find.text('Workflows'), findsOneWidget);
      expect(_findNewWorkflowButton(), findsOneWidget);
    }
  });

  testWidgets('test_workflows_screen_build_property_follows_deletions', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(12357);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowsScene scene = await pumpRandomWorkflowsScene(
        tester,
        random,
      );
      final List<Workflow> listed = scene.workflows.listWorkflows();
      if (listed.isEmpty) {
        continue;
      }
      final Workflow removed = pickOne(random, listed);

      await scene.workflows.deleteWorkflow(removed.id);
      await tester.pump();

      expect(findWorkflowName(removed), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_workflows_screen_build_property_new_runs_show_at_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(12358);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowsScene scene = buildWorkflowsSceneWithWork(
        random,
        workflows: <Workflow>[randomSignableWorkflow(random)],
        sceneWork: (work: const <Task>[], runs: const <Run>[]),
      );
      await pumpPageInRandomWindow(tester, random: random, page: scene.screen);
      final Workflow workflow = scene.workflows.listWorkflows().single;
      if (findExpectedState(scene, workflow) != SignatureState.signed) {
        continue;
      }

      await startWorkflowNow(
        taskRepository: scene.tasks,
        workflow: workflow,
        projectId: GalleryProjectIds.acmeApp,
      );
      await tester.pump();

      expect(readWorkflowRowTexts(workflow), contains('Just now'));
    }
  });

  testWidgets('test_workflows_screen_build_new_workflow_button_property_opens_'
      'new_workflow', (WidgetTester tester) async {
    final Random random = seededRandom(12359);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowsScene scene = await pumpRandomWorkflowsScene(
        tester,
        random,
      );

      await _tapNewWorkflow(tester);

      expect(scene.navigation.currentRoute, const NewWorkflowRoute());
    }
  });

  testWidgets('test_workflows_screen_build_new_workflow_button_property_shown_'
      'once_with_or_without_workflows', (WidgetTester tester) async {
    final Random random = seededRandom(12360);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Workflow> workflows = random.nextBool()
          ? const <Workflow>[]
          : randomSceneWorkflows(random);
      final WorkflowsScene scene = buildWorkflowsScene(random, workflows);
      await pumpPageInRandomWindow(tester, random: random, page: scene.screen);

      expect(_findNewWorkflowButton(), findsOneWidget);
    }
  });

  testWidgets('test_workflows_screen_build_new_workflow_button_property_twice_'
      'tapped_opens_once', (WidgetTester tester) async {
    final Random random = seededRandom(12361);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowsScene scene = await pumpRandomWorkflowsScene(
        tester,
        random,
      );

      await _tapNewWorkflow(tester);
      await _tapNewWorkflow(tester);

      expect(scene.navigation.routes, const <AppRoute>[
        workflowsSectionRoute,
        NewWorkflowRoute(),
      ]);
    }
  });
}
