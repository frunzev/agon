import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'workflow_drafting_flow_scene.dart';
import 'workflow_drafting_scene.dart';

const Duration _betweenTwoTaps = Duration(milliseconds: 80);

bool _isStopEnabled(WidgetTester tester) {
  final AppButton button = tester.widget<AppButton>(
    find.widgetWithText(AppButton, stopDraftingLabel),
  );
  return button.onPressed != null;
}

void main() {
  testWidgets('test_workflow_drafting_screen_open_workflows_property_back_'
      'after_a_failure_opens_only_workflows', (WidgetTester tester) async {
    final Random random = seededRandom(1220708);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene scene = await openDraftingFlow(tester, random);
      scene.workflows.progress.addError(StateError('raw $i'));
      await tester.pump();

      await tapVisible(tester, find.text(workflowsBackLabel));
      await tester.pump();

      expect(scene.navigation.routes, const <AppRoute>[flowWorkflowsRoute]);
      expect(scene.workflows.stoppedDrafts, isEmpty);
    }
  });

  testWidgets('test_workflow_drafting_screen_open_workflows_property_back_'
      'while_drafting_stops_then_opens_workflows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1220709);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene scene = await openDraftingFlow(tester, random);
      await addRandomDraftProgress(tester, random, scene);

      await tapVisible(tester, find.text(workflowsBackLabel));
      await tester.pump();

      expect(scene.navigation.routes, const <AppRoute>[flowWorkflowsRoute]);
      expect(scene.workflows.stoppedDrafts, <WorkflowDraft>[scene.draft]);
    }
  });

  testWidgets('test_workflow_drafting_screen_open_workflows_property_a_'
      'refused_stop_opens_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1220710);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene scene = await openDraftingFlow(tester, random);
      final List<AppRoute> routesBefore = scene.navigation.routes;
      scene.workflows.stopRefusal = PeopleFacingRefusal('Busy $i');

      await tapVisible(tester, find.text(workflowsBackLabel));
      await tester.pump();

      expect(scene.navigation.routes, routesBefore);
      expect(find.text(stopFailedTitle), findsOneWidget);
      expect(find.text('Busy $i'), findsOneWidget);
    }
  });

  testWidgets('test_workflow_drafting_screen_leave_drafting_property_double_'
      'taps_stop_once', (WidgetTester tester) async {
    final Random random = seededRandom(1220711);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene scene = await openDraftingFlow(tester, random);
      final Completer<void> hold = Completer<void>();
      scene.workflows.stopHold = hold;
      final String first = random.nextBool()
          ? stopDraftingLabel
          : workflowsBackLabel;
      final String second = random.nextBool()
          ? stopDraftingLabel
          : workflowsBackLabel;

      await tapVisible(tester, find.text(first));
      await tester.pump(_betweenTwoTaps);
      await tester.tap(find.text(second), warnIfMissed: false);
      await tester.pump(_betweenTwoTaps);
      hold.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(scene.workflows.stoppedDrafts, <WorkflowDraft>[
        scene.draft,
      ], reason: '$first then $second');
      expect(scene.navigation.routes.length, lessThan(3));
    }
  });

  testWidgets('test_workflow_drafting_screen_leave_drafting_property_stop_'
      'returns_to_the_description', (WidgetTester tester) async {
    final Random random = seededRandom(1220712);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene scene = await openDraftingFlow(tester, random);
      await addRandomDraftProgress(tester, random, scene);

      await tapVisible(tester, find.text(stopDraftingLabel));
      await tester.pump();

      expect(scene.navigation.routes, const <AppRoute>[
        flowWorkflowsRoute,
        NewWorkflowRoute(),
      ]);
      expect(scene.workflows.stoppedDrafts, <WorkflowDraft>[scene.draft]);
    }
  });

  testWidgets('test_workflow_drafting_screen_leave_drafting_property_a_'
      'finished_draft_is_never_stopped', (WidgetTester tester) async {
    final Random random = seededRandom(1220713);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene scene = await openDraftingFlow(tester, random);
      await addRandomDraftProgress(tester, random, scene);
      final WorkflowDraftProgress finished = buildWorkflowDraftProgress(
        random,
        pending: 0,
      );
      scene.workflows.progress.add(finished);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());

      expect(scene.workflows.stoppedDrafts, isEmpty);
      expect(scene.navigation.routes, <AppRoute>[
        flowWorkflowsRoute,
        WorkflowBuilderRoute(
          finished.workflow.id,
          opening: BuilderOpening.afterDrafting,
        ),
      ]);
    }
  });

  testWidgets('test_workflow_drafting_screen_finish_stopping_property_stop_'
      'is_off_while_stopping', (WidgetTester tester) async {
    final Random random = seededRandom(1221501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene scene = await openDraftingFlow(tester, random);
      final Completer<void> hold = Completer<void>();
      scene.workflows.stopHold = hold;

      await tapVisible(tester, find.text(stopDraftingLabel));
      await tester.pump();

      expect(_isStopEnabled(tester), isFalse);
      hold.complete();
      await tester.pump();
    }
  });

  testWidgets('test_workflow_drafting_screen_finish_stopping_property_a_'
      'refused_stop_turns_stop_back_on', (WidgetTester tester) async {
    final Random random = seededRandom(1221502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene scene = await openDraftingFlow(tester, random);
      scene.workflows.stopRefusal = PeopleFacingRefusal('Stuck $i');

      await tapVisible(tester, find.text(stopDraftingLabel));
      await tester.pump();

      expect(_isStopEnabled(tester), isTrue);
      expect(find.text('Stuck $i'), findsOneWidget);
    }
  });

  testWidgets('test_workflow_drafting_screen_finish_stopping_property_a_'
      'retry_after_a_refusal_stops_and_leaves', (WidgetTester tester) async {
    final Random random = seededRandom(1221503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftingFlowScene scene = await openDraftingFlow(tester, random);
      scene.workflows.stopRefusal = PeopleFacingRefusal('Stuck $i');
      await tapVisible(tester, find.text(stopDraftingLabel));
      await tester.pump();
      scene.workflows.stopRefusal = null;

      await tapVisible(tester, find.text(stopDraftingLabel));
      await tester.pump();

      expect(scene.workflows.stoppedDrafts, <WorkflowDraft>[
        scene.draft,
        scene.draft,
      ]);
      expect(scene.navigation.routes, const <AppRoute>[
        flowWorkflowsRoute,
        NewWorkflowRoute(),
      ]);
    }
  });
}
