import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/approvals/approval_dialog.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'support/approvals_screen_scene.dart';

const int _screenIterations = 6;
const Offset _barrierPoint = Offset(4, 4);

final List<ApprovalRequest> _reviewedHere = <ApprovalRequest>[
  galleryImproveSkillApproval,
  deployApproval,
];

final List<ApprovalRequest> _openedInChat = <ApprovalRequest>[
  galleryApprovals.first,
  galleryRunCommandApproval,
  deleteApproval,
];

String _titleOf(AppDependencies dependencies, ApprovalRequest request) {
  final List<Workflow> workflows = dependencies.workflowRepository
      .listWorkflows();
  return describeApprovalTitle(request.action, workflows);
}

Future<ApprovalsScene> _openRow(
  WidgetTester tester,
  Random random,
  ApprovalRequest request,
) async {
  final AppDependencies dependencies = replaceApprovals(
    buildGalleryDependencies(),
    <ApprovalRequest>[request],
  );
  final ApprovalsScene scene = await pumpApprovalsScreen(
    tester,
    random: random,
    dependencies: dependencies,
  );
  await tapRowTitled(tester, _titleOf(dependencies, request));
  return scene;
}

List<ApprovalRequest> _pendingIn(ApprovalsScene scene) {
  return scene.dependencies.approvalRepository.listPendingApprovals();
}

void main() {
  testWidgets('test_open_request_property_sign_requests_open_the_change', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616601);
    for (int i = 0; i < _screenIterations; i += 1) {
      final ApprovalRequest request = galleryApprovals[1];
      final SignWorkflowAction action = request.action as SignWorkflowAction;

      final ApprovalsScene scene = await _openRow(tester, random, request);

      expect(
        scene.navigation.currentRoute,
        WorkflowChangeRoute(action.workflowId),
      );
    }
  });

  testWidgets('test_open_request_property_run_requests_open_the_chat', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616602);
    for (int i = 0; i < _screenIterations; i += 1) {
      final ApprovalRequest request = pickOne(random, _openedInChat);

      final ApprovalsScene scene = await _openRow(tester, random, request);

      expectNoProblem(tester);
      expect(scene.navigation.currentRoute, ChatRoute(request.runId!));
    }
  });

  testWidgets('test_open_request_property_skill_and_runless_ask_here', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616603);
    for (int i = 0; i < _screenIterations; i += 1) {
      final ApprovalRequest request = pickOne(random, _reviewedHere);

      final ApprovalsScene scene = await _openRow(tester, random, request);

      expectNoProblem(tester);
      expect(scene.navigation.currentRoute, approvalsRoute);
      expect(find.text(approveDecisionLabel), findsOneWidget);
      expect(find.text(denyDecisionLabel), findsOneWidget);
    }
  });

  testWidgets('test_review_here_property_a_decision_settles_the_request', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616604);
    for (int i = 0; i < _screenIterations; i += 1) {
      final ApprovalRequest request = pickOne(random, _reviewedHere);
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final ApprovalsScene scene = await _openRow(tester, random, request);

      await tapButtonLabelled(tester, describeDecisionLabel(decision));

      expectNoProblem(tester);
      expect(_pendingIn(scene), isEmpty);
      final ApprovalRequest decided = scene.dependencies.approvalRepository
          .findApproval(request.id);
      expect(decided.decision!.decision, decision);
    }
  });

  testWidgets('test_review_here_property_dismissing_keeps_it_waiting', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616605);
    for (int i = 0; i < _screenIterations; i += 1) {
      final ApprovalRequest request = pickOne(random, _reviewedHere);
      final ApprovalsScene scene = await _openRow(tester, random, request);

      await tester.tapAt(_barrierPoint);
      await pumpFrames(tester);

      expectNoProblem(tester);
      expect(find.text(approveDecisionLabel), findsNothing);
      expect(_pendingIn(scene).single.id, request.id);
    }
  });

  testWidgets('test_review_here_property_names_the_asking_device', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616606);
    for (int i = 0; i < _screenIterations; i += 1) {
      final ApprovalRequest request = pickOne(random, _reviewedHere);

      final ApprovalsScene scene = await _openRow(tester, random, request);

      final String requester = scene.dependencies.deviceRepository
          .findDevice(request.requestedBy)
          .name;
      expect(find.textContaining('Agent on $requester'), findsOneWidget);
    }
  });
}
