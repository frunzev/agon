import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/screens/approvals/run_approval_prompts.dart';

import '../../support/arriving_approval_repository.dart';
import '../../support/random_inputs.dart';
import 'support/run_prompts_scene.dart';

const int _promptIterations = 6;

void main() {
  test('test_run_approval_prompts_constructor_property_keeps_every_'
      'dependency', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    final ArrivingApprovalRepository approvals = ArrivingApprovalRepository();

    final RunApprovalPrompts prompts = buildRunPrompts(
      dependencies: dependencies,
      approvalRepository: approvals,
    );

    expect(prompts.runId, promptedRunId);
    expect(prompts.taskRepository, same(dependencies.taskRepository));
    expect(prompts.workflowRepository, same(dependencies.workflowRepository));
    expect(prompts.approvalRepository, same(approvals));
    expect(prompts.deviceRepository, same(dependencies.deviceRepository));
    expect(prompts.clock, same(dependencies.clock));
  });

  test('test_run_approval_prompts_constructor_property_keeps_the_child', () {
    final RunApprovalPrompts prompts = buildRunPrompts(
      dependencies: buildGalleryDependencies(),
      approvalRepository: ArrivingApprovalRepository(),
    );

    expect(prompts.child, isA<Text>());
    expect((prompts.child as Text).data, promptedPageText);
  });

  test('test_run_approval_prompts_constructor_property_keeps_the_key', () {
    final AppDependencies dependencies = buildGalleryDependencies();
    const Key key = ValueKey<String>('prompts');

    final RunApprovalPrompts prompts = RunApprovalPrompts(
      key: key,
      runId: promptedRunId,
      taskRepository: dependencies.taskRepository,
      workflowRepository: dependencies.workflowRepository,
      approvalRepository: ArrivingApprovalRepository(),
      deviceRepository: dependencies.deviceRepository,
      clock: dependencies.clock,
      child: const SizedBox.shrink(),
    );

    expect(prompts.key, key);
  });

  test('test_run_approval_prompts_create_state_property_fresh_each_time', () {
    final RunApprovalPrompts prompts = buildRunPrompts(
      dependencies: buildGalleryDependencies(),
      approvalRepository: ArrivingApprovalRepository(),
    );

    expect(prompts.createState(), isNot(same(prompts.createState())));
  });

  testWidgets('test_run_approval_prompts_create_state_property_state_'
      'belongs_to_the_widget', (WidgetTester tester) async {
    final Random random = seededRandom(616701);
    for (int i = 0; i < _promptIterations; i += 1) {
      await pumpRunPrompts(
        tester,
        random: random,
        approvalRepository: ArrivingApprovalRepository(),
      );

      final State<RunApprovalPrompts> state = tester.state(
        find.byType(RunApprovalPrompts),
      );
      expect(state.widget.runId, promptedRunId);
      expect(state.mounted, isTrue);
    }
  });

  testWidgets('test_run_approval_prompts_create_state_property_new_page_'
      'asks_again', (WidgetTester tester) async {
    final Random random = seededRandom(616702);
    for (int i = 0; i < _promptIterations; i += 1) {
      final ArrivingApprovalRepository approvals =
          ArrivingApprovalRepository();
      approvals.raiseApproval(
        buildRunApproval(runId: promptedRunId, number: i, random: random),
      );
      await pumpRunPrompts(
        tester,
        random: random,
        approvalRepository: approvals,
      );
      await dismissDialog(tester);

      await pumpRunPrompts(
        tester,
        random: random,
        approvalRepository: approvals,
      );

      expect(countOpenDialogs(), 1);
    }
  });

  testWidgets('test_run_approval_prompts_build_property_shows_the_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616703);
    for (int i = 0; i < _promptIterations; i += 1) {
      await pumpRunPrompts(
        tester,
        random: random,
        approvalRepository: ArrivingApprovalRepository(),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(promptedPageText), findsOneWidget);
      expect(countOpenDialogs(), 0);
    }
  });

  testWidgets('test_run_approval_prompts_build_property_page_stays_under_'
      'the_dialog', (WidgetTester tester) async {
    final Random random = seededRandom(616704);
    for (int i = 0; i < _promptIterations; i += 1) {
      final ArrivingApprovalRepository approvals =
          ArrivingApprovalRepository();
      approvals.raiseApproval(
        buildRunApproval(runId: promptedRunId, number: i, random: random),
      );

      await pumpRunPrompts(
        tester,
        random: random,
        approvalRepository: approvals,
      );

      expect(tester.takeException(), isNull);
      expect(countOpenDialogs(), 1);
      expect(find.text(promptedPageText), findsOneWidget);
    }
  });

  testWidgets('test_run_approval_prompts_build_property_adds_nothing_'
      'around_the_page', (WidgetTester tester) async {
    final Random random = seededRandom(616705);
    for (int i = 0; i < _promptIterations; i += 1) {
      await pumpRunPrompts(
        tester,
        random: random,
        approvalRepository: ArrivingApprovalRepository(),
      );

      final RunApprovalPrompts prompts = tester.widget(
        find.byType(RunApprovalPrompts),
      );
      final Element promptsElement = tester.element(
        find.byType(RunApprovalPrompts),
      );
      final List<Widget> children = <Widget>[];
      promptsElement.visitChildren((Element child) {
        children.add(child.widget);
      });
      expect(children.single, same(prompts.child));
    }
  });

  testWidgets('test_init_state_property_waiting_request_is_asked_at_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616706);
    for (int i = 0; i < _promptIterations; i += 1) {
      final ArrivingApprovalRepository approvals =
          ArrivingApprovalRepository();
      approvals.raiseApproval(
        buildRunApproval(runId: promptedRunId, number: i, random: random),
      );

      await pumpRunPrompts(
        tester,
        random: random,
        approvalRepository: approvals,
      );

      expect(countOpenDialogs(), 1);
    }
  });

  testWidgets('test_init_state_property_other_runs_are_not_asked', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616707);
    for (int i = 0; i < _promptIterations; i += 1) {
      final ArrivingApprovalRepository approvals =
          ArrivingApprovalRepository();
      approvals.raiseApproval(
        buildRunApproval(runId: otherRunId, number: i, random: random),
      );

      await pumpRunPrompts(
        tester,
        random: random,
        approvalRepository: approvals,
      );

      expect(countOpenDialogs(), 0);
    }
  });

  testWidgets('test_init_state_property_listens_for_arrivals', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616708);
    for (int i = 0; i < _promptIterations; i += 1) {
      final ArrivingApprovalRepository approvals =
          ArrivingApprovalRepository();
      await pumpRunPrompts(
        tester,
        random: random,
        approvalRepository: approvals,
      );

      approvals.raiseApproval(
        buildRunApproval(runId: promptedRunId, number: i, random: random),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(countOpenDialogs(), 1);
    }
  });
}
