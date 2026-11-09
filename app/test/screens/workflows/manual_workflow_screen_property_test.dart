import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'manual_workflow_scene.dart';

TextEditingController _readNameController(WidgetTester tester) {
  return tester
      .widget<TextField>(findFieldInput(workflowNameLabel))
      .controller!;
}

void main() {
  test('test_manual_workflow_screen_constructor_property_keeps_every_'
      'field', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final AppNavigation navigation = AppNavigation(
        initialRoute: manualWorkflowsRoute,
      );
      final ManualWorkflowScreen screen = buildManualScreen(
        workflows: dependencies.workflowRepository,
        dependencies: dependencies,
        navigation: navigation,
      );

      expect(screen.workflowRepository, same(dependencies.workflowRepository));
      expect(
        screen.workspaceRepository,
        same(dependencies.workspaceRepository),
      );
      expect(screen.deviceRepository, same(dependencies.deviceRepository));
      expect(screen.runnerRepository, same(dependencies.runnerRepository));
      expect(screen.skillRepository, same(dependencies.skillRepository));
      expect(screen.navigation, same(navigation));
    }
  });

  testWidgets('test_manual_workflow_screen_constructor_property_starts_'
      'empty_and_unnamed', (WidgetTester tester) async {
    final Random random = seededRandom(1220901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);

      expect(_readNameController(tester).text, isEmpty);
      expect(find.text(emptyCanvasText), findsOneWidget);
      expect(find.byType(EditableWorkflowDiagram), findsNothing);
      expect(find.text(describeManualSummary(0)), findsOneWidget);
    }
  });

  testWidgets('test_manual_workflow_screen_constructor_property_saves_into_'
      'the_current_workspace', (WidgetTester tester) async {
    final Random random = seededRandom(1220902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ManualScene scene = await openManualScene(
        tester,
        random,
        refusal: null,
      );
      await tester.enterText(findFieldInput(workflowNameLabel), 'made-$i');
      await addRandomSteps(tester, random);
      await fillEveryStep(tester);

      await tapManualLabel(tester, signAndSaveLabel);
      await tester.pump();

      final Workflow saved = scene.stored.listWorkflows().last;
      expect(saved.name, 'made-$i');
      expect(saved.availability, isA<OnlyWorkspaces>());
      expect((saved.availability as OnlyWorkspaces).workspaces, <Object>[
        scene.dependencies.workspaceRepository.currentWorkspace().id,
      ]);
    }
  });

  test('test_manual_workflow_screen_create_state_property_each_call_makes_'
      'a_fresh_state', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    for (int i = 0; i < propertyIterations; i += 1) {
      final ManualWorkflowScreen screen = buildManualScreen(
        workflows: dependencies.workflowRepository,
        dependencies: dependencies,
        navigation: AppNavigation(initialRoute: manualWorkflowsRoute),
      );

      expect(identical(screen.createState(), screen.createState()), isFalse);
    }
  });

  testWidgets('test_manual_workflow_screen_create_state_property_rebuilds_'
      'keep_the_steps', (WidgetTester tester) async {
    final Random random = seededRandom(1220903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);
      final int added = await addRandomSteps(tester, random);
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      useViewSize(tester, Size(width, desktopHeight));
      await tester.pump();

      expect(readManualWorkflow(tester).agents.length, added);
    }
  });

  testWidgets('test_manual_workflow_screen_create_state_property_reopening_'
      'starts_over', (WidgetTester tester) async {
    final Random random = seededRandom(1220904);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);
      await addRandomSteps(tester, random);
      await tester.enterText(findFieldInput(workflowNameLabel), 'left-$i');
      await openManualScene(tester, random, refusal: null);

      expect(find.byType(EditableWorkflowDiagram), findsNothing);
      expect(_readNameController(tester).text, isEmpty);
    }
  });

  testWidgets('test_manual_workflow_screen_dispose_property_leaving_saves_'
      'nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1220905);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ManualScene scene = await openManualScene(
        tester,
        random,
        refusal: null,
      );
      final int countBefore = scene.stored.listWorkflows().length;
      await addRandomSteps(tester, random);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull);
      expect(scene.stored.listWorkflows().length, countBefore);
      expect(scene.navigation.routes, manualRoutes);
    }
  });

  testWidgets('test_manual_workflow_screen_dispose_property_releases_the_'
      'name_field', (WidgetTester tester) async {
    final Random random = seededRandom(1220906);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);
      final TextEditingController controller = _readNameController(tester);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(() => controller.addListener(() {}), throwsFlutterError);
    }
  });

  testWidgets('test_manual_workflow_screen_dispose_property_cancel_and_back_'
      'leave_only_the_builder', (WidgetTester tester) async {
    final Random random = seededRandom(1220907);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ManualScene scene = await openManualScene(
        tester,
        random,
        refusal: null,
      );
      await addRandomSteps(tester, random);

      if (random.nextBool()) {
        await tapManualLabel(tester, cancelBuildingLabel);
      } else {
        await tester.tap(find.byType(BackLinkButton));
        await tester.pump();
      }

      expect(scene.navigation.routes, manualRoutes.sublist(0, 2));
    }
  });

  testWidgets('test_manual_workflow_screen_build_property_never_overflows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1220908);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);
      if (random.nextBool()) {
        await addRandomSteps(tester, random);
      }
      if (random.nextBool()) {
        await tapManualLabel(tester, signAndSaveLabel);
      }

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_manual_workflow_screen_build_property_matches_the_design_'
      'wording', (WidgetTester tester) async {
    final Random random = seededRandom(1220909);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);

      expect(find.text(newWorkflowTitle), findsOneWidget);
      expect(find.text(cancelBuildingLabel), findsOneWidget);
      expect(find.text(signAndSaveLabel), findsOneWidget);
      expect(find.text(workflowNameLabel), findsOneWidget);
      expect(find.text(addAgentLabel), findsOneWidget);
      expect(find.text(addPersonStepLabel), findsOneWidget);
      expect(find.text(workflowNameHint), findsOneWidget);
    }
  });

  testWidgets('test_manual_workflow_screen_build_property_no_fill_in_offer', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1220910);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openManualScene(tester, random, refusal: null);
      await tapManualLabel(tester, addAgentLabel);

      final AgentSettingsPanel panel = tester.widget<AgentSettingsPanel>(
        find.byType(AgentSettingsPanel),
      );
      expect(panel.onFillInRequested, isNull);
      expect(find.text('Fill in with agent'), findsNothing);
    }
  });
}
