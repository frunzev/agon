import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/diff_line.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/approvals/approval_dialog.dart';
import 'package:agent_orchestration/screens/approvals/approval_text.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/code_block.dart';

import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'support/approval_dialog_scene.dart';
import 'support/random_approval_requests.dart';

const String _commandNote = 'The run waits until you decide.';
const String _skillNote =
    "Approving saves it as the skill's new version. You can undo it "
    "from the skill's history.";
const Map<DiffLineChange, String> _diffMarkers = <DiffLineChange, String>{
  DiffLineChange.unchanged: '  ',
  DiffLineChange.added: '+ ',
  DiffLineChange.removed: '- ',
};

ApprovalDialog _buildDialog(Random random, ApprovalAction action) {
  final Device requester = pickOne(random, galleryDevices);
  return ApprovalDialog(
    request: buildPendingApproval(
      action: action,
      requestedBy: requester.id,
      requestedAt: galleryNow,
    ),
    runLabel: randomRunLabel(random),
    askedBy: 'Agent on ${requester.name}',
    workflows: galleryWorkflows,
    deviceNames: DeviceNames(galleryDevices),
  );
}

void _expectInsideWindow(WidgetTester tester, Finder finder, Size size) {
  final Rect area = tester.getRect(finder);
  expect(area.left, greaterThanOrEqualTo(0), reason: 'size $size');
  expect(area.right, lessThanOrEqualTo(size.width), reason: 'size $size');
}

void main() {
  testWidgets('test_build_command_dialog_property_titles_with_the_summary_'
      'and_shows_the_whole_command', (WidgetTester tester) async {
    final Random random = seededRandom(95901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunCommandAction action = randomCommandAction(random);
      final Size size = randomApprovalWindowSize(random);
      await openApprovalDialogScene(
        tester,
        size: size,
        dialog: _buildDialog(random, action),
      );

      final Finder command = find.descendant(
        of: find.byType(WrappedCodeBlock),
        matching: find.text(action.command),
      );
      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(find.text('${action.summary}?'), findsOneWidget);
      expect(command, findsOneWidget);
      _expectInsideWindow(tester, command, size);
    }
  });

  testWidgets('test_build_command_dialog_property_names_the_tool_in_plain_'
      'words', (WidgetTester tester) async {
    final Random random = seededRandom(95902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunCommandAction action = randomCommandAction(random);
      final ApprovalDialog dialog = _buildDialog(random, action);
      await openApprovalDialogScene(
        tester,
        size: randomApprovalWindowSize(random),
        dialog: dialog,
      );

      final String request = find
          .textContaining(' wants to ')
          .evaluate()
          .map((Element element) => (element.widget as Text).data)
          .single!;
      if (action.tool == commandToolName) {
        expect(request, endsWith('wants to run a command.'));
      } else {
        expect(request, endsWith('wants to use ${action.tool}.'));
      }
      expect(request.startsWith('The agent in '), dialog.runLabel != null);
    }
  });

  testWidgets('test_build_command_dialog_property_says_the_run_waits', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(95903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openApprovalDialogScene(
        tester,
        size: randomApprovalWindowSize(random),
        dialog: _buildDialog(random, randomCommandAction(random)),
      );

      expect(find.text(_commandNote), findsOneWidget);
      expect(find.byType(CodeBlock), findsNothing);
    }
  });

  testWidgets('test_build_skill_change_dialog_property_shows_the_change_'
      'summary', (WidgetTester tester) async {
    final Random random = seededRandom(95904);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ImproveSkillAction action = randomSkillChangeAction(random);
      final ApprovalDialog dialog = _buildDialog(random, action);
      await openApprovalDialogScene(
        tester,
        size: randomApprovalWindowSize(random),
        dialog: dialog,
      );

      final String title = describeApprovalTitle(action, galleryWorkflows);
      final String request = describeSkillChangeRequest(
        runLabel: dialog.runLabel,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('$title?'), findsOneWidget);
      expect(find.text(request), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
      expect(find.text(action.summary), findsOneWidget);
      expect(find.text(_skillNote), findsOneWidget);
    }
  });

  testWidgets('test_build_skill_change_dialog_property_shows_every_marked_'
      'line', (WidgetTester tester) async {
    final Random random = seededRandom(95905);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ImproveSkillAction action = randomSkillChangeAction(random);
      await openApprovalDialogScene(
        tester,
        size: randomApprovalWindowSize(random),
        dialog: _buildDialog(random, action),
      );

      final SkillChangePreview? preview = action.preview;
      if (preview == null) {
        expect(find.byType(CodeBlock), findsNothing);
        continue;
      }
      for (final DiffLine line in preview.lines) {
        final String marked = '${_diffMarkers[line.change]}${line.text}';
        expect(find.text(marked), findsOneWidget, reason: marked);
      }
    }
  });

  testWidgets('test_build_skill_change_dialog_property_a_deleted_skill_'
      'still_asks', (WidgetTester tester) async {
    final Random random = seededRandom(95906);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ImproveSkillAction action = ImproveSkillAction(
        skillId: randomSkillChangeAction(random).skillId,
        summary: 'Change ${randomText(random)}',
        preview: null,
      );
      final ApprovalDialogScene scene = await openApprovalDialogScene(
        tester,
        size: randomApprovalWindowSize(random),
        dialog: _buildDialog(random, action),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Improve a deleted skill?'), findsOneWidget);
      await tapButtonLabelled(tester, approveDecisionLabel);
      expect(scene.decisions, <ApprovalDecision?>[ApprovalDecision.approved]);
    }
  });

  testWidgets('test_build_decision_buttons_property_each_button_answers_'
      'once', (WidgetTester tester) async {
    final Random random = seededRandom(95907);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ApprovalDecision decision = pickOne(
        random,
        ApprovalDecision.values,
      );
      final ApprovalDialogScene scene = await openApprovalDialogScene(
        tester,
        size: randomApprovalWindowSize(random),
        dialog: _buildDialog(random, randomApprovalAction(random)),
      );

      await tapButtonLabelled(tester, describeDecisionLabel(decision));

      expect(scene.decisions, <ApprovalDecision?>[decision]);
      expect(
        find.widgetWithText(AppButton, approveDecisionLabel),
        findsNothing,
      );
    }
  });

  testWidgets('test_build_decision_buttons_property_deny_comes_before_'
      'approve', (WidgetTester tester) async {
    final Random random = seededRandom(95908);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = randomApprovalWindowSize(random);
      await openApprovalDialogScene(
        tester,
        size: size,
        dialog: _buildDialog(random, randomApprovalAction(random)),
      );

      final Rect deny = tester.getRect(
        find.widgetWithText(AppButton, denyDecisionLabel),
      );
      final Rect approve = tester.getRect(
        find.widgetWithText(AppButton, approveDecisionLabel),
      );
      if (LayoutSize.forWidth(size.width).isCompact) {
        expect(approve.bottom, lessThanOrEqualTo(deny.top));
      } else {
        expect(deny.right, lessThanOrEqualTo(approve.left));
      }
    }
  });

  testWidgets('test_build_decision_buttons_property_buttons_stay_inside_'
      'the_window', (WidgetTester tester) async {
    final Random random = seededRandom(95909);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = randomApprovalWindowSize(random);
      await openApprovalDialogScene(
        tester,
        size: size,
        dialog: _buildDialog(random, randomApprovalAction(random)),
      );

      for (final String label in <String>[
        denyDecisionLabel,
        approveDecisionLabel,
      ]) {
        final Finder button = find.widgetWithText(AppButton, label);
        await tester.ensureVisible(button);
        await tester.pump();
        _expectInsideWindow(tester, button, size);
        expect(tester.getRect(button).bottom, lessThanOrEqualTo(size.height));
      }
    }
  });
}
