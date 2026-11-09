import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/arriving_approval_repository.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/run_prompts_scene.dart';

const int _promptIterations = 6;

void main() {
  testWidgets('test_dispose_property_a_removed_page_asks_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616709);
    for (int i = 0; i < _promptIterations; i += 1) {
      final ArrivingApprovalRepository approvals =
          ArrivingApprovalRepository();
      await pumpRunPrompts(
        tester,
        random: random,
        approvalRepository: approvals,
      );
      await tester.pumpWidget(
        wrapInApp(const SizedBox.shrink(), platform: desktopPlatform),
      );

      approvals.raiseApproval(
        buildRunApproval(runId: promptedRunId, number: i, random: random),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(countOpenDialogs(), 0);
    }
  });

  testWidgets('test_dispose_property_leaving_with_an_open_dialog_is_safe', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616710);
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

      await tester.pumpWidget(const SizedBox.shrink());
      approvals.raiseApproval(
        buildRunApproval(runId: promptedRunId, number: i + 1, random: random),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_dispose_property_decisions_survive_leaving', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(616711);
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

      await tester.pumpWidget(const SizedBox.shrink());

      expect(approvals.listPendingApprovals(), hasLength(1));
      expect(tester.takeException(), isNull);
    }
  });
}
