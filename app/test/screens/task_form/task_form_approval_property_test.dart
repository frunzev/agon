import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/screens/shared/approval_policy_field.dart';
import 'package:agent_orchestration/screens/task_form/folder_runner_notice.dart';
import 'package:agent_orchestration/screens/task_form/sign_workflow_notice.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/task_form_values.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import '../support/random_page_windows.dart';
import 'task_form_scene.dart';

const Map<ApprovalPolicy?, String> _choiceTitles = <ApprovalPolicy?, String>{
  null: 'Same as the project',
  ApprovalPolicy.neverAsk: 'Auto',
  ApprovalPolicy.askBeforeRiskyActions: 'Ask me',
};
const List<String> _designLabels = <String>[
  'What should be done?',
  'Details',
  'Project',
  'Who does it',
  'Runs on',
  'A workflow picks its own runners.',
  'Where agents run',
  'Skills to use',
  'Commands and pushes',
  'Repeat',
];

Future<ApprovalPolicy?> _tapRandomPolicy(
  WidgetTester tester,
  Random random,
) async {
  final ApprovalPolicy? policy = randomInheritableApprovalPolicy(random);
  await tapShownText(tester, _choiceTitles[policy]!);
  return policy;
}

void main() {
  testWidgets('test_build_approval_field_property_shows_the_chosen_policy', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131701);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskFormValues initial = randomTaskFormValues(random, options);

      await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: initial,
        options: options,
        answerSubmit: answerAtOnce,
      );

      final ApprovalPolicyField field = tester.widget(
        find.byType(ApprovalPolicyField),
      );
      expect(field.selected, initial.approvalPolicy);
      expect(field.fallback, ApprovalPolicyFallback.project);
      for (final String title in _choiceTitles.values) {
        expect(find.text(title), findsOneWidget);
      }
    }
  });

  testWidgets('test_build_approval_field_property_last_tap_is_saved', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131702);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskFormValues initial = randomSavableValues(random, options);
      ApprovalPolicy? expected = initial.approvalPolicy;
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: initial,
        options: options,
        answerSubmit: answerAtOnce,
      );
      final int tapCount = 1 + random.nextInt(4);

      for (int tap = 0; tap < tapCount; tap += 1) {
        expected = await _tapRandomPolicy(tester, random);
        expect(scene.reportedChanges.last.approvalPolicy, expected);
      }
      await tapTaskFormSubmit(tester);

      expect(scene.submitted.single.approvalPolicy, expected);
      final ApprovalPolicyField field = tester.widget(
        find.byType(ApprovalPolicyField),
      );
      expect(field.selected, expected);
    }
  });

  testWidgets('test_build_approval_field_property_keeps_the_typed_title', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131703);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskFormValues initial = randomSavableValues(random, options);
      final TaskFormScene scene = await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: initial,
        options: options,
        answerSubmit: answerAtOnce,
      );
      await enterFieldText(
        tester,
        label: taskFormTitleLabel,
        text: 'Typed ${randomText(random)}',
      );

      final ApprovalPolicy? tapped = await _tapRandomPolicy(tester, random);

      final TaskFormValues reported = scene.reportedChanges.last;
      expect(reported.approvalPolicy, tapped);
      expect(reported.title, readFieldText(tester, taskFormTitleLabel));
      expect(reported.projectId, initial.projectId);
      expect(reported.doer, initial.doer);
    }
  });

  testWidgets('test_task_form_build_property_random_drafts_follow_design', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1131704);
    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final TaskFormOptions options = buildRandomTaskFormOptions(random);
      final TaskFormValues initial = randomTaskFormValues(random, options);

      await pumpTaskFormScene(
        tester,
        random: random,
        initialValues: initial,
        options: options,
        answerSubmit: answerAtOnce,
      );

      expect(tester.takeException(), isNull, reason: 'round $i');
      for (final String label in _designLabels) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      final bool isWeekly = initial.repeat == RepeatChoice.weekly;
      expect(find.text('On'), isWeekly ? findsOneWidget : findsNothing);
      final bool needsTime = initial.repeat.needsTime;
      expect(find.text('At'), needsTime ? findsOneWidget : findsNothing);
      final bool needsSigning =
          options.findWorkflowToSign(initial.doer) != null;
      expect(
        find.byType(SignWorkflowNotice),
        needsSigning ? findsOneWidget : findsNothing,
      );
      final bool lacksFolderRunner = options.missingFolderRunners.containsKey(
        initial.projectId,
      );
      expect(
        find.byType(FolderRunnerNotice),
        lacksFolderRunner ? findsOneWidget : findsNothing,
      );
    }
  });
}
