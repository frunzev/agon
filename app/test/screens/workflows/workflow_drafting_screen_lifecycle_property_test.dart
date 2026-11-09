import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/workflows/workflow_drafting_screen.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'workflow_drafting_scene.dart';

const String _unexplainedProblem =
    'The drafting agent stopped without saying why. Try again.';

Future<void> _tapLabel(WidgetTester tester, String label) async {
  await tapVisible(tester, find.text(label));
  await tester.pump();
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  testWidgets('test_workflow_drafting_screen_show_progress_property_opens', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54201);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );
      final WorkflowDraftProgress finished = buildWorkflowDraftProgress(
        random,
        pending: 0,
      );

      scene.workflows.progress.add(finished);
      await tester.pump();

      expect(scene.navigation.routes, <AppRoute>[
        const SectionRoute(AppSection.workflows),
        WorkflowBuilderRoute(
          finished.workflow.id,
          opening: BuilderOpening.afterDrafting,
        ),
      ]);
      await _leave(tester);
      expect(scene.workflows.stoppedDrafts, isEmpty);
    }
  });

  testWidgets('test_workflow_drafting_screen_show_progress_property_stays', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54202);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );
      final List<AppRoute> routesBefore = scene.navigation.routes;

      for (int step = 0; step < 1 + random.nextInt(3); step += 1) {
        scene.workflows.progress.add(
          buildWorkflowDraftProgress(random, pending: 1 + random.nextInt(3)),
        );
        await tester.pump();
      }

      expect(scene.navigation.routes, routesBefore);
      expect(find.text(stopDraftingLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_workflow_drafting_screen_show_progress_property_late', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54203);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );
      final List<AppRoute> routesBefore = scene.navigation.routes;
      await _leave(tester);

      scene.workflows.progress.add(
        buildWorkflowDraftProgress(random, pending: random.nextInt(2)),
      );
      await tester.pump();

      expect(scene.navigation.routes, routesBefore);
      expect(scene.workflows.stoppedDrafts, <WorkflowDraft>[scene.draft]);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_workflow_drafting_screen_show_problem_property_reason', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54204);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );
      final String reason = 'Refused $i ${randomWordPhrase(random)}'.trim();

      scene.workflows.progress.addError(PeopleFacingRefusal(reason));
      await tester.pump();

      expect(find.text(draftFailedTitle), findsOneWidget);
      expect(find.text(reason), findsOneWidget);
      expect(find.text(stopDraftingLabel), findsNothing);
    }
  });

  testWidgets('test_workflow_drafting_screen_show_problem_property_generic', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54205);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );

      scene.workflows.progress.addError(StateError('raw $i'));
      await tester.pump();

      expect(find.text(_unexplainedProblem), findsOneWidget);
      expect(find.text('raw $i'), findsNothing);
    }
  });

  testWidgets('test_workflow_drafting_screen_show_problem_property_no_stop', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54206);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );
      scene.workflows.progress.addError(PeopleFacingRefusal('No $i'));
      await tester.pump();

      if (random.nextBool()) {
        await _tapLabel(tester, workflowsBackLabel);
      }
      await _leave(tester);

      expect(scene.workflows.stoppedDrafts, isEmpty);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_workflow_drafting_screen_stop_drafting_property_closes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54207);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );

      await _tapLabel(tester, stopDraftingLabel);

      expect(scene.navigation.routes, <AppRoute>[
        const SectionRoute(AppSection.workflows),
      ]);
      expect(scene.workflows.stoppedDrafts, <WorkflowDraft>[scene.draft]);
    }
  });

  testWidgets('test_workflow_drafting_screen_stop_drafting_property_refused', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(54208);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );
      final List<AppRoute> routesBefore = scene.navigation.routes;
      scene.workflows.stopRefusal = PeopleFacingRefusal('Cannot stop $i');

      await _tapLabel(
        tester,
        random.nextBool() ? stopDraftingLabel : workflowsBackLabel,
      );

      expect(find.text(stopFailedTitle), findsOneWidget);
      expect(find.text('Cannot stop $i'), findsOneWidget);
      expect(scene.navigation.routes, routesBefore);
    }
  });
}
