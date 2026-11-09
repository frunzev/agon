import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/screens/approvals/approvals_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';

import '../../support/app_harness.dart';
import '../../support/arriving_approval_repository.dart';
import '../../support/random_inputs.dart';
import 'support/approvals_screen_scene.dart';

const int _screenIterations = 6;
const String _emptyTitle = 'No approvals waiting';

ApprovalsScreen _buildScreen(AppDependencies dependencies) {
  return ApprovalsScreen(
    approvalRepository: dependencies.approvalRepository,
    personStepRepository: dependencies.personStepRepository,
    taskRepository: dependencies.taskRepository,
    workflowRepository: dependencies.workflowRepository,
    deviceRepository: dependencies.deviceRepository,
    clock: dependencies.clock,
    navigation: AppNavigation(initialRoute: approvalsRoute),
  );
}

String _titleOf(AppDependencies dependencies, ApprovalRequest request) {
  final List<Workflow> workflows = dependencies.workflowRepository
      .listWorkflows();
  return describeApprovalTitle(request.action, workflows);
}

void main() {
  test('test_approvals_screen_constructor_property_keeps_every_'
      'repository', () {
    final AppDependencies dependencies = buildGalleryDependencies();

    final ApprovalsScreen screen = _buildScreen(dependencies);

    expect(screen.approvalRepository, same(dependencies.approvalRepository));
    expect(
      screen.personStepRepository,
      same(dependencies.personStepRepository),
    );
    expect(screen.taskRepository, same(dependencies.taskRepository));
    expect(screen.workflowRepository, same(dependencies.workflowRepository));
    expect(screen.deviceRepository, same(dependencies.deviceRepository));
  });

  test('test_approvals_screen_constructor_property_keeps_clock_and_'
      'navigation', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final AppNavigation navigation = AppNavigation(
      initialRoute: approvalsRoute,
    );

    final ApprovalsScreen screen = ApprovalsScreen(
      approvalRepository: dependencies.approvalRepository,
      personStepRepository: dependencies.personStepRepository,
      taskRepository: dependencies.taskRepository,
      workflowRepository: dependencies.workflowRepository,
      deviceRepository: dependencies.deviceRepository,
      clock: dependencies.clock,
      navigation: navigation,
    );

    expect(screen.clock, same(dependencies.clock));
    expect(screen.navigation, same(navigation));
  });

  test('test_approvals_screen_constructor_property_two_screens_share_'
      'nothing_mutable', () {
    final AppDependencies first = buildGalleryDependencies();
    final AppDependencies second = buildGalleryDependencies();

    final ApprovalsScreen firstScreen = _buildScreen(first);
    final ApprovalsScreen secondScreen = _buildScreen(second);

    expect(
      firstScreen.approvalRepository,
      isNot(same(secondScreen.approvalRepository)),
    );
    expect(firstScreen.navigation, isNot(same(secondScreen.navigation)));
  });

  testWidgets('test_approvals_screen_build_property_any_list_at_any_size', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616401);
    for (int i = 0; i < _screenIterations; i += 1) {
      final List<ApprovalRequest> approvals = pickApprovals(random);
      final AppDependencies dependencies = replaceApprovals(
        random.nextBool()
            ? buildGalleryDependencies()
            : buildQuestionDependencies(),
        approvals,
      );

      await pumpApprovalsScreen(
        tester,
        random: random,
        dependencies: dependencies,
      );

      expectNoProblem(tester);
      for (final ApprovalRequest request in listPending(approvals)) {
        expect(find.text(_titleOf(dependencies, request)), findsWidgets);
      }
    }
  });

  testWidgets('test_approvals_screen_build_property_arrivals_appear', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616402);
    for (int i = 0; i < _screenIterations; i += 1) {
      final ArrivingApprovalRepository arriving = ArrivingApprovalRepository();
      final AppDependencies dependencies = replaceRepositories(
        buildGalleryDependencies(),
        approvalRepository: arriving,
      );
      await pumpApprovalsScreen(
        tester,
        random: random,
        dependencies: dependencies,
      );
      expect(find.text(_emptyTitle), findsOneWidget);

      final ApprovalRequest arrival = pickOne(
        random,
        listPending(approvalPool),
      );
      arriving.raiseApproval(arrival);
      await pumpFrames(tester);

      expectNoProblem(tester);
      expect(find.text(_emptyTitle), findsNothing);
      expect(find.text(_titleOf(dependencies, arrival)), findsWidgets);
    }
  });

  testWidgets('test_approvals_screen_build_property_decisions_remove_rows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616403);
    for (int i = 0; i < _screenIterations; i += 1) {
      final List<ApprovalRequest> pending = listPending(approvalPool);
      final AppDependencies dependencies = replaceApprovals(
        buildGalleryDependencies(),
        pending,
      );
      await pumpApprovalsScreen(
        tester,
        random: random,
        dependencies: dependencies,
      );

      for (final ApprovalRequest request in pending) {
        await dependencies.approvalRepository.decideApproval(
          request.id,
          pickOne(random, ApprovalDecision.values),
        );
      }
      await pumpFrames(tester);

      expectNoProblem(tester);
      expect(find.text(_emptyTitle), findsOneWidget);
      expect(find.text(reviewLabel), findsNothing);
    }
  });

  testWidgets('test_build_page_property_empty_only_when_nothing_waits', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616404);
    for (int i = 0; i < _screenIterations; i += 1) {
      final List<ApprovalRequest> approvals = pickApprovals(random);
      final bool hasQuestion = random.nextBool();
      final AppDependencies dependencies = replaceApprovals(
        hasQuestion ? buildQuestionDependencies() : buildGalleryDependencies(),
        approvals,
      );

      await pumpApprovalsScreen(
        tester,
        random: random,
        dependencies: dependencies,
      );

      final bool isEmpty = listPending(approvals).isEmpty && !hasQuestion;
      expect(find.text(_emptyTitle), isEmpty ? findsOneWidget : findsNothing);
    }
  });

  testWidgets('test_build_page_property_summary_counts_the_rows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616405);
    for (int i = 0; i < _screenIterations; i += 1) {
      final List<ApprovalRequest> pending = listPending(pickApprovals(random));
      final bool hasQuestion = random.nextBool();
      if (pending.isEmpty && !hasQuestion) {
        continue;
      }
      final AppDependencies dependencies = replaceApprovals(
        hasQuestion ? buildQuestionDependencies() : buildGalleryDependencies(),
        pending,
      );

      await pumpApprovalsScreen(
        tester,
        random: random,
        dependencies: dependencies,
      );

      final String summary = describeWaitingWork(
        approvalCount: pending.length,
        questionCount: hasQuestion ? 1 : 0,
      );
      expect(find.text(summary), findsOneWidget);
      expect(find.text(reviewLabel), findsNWidgets(pending.length));
    }
  });

  testWidgets('test_build_page_property_approvals_titled_beside_'
      'questions', (WidgetTester tester) async {
    final Random random = seededRandom(616406);
    for (int i = 0; i < _screenIterations; i += 1) {
      final List<ApprovalRequest> pending = listPending(pickApprovals(random));
      final bool hasQuestion = random.nextBool();
      final AppDependencies dependencies = replaceApprovals(
        hasQuestion ? buildQuestionDependencies() : buildGalleryDependencies(),
        pending,
      );

      await pumpApprovalsScreen(
        tester,
        random: random,
        dependencies: dependencies,
      );

      final bool isTitled = hasQuestion && pending.isNotEmpty;
      expect(
        find.text(approvalsSectionTitle),
        isTitled ? findsOneWidget : findsNothing,
      );
    }
  });
}
