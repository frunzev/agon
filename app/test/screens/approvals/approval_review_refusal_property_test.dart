import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/screens/approvals/approval_dialog.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import 'support/approval_review_scene.dart';
import 'support/random_approval_requests.dart';

final class _EscapedProblems {
  final List<Object> problems = <Object>[];

  Future<void> watch(Future<void> work) async {
    try {
      await work;
    } on FormatException catch (problem) {
      problems.add(problem);
    }
  }
}

Future<ReviewScene> _pumpDecidingScene(WidgetTester tester, Random random) {
  return pumpReview(
    tester,
    random,
    requester: pickOne(random, galleryDevices),
    requestedAt: galleryNow,
  );
}

Future<void> _decide(
  WidgetTester tester,
  ReviewScene scene,
  ApprovalDecision decision,
) {
  final BuildContext context = tester.element(find.text(openDialogLabel));
  return scene.review.decide(
    rootContext: context,
    request: scene.request,
    decision: decision,
  );
}

void main() {
  testWidgets('test_approval_review_review_property_every_kind_shows_a_'
      'refusal_and_stays_pending', (WidgetTester tester) async {
    final Random random = seededRandom(96004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final PeopleFacingProblem problem = randomPeopleFacingProblem(random);
      final ReviewScene scene = await openReview(
        tester,
        random,
        requester: pickOne(random, galleryDevices),
        requestedAt: galleryNow,
      );
      scene.refusal.problem = problem.problem;

      final String label = describeDecisionLabel(decision);
      await tapButtonLabelled(tester, label);

      expect(tester.takeException(), isNull);
      expect(scene.refusal.attempts, 1);
      final String approvalTitle = describeApprovalTitle(
        scene.request.action,
        galleryWorkflows,
      );
      expect(find.text(approvalTitle), findsOneWidget);
      expect(find.text(describeRefusalTitle(label)), findsOneWidget);
      expect(find.text(problem.explanation), findsOneWidget);
      expect(scene.readStoredRequest().isPending, isTrue);
      await tapButtonLabelled(tester, refusalCloseLabel);
      expect(find.text(describeRefusalTitle(label)), findsNothing);
    }
  });

  testWidgets('test_approval_review_review_property_the_chosen_decision_'
      'is_stored', (WidgetTester tester) async {
    final Random random = seededRandom(96005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final ReviewScene scene = await openReview(
        tester,
        random,
        requester: pickOne(random, galleryDevices),
        requestedAt: galleryNow,
      );

      await tapButtonLabelled(tester, describeDecisionLabel(decision));

      expect(tester.takeException(), isNull);
      expect(scene.readStoredRequest().decision?.decision, decision);
      expect(find.byType(ApprovalDialog), findsNothing);
    }
  });

  testWidgets('test_approval_review_decide_property_titles_the_refusal_'
      'with_the_approval', (WidgetTester tester) async {
    final Random random = seededRandom(96006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final PeopleFacingProblem problem = randomPeopleFacingProblem(random);
      final ReviewScene scene = await _pumpDecidingScene(tester, random);
      scene.refusal.problem = problem.problem;

      final Future<void> deciding = _decide(tester, scene, decision);
      await pumpFrames(tester);

      final String label = describeDecisionLabel(decision);
      final String approvalTitle = describeApprovalTitle(
        scene.request.action,
        galleryWorkflows,
      );
      expect(find.text(approvalTitle), findsOneWidget);
      expect(find.text(describeRefusalTitle(label)), findsOneWidget);
      await tapButtonLabelled(tester, refusalCloseLabel);
      await deciding;
      expect(scene.readStoredRequest().isPending, isTrue);
    }
  });

  testWidgets('test_approval_review_decide_property_unexplained_problems_'
      'escape_for_every_kind', (WidgetTester tester) async {
    final Random random = seededRandom(96007);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final ReviewScene scene = await _pumpDecidingScene(tester, random);
      scene.refusal.problem = randomUnexplainedProblem(random);
      final _EscapedProblems escaped = _EscapedProblems();

      final Future<void> deciding = escaped.watch(
        _decide(tester, scene, decision),
      );
      await pumpFrames(tester);
      await deciding;

      final String label = describeDecisionLabel(decision);
      expect(escaped.problems, <Matcher>[isA<FormatException>()]);
      expect(find.text(describeRefusalTitle(label)), findsNothing);
      expect(scene.readStoredRequest().isPending, isTrue);
    }
  });
}
