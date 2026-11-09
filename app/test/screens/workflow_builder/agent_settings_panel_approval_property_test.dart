import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/screens/shared/approval_policy_field.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../support/random_page_windows.dart';
import 'agent_settings_panel_scene.dart';

const Map<ApprovalPolicy?, String> _choiceTitles = <ApprovalPolicy?, String>{
  null: 'Same as the project',
  ApprovalPolicy.neverAsk: 'Auto',
  ApprovalPolicy.askBeforeRiskyActions: 'Ask me',
};

void main() {
  testWidgets('test_build_approval_field_property_shows_the_agent_policy', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162304);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalPolicy? policy = randomInheritableApprovalPolicy(random);

      await pumpAgentSettings(
        tester,
        random: random,
        agent: randomSettingsAgent(random).withApprovalPolicy(policy),
        canFillIn: false,
      );

      final ApprovalPolicyField field = tester.widget(
        find.byType(ApprovalPolicyField),
      );
      expect(field.selected, policy);
      expect(field.fallback, ApprovalPolicyFallback.project);
    }
  });

  testWidgets('test_build_approval_field_property_tap_saves_that_policy', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162305);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentSettingsScene scene = await pumpAgentSettings(
        tester,
        random: random,
        agent: randomSettingsAgent(random),
        canFillIn: false,
      );
      final WorkflowAgent agent = scene.shownAgent.value;
      final ApprovalPolicy? policy = randomInheritableApprovalPolicy(random);

      await tapShownText(tester, _choiceTitles[policy]!);

      if (policy == agent.approvalPolicy) {
        expect(scene.changes.length, lessThanOrEqualTo(1));
      } else {
        expect(scene.changes.single, agent.withApprovalPolicy(policy));
      }
      expect(scene.shownAgent.value.approvalPolicy, policy);
    }
  });

  testWidgets('test_build_approval_field_property_titles_match_design', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162306);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpAgentSettings(
        tester,
        random: random,
        agent: randomSettingsAgent(random),
        canFillIn: false,
      );

      for (final String title in _choiceTitles.values) {
        expect(find.text(title), findsOneWidget);
      }
    }
  });
}
