import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

import 'random_approval_requests.dart';

final class ApprovalDialogScene {
  ApprovalDialogScene({required this.dialog});

  final Widget dialog;
  final List<ApprovalDecision?> decisions = <ApprovalDecision?>[];

  Future<void> open(BuildContext context) async {
    final ApprovalDecision? decision = await showAppDialog<ApprovalDecision>(
      context: context,
      builder: _buildDialog,
    );
    decisions.add(decision);
  }

  Widget _buildDialog(BuildContext _) => dialog;
}

Future<ApprovalDialogScene> openApprovalDialogScene(
  WidgetTester tester, {
  required Size size,
  required Widget dialog,
}) async {
  final ApprovalDialogScene scene = ApprovalDialogScene(dialog: dialog);
  await pumpApprovalOpener(tester, size: size, open: scene.open);
  await tapOpenApproval(tester);
  return scene;
}
