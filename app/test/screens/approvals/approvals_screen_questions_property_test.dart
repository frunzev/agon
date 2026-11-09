import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/approvals/approval_dialog.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/screens/approvals/approvals_screen.dart';

import '../../support/random_inputs.dart';
import 'support/approvals_screen_scene.dart';

const int _screenIterations = 6;

List<double> _rowTops(
  WidgetTester tester,
  AppDependencies dependencies,
  List<ApprovalRequest> pending,
) {
  final List<Workflow> workflows = dependencies.workflowRepository
      .listWorkflows();
  final List<double> tops = <double>[];
  for (final ApprovalRequest request in pending) {
    final String title = describeApprovalTitle(request.action, workflows);
    tops.add(findTopOf(tester, title));
  }
  return tops;
}

void main() {
  testWidgets('test_build_questions_property_section_only_with_questions', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616407);
    for (int i = 0; i < _screenIterations; i += 1) {
      final bool hasQuestion = random.nextBool();
      final AppDependencies dependencies = replaceApprovals(
        hasQuestion ? buildQuestionDependencies() : buildGalleryDependencies(),
        pickApprovals(random),
      );

      await pumpApprovalsScreen(
        tester,
        random: random,
        dependencies: dependencies,
      );

      expect(
        find.text(questionsSectionTitle),
        hasQuestion ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_build_questions_property_questions_come_first', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616408);
    for (int i = 0; i < _screenIterations; i += 1) {
      final List<ApprovalRequest> pending = listPending(approvalPool);
      final AppDependencies dependencies = replaceApprovals(
        buildQuestionDependencies(),
        pending,
      );

      await pumpApprovalsScreen(
        tester,
        random: random,
        dependencies: dependencies,
      );

      final double questionsTop = findTopOf(tester, questionsSectionTitle);
      final double approvalsTop = findTopOf(tester, approvalsSectionTitle);
      expect(approvalsTop, greaterThan(questionsTop));
    }
  });

  testWidgets('test_build_questions_property_answers_never_decide_'
      'approvals', (WidgetTester tester) async {
    final Random random = seededRandom(616409);
    for (int i = 0; i < _screenIterations; i += 1) {
      final List<ApprovalRequest> pending = listPending(pickApprovals(random));
      final AppDependencies dependencies = replaceApprovals(
        buildQuestionDependencies(),
        pending,
      );

      await pumpApprovalsScreen(
        tester,
        random: random,
        dependencies: dependencies,
      );

      expectNoProblem(tester);
      expect(find.text(approveDecisionLabel), findsNothing);
      expect(
        dependencies.approvalRepository.listPendingApprovals(),
        hasLength(pending.length),
      );
    }
  });

  testWidgets('test_build_approval_list_property_one_row_per_request', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(617001);
    for (int i = 0; i < _screenIterations; i += 1) {
      final List<ApprovalRequest> pending = listPending(pickApprovals(random));
      final AppDependencies dependencies = replaceApprovals(
        random.nextBool()
            ? buildQuestionDependencies()
            : buildGalleryDependencies(),
        pending,
      );

      await pumpApprovalsScreen(
        tester,
        random: random,
        dependencies: dependencies,
      );

      expect(find.text(reviewLabel), findsNWidgets(pending.length));
    }
  });

  testWidgets('test_build_approval_list_property_rows_keep_the_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(617002);
    for (int i = 0; i < _screenIterations; i += 1) {
      final List<ApprovalRequest> pending = listPending(approvalPool);
      pending.shuffle(random);
      final AppDependencies dependencies = replaceApprovals(
        buildGalleryDependencies(),
        pending,
      );
      await pumpApprovalsScreen(
        tester,
        random: random,
        dependencies: dependencies,
      );

      final List<double> tops = _rowTops(tester, dependencies, pending);

      for (int index = 1; index < tops.length; index += 1) {
        expect(tops[index], greaterThan(tops[index - 1]));
      }
    }
  });

  testWidgets('test_build_approval_list_property_rows_sit_under_their_'
      'title', (WidgetTester tester) async {
    final Random random = seededRandom(617003);
    for (int i = 0; i < _screenIterations; i += 1) {
      final List<ApprovalRequest> pending = listPending(approvalPool);
      final AppDependencies dependencies = replaceApprovals(
        buildQuestionDependencies(),
        pending,
      );
      await pumpApprovalsScreen(
        tester,
        random: random,
        dependencies: dependencies,
      );

      final double titleTop = findTopOf(tester, approvalsSectionTitle);

      for (final double rowTop in _rowTops(tester, dependencies, pending)) {
        expect(rowTop, greaterThan(titleTop));
      }
    }
  });
}
