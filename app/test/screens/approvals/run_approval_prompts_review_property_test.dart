import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/screens/approvals/approval_dialog.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';

import '../../support/app_harness.dart';
import '../../support/arriving_approval_repository.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_work_repositories.dart';
import 'support/run_prompts_scene.dart';

const int _promptIterations = 6;
const int _largestQueue = 4;

ApprovalRequest _deployFor(RunId runId, int number) {
  return ApprovalRequest(
    id: ApprovalId('deploy-${runId.value}-$number'),
    runId: runId,
    action: DeployAction(target: 'target-$number'),
    requestedBy: GalleryDeviceIds.macStudio,
    requestedAt: galleryToday(14, 9),
    decision: null,
  );
}

String _dialogTitle(int number) => 'Deploy to target-$number?';

Future<ArrivingApprovalRepository> _pumpWithQueue(
  WidgetTester tester,
  Random random,
  int queueLength,
) async {
  final ArrivingApprovalRepository approvals = ArrivingApprovalRepository();
  for (int number = 0; number < queueLength; number += 1) {
    approvals.raiseApproval(_deployFor(promptedRunId, number));
  }
  await pumpRunPrompts(tester, random: random, approvalRepository: approvals);
  return approvals;
}

Future<void> _decide(WidgetTester tester, Random random) async {
  final ApprovalDecision decision = pickOne(random, ApprovalDecision.values);
  await tapButtonLabelled(tester, describeDecisionLabel(decision));
}

void main() {
  testWidgets('test_schedule_approval_review_property_asks_after_a_frame', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616801);
    for (int i = 0; i < _promptIterations; i += 1) {
      final ArrivingApprovalRepository approvals = await _pumpWithQueue(
        tester,
        random,
        0,
      );

      approvals.raiseApproval(_deployFor(promptedRunId, i));
      expect(countOpenDialogs(), 0);
      await pumpFrames(tester);

      expect(countOpenDialogs(), 1);
    }
  });

  testWidgets('test_schedule_approval_review_property_one_dialog_at_a_'
      'time', (WidgetTester tester) async {
    final Random random = seededRandom(616802);
    for (int i = 0; i < _promptIterations; i += 1) {
      final ArrivingApprovalRepository approvals = await _pumpWithQueue(
        tester,
        random,
        0,
      );

      for (int number = 0; number < 1 + random.nextInt(4); number += 1) {
        approvals.raiseApproval(_deployFor(promptedRunId, number));
      }
      await pumpFrames(tester);

      expect(countOpenDialogs(), 1);
    }
  });

  testWidgets('test_schedule_approval_review_property_other_runs_change_'
      'nothing', (WidgetTester tester) async {
    final Random random = seededRandom(616803);
    for (int i = 0; i < _promptIterations; i += 1) {
      final ArrivingApprovalRepository approvals = await _pumpWithQueue(
        tester,
        random,
        1,
      );

      approvals.raiseApproval(_deployFor(otherRunId, i));
      await pumpFrames(tester);

      expect(countOpenDialogs(), 1);
      expect(find.text(_dialogTitle(0)), findsOneWidget);
    }
  });

  testWidgets('test_start_approval_review_property_decisions_lead_to_the_'
      'next', (WidgetTester tester) async {
    final Random random = seededRandom(616804);
    for (int i = 0; i < _promptIterations; i += 1) {
      await _pumpWithQueue(tester, random, 2);

      await _decide(tester, random);

      expect(find.text(_dialogTitle(1)), findsOneWidget);
    }
  });

  testWidgets('test_start_approval_review_property_dismissal_leads_to_the_'
      'next', (WidgetTester tester) async {
    final Random random = seededRandom(616805);
    for (int i = 0; i < _promptIterations; i += 1) {
      await _pumpWithQueue(tester, random, 2);

      await dismissDialog(tester);

      expect(find.text(_dialogTitle(1)), findsOneWidget);
    }
  });

  testWidgets('test_start_approval_review_property_dismissed_is_not_'
      'asked_again', (WidgetTester tester) async {
    final Random random = seededRandom(616806);
    for (int i = 0; i < _promptIterations; i += 1) {
      final ArrivingApprovalRepository approvals = await _pumpWithQueue(
        tester,
        random,
        1,
      );
      await dismissDialog(tester);

      approvals.raiseApproval(_deployFor(otherRunId, i));
      await pumpFrames(tester);

      expect(countOpenDialogs(), 0);
      expect(approvals.listPendingApprovals(), hasLength(2));
    }
  });

  testWidgets('test_find_unreviewed_approval_property_asks_in_arrival_'
      'order', (WidgetTester tester) async {
    final Random random = seededRandom(616807);
    for (int i = 0; i < _promptIterations; i += 1) {
      final int queueLength = 1 + random.nextInt(_largestQueue);
      await _pumpWithQueue(tester, random, queueLength);

      for (int number = 0; number < queueLength; number += 1) {
        expect(find.text(_dialogTitle(number)), findsOneWidget);
        await dismissDialog(tester);
      }

      expect(countOpenDialogs(), 0);
    }
  });

  testWidgets('test_find_unreviewed_approval_property_only_this_run', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616808);
    for (int i = 0; i < _promptIterations; i += 1) {
      final ArrivingApprovalRepository approvals =
          ArrivingApprovalRepository();
      final int otherCount = 1 + random.nextInt(_largestQueue);
      for (int number = 0; number < otherCount; number += 1) {
        approvals.raiseApproval(_deployFor(otherRunId, number));
      }

      await pumpRunPrompts(
        tester,
        random: random,
        approvalRepository: approvals,
      );

      expect(countOpenDialogs(), 0);
    }
  });

  testWidgets('test_find_unreviewed_approval_property_decided_are_'
      'skipped', (WidgetTester tester) async {
    final Random random = seededRandom(616809);
    for (int i = 0; i < _promptIterations; i += 1) {
      final ArrivingApprovalRepository approvals =
          ArrivingApprovalRepository();
      approvals.raiseApproval(_deployFor(promptedRunId, 0));
      await approvals.decideApproval(
        _deployFor(promptedRunId, 0).id,
        pickOne(random, ApprovalDecision.values),
      );

      await pumpRunPrompts(
        tester,
        random: random,
        approvalRepository: approvals,
      );

      expect(countOpenDialogs(), 0);
    }
  });

  testWidgets('test_review_next_approval_property_decision_is_recorded', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616810);
    for (int i = 0; i < _promptIterations; i += 1) {
      final ArrivingApprovalRepository approvals = await _pumpWithQueue(
        tester,
        random,
        1,
      );
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );

      await tapButtonLabelled(tester, describeDecisionLabel(decision));

      expect(approvals.listApprovals().single.decision!.decision, decision);
      expect(countOpenDialogs(), 0);
    }
  });

  testWidgets('test_review_next_approval_property_refusals_are_explained', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616811);
    for (int i = 0; i < _promptIterations; i += 1) {
      final ArrivingApprovalRepository stored = ArrivingApprovalRepository();
      stored.raiseApproval(_deployFor(promptedRunId, i));
      final ExplainedRefusal planned = randomExplainedRefusal(random);
      final PlannedRefusal refusal = PlannedRefusal()
        ..problem = planned.problem;
      await pumpRunPrompts(
        tester,
        random: random,
        approvalRepository: RefusingApprovalRepository(
          stored: stored,
          refusal: refusal,
        ),
      );

      await _decide(tester, random);

      expect(find.byType(ActionRefusalDialog), findsOneWidget);
      expect(find.textContaining(planned.explanation), findsOneWidget);
      expect(stored.listPendingApprovals(), hasLength(1));
    }
  });

  testWidgets('test_review_next_approval_property_every_request_is_asked_'
      'once', (WidgetTester tester) async {
    final Random random = seededRandom(616812);
    for (int i = 0; i < _promptIterations; i += 1) {
      final int queueLength = 1 + random.nextInt(_largestQueue);
      final ArrivingApprovalRepository approvals = await _pumpWithQueue(
        tester,
        random,
        queueLength,
      );
      int decidedCount = 0;

      for (int number = 0; number < queueLength; number += 1) {
        expect(countOpenDialogs(), 1);
        if (random.nextBool()) {
          await _decide(tester, random);
          decidedCount += 1;
        } else {
          await dismissDialog(tester);
        }
      }

      expect(countOpenDialogs(), 0);
      expect(
        approvals.listPendingApprovals(),
        hasLength(queueLength - decidedCount),
      );
    }
  });
}
