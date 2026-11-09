import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/workflows/workflow_drafting_screen.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'workflow_drafting_scene.dart';

Future<void> _leaveByAnyOtherRoute(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  testWidgets('test_workflow_drafting_screen_dispose_property_leaving_stops', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52901);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );
      for (int step = 0; step < random.nextInt(3); step += 1) {
        scene.workflows.progress.add(
          buildWorkflowDraftProgress(random, pending: 1 + random.nextInt(3)),
        );
        await tester.pump();
      }

      await _leaveByAnyOtherRoute(tester);

      expect(scene.workflows.stoppedDrafts, <WorkflowDraft>[scene.draft]);
      expect(tester.takeException(), isNull, reason: 'round $i');
    }
  });

  testWidgets('test_workflow_drafting_screen_dispose_property_ended_stays', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52902);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );
      final bool finishes = random.nextBool();
      if (finishes) {
        scene.workflows.progress.add(
          buildWorkflowDraftProgress(random, pending: 0),
        );
      } else {
        scene.workflows.progress.addError(PeopleFacingRefusal('Failed $i'));
      }
      await tester.pump();

      await _leaveByAnyOtherRoute(tester);

      expect(scene.workflows.stoppedDrafts, isEmpty, reason: '$finishes');
      expect(tester.takeException(), isNull, reason: 'round $i');
    }
  });

  testWidgets('test_workflow_drafting_screen_dispose_property_stops_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52903);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );
      final String label = random.nextBool()
          ? stopDraftingLabel
          : workflowsBackLabel;
      await tapVisible(tester, find.text(label));
      await tester.pump();

      await _leaveByAnyOtherRoute(tester);

      expect(scene.workflows.stoppedDrafts, <WorkflowDraft>[scene.draft]);
      expect(tester.takeException(), isNull, reason: label);
    }
  });

  testWidgets('test_workflow_drafting_screen_dispose_property_refusal_quiet', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52904);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );
      scene.workflows.stopRefusal = random.nextBool()
          ? PeopleFacingRefusal('Cannot stop $i')
          : StateError('node is gone $i');

      await _leaveByAnyOtherRoute(tester);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(scene.workflows.stoppedDrafts, isEmpty);
    }
  });

  testWidgets('test_workflow_drafting_screen_stop_drafting_property_retried', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52905);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final WorkflowDraftingScene scene = await openWorkflowDrafting(
        tester,
        random,
      );
      scene.workflows.stopRefusal = PeopleFacingRefusal('Cannot stop $i');
      await tapVisible(tester, find.text(stopDraftingLabel));
      await tester.pump();
      expect(find.text(stopFailedTitle), findsOneWidget);
      scene.workflows.stopRefusal = null;

      await _leaveByAnyOtherRoute(tester);

      expect(scene.workflows.stoppedDrafts, <WorkflowDraft>[scene.draft]);
      expect(tester.takeException(), isNull, reason: 'round $i');
    }
  });
}
