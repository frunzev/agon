import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/approvals/approval_dialog.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/code_block.dart';

import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'support/approval_dialog_scene.dart';
import 'support/random_approval_requests.dart';

final DeviceNames _galleryDeviceNames = DeviceNames(galleryDevices);

ApprovalDialog _buildRandomDialog(Random random, ApprovalAction action) {
  final Device requester = pickOne(random, galleryDevices);
  return ApprovalDialog(
    request: buildPendingApproval(
      action: action,
      requestedBy: requester.id,
      requestedAt: galleryNow,
    ),
    runLabel: randomRunLabel(random),
    askedBy: 'Agent on ${requester.name}, ${randomWordPhrase(random)}#',
    workflows: galleryWorkflows,
    deviceNames: _galleryDeviceNames,
  );
}

void main() {
  testWidgets('test_approval_dialog_build_property_every_kind_shows_title_'
      'asker_and_both_decisions', (WidgetTester tester) async {
    final Random random = seededRandom(95801);

    for (int i = 0; i < widgetPropertyIterations * 3; i += 1) {
      final ApprovalAction action = randomApprovalAction(random);
      final ApprovalDialog dialog = _buildRandomDialog(random, action);
      final Size size = randomApprovalWindowSize(random);
      final ApprovalDialogScene scene = await openApprovalDialogScene(
        tester,
        size: size,
        dialog: dialog,
      );

      final String title = describeApprovalTitle(action, galleryWorkflows);
      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(find.text('$title?'), findsOneWidget);
      expect(find.text('Asked by'), findsOneWidget);
      expect(find.text(dialog.askedBy), findsOneWidget);
      expect(find.widgetWithText(AppButton, approveDecisionLabel), findsOne);
      expect(find.widgetWithText(AppButton, denyDecisionLabel), findsOne);
      await tapButtonLabelled(tester, denyDecisionLabel);
      expect(scene.decisions, <ApprovalDecision?>[ApprovalDecision.denied]);
    }
  });

  testWidgets('test_approval_dialog_build_property_push_shows_every_'
      'commit_branch_and_repository', (WidgetTester tester) async {
    final Random random = seededRandom(95802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PushCommitsAction action = randomPushAction(random);
      final ApprovalDialog dialog = _buildRandomDialog(random, action);
      await openApprovalDialogScene(
        tester,
        size: randomApprovalWindowSize(random),
        dialog: dialog,
      );

      final String repository = describeApprovalRepository(
        action.repository,
        _galleryDeviceNames,
      );
      final String request = describePushRequest(
        runLabel: dialog.runLabel,
        commitCount: action.commits.length,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(request), findsOneWidget);
      expect(find.text(repository), findsOneWidget);
      expect(find.text(action.branch), findsWidgets);
      for (final String commit in action.commits) {
        expect(find.text(commit), findsOneWidget);
      }
      expect(find.textContaining('local:'), findsNothing);
    }
  });

  testWidgets('test_approval_dialog_build_property_other_actions_ask_in_'
      'plain_words_without_code', (WidgetTester tester) async {
    final Random random = seededRandom(95803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalAction action = randomPlainApprovalAction(random);
      final ApprovalDialog dialog = _buildRandomDialog(random, action);
      await openApprovalDialogScene(
        tester,
        size: randomApprovalWindowSize(random),
        dialog: dialog,
      );

      final String request = describeActionRequest(runLabel: dialog.runLabel);
      expect(tester.takeException(), isNull);
      expect(find.text(request), findsOneWidget);
      expect(find.byType(CodeBlock), findsNothing);
      expect(find.byType(WrappedCodeBlock), findsNothing);
      expect(find.byType(DialogNote), findsNothing);
    }
  });

  test('test_describe_decision_label_property_each_decision_has_its_own_'
      'label', () {
    final Set<String> labels = <String>{
      for (final ApprovalDecision decision in ApprovalDecision.values)
        describeDecisionLabel(decision),
    };

    expect(labels, hasLength(ApprovalDecision.values.length));
    expect(describeDecisionLabel(ApprovalDecision.approved), 'Approve');
    expect(describeDecisionLabel(ApprovalDecision.denied), 'Deny');
  });

  test('test_describe_decision_label_property_one_plain_capitalized_word', () {
    final RegExp plainWord = RegExp(r'^[A-Z][a-z]+$');

    for (final ApprovalDecision decision in ApprovalDecision.values) {
      expect(plainWord.hasMatch(describeDecisionLabel(decision)), isTrue);
    }
  });

  testWidgets('test_describe_decision_label_property_the_labelled_button_'
      'gives_that_decision', (WidgetTester tester) async {
    final Random random = seededRandom(95804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final ApprovalAction action = randomApprovalAction(random);
      final ApprovalDialogScene scene = await openApprovalDialogScene(
        tester,
        size: randomApprovalWindowSize(random),
        dialog: _buildRandomDialog(random, action),
      );

      await tapButtonLabelled(tester, describeDecisionLabel(decision));

      expect(scene.decisions, <ApprovalDecision?>[decision]);
      expect(find.byType(ApprovalDialog), findsNothing);
    }
  });
}
