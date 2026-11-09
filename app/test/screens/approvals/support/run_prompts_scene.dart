import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/approval_repository.dart';
import 'package:agent_orchestration/screens/approvals/run_approval_prompts.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';

import '../../../support/app_harness.dart';
import '../../../support/widget_harness.dart';
import 'random_approval_requests.dart';

const String promptedPageText = 'The run page';
const RunId promptedRunId = GalleryRunIds.release42;
const RunId otherRunId = GalleryRunIds.release41;
const Offset barrierPoint = Offset(4, 4);

ApprovalRequest buildRunApproval({
  required RunId runId,
  required int number,
  required Random random,
}) {
  return ApprovalRequest(
    id: ApprovalId('approval-for-${runId.value}-$number'),
    runId: runId,
    action: randomApprovalAction(random),
    requestedBy: GalleryDeviceIds.macStudio,
    requestedAt: galleryToday(14, 9),
    decision: null,
  );
}

RunApprovalPrompts buildRunPrompts({
  required AppDependencies dependencies,
  required ApprovalRepository approvalRepository,
}) {
  return RunApprovalPrompts(
    runId: promptedRunId,
    taskRepository: dependencies.taskRepository,
    workflowRepository: dependencies.workflowRepository,
    approvalRepository: approvalRepository,
    deviceRepository: dependencies.deviceRepository,
    clock: dependencies.clock,
    child: const Text(promptedPageText),
  );
}

Future<void> pumpRunPrompts(
  WidgetTester tester, {
  required Random random,
  required ApprovalRepository approvalRepository,
}) async {
  final Size size = randomApprovalWindowSize(random);
  useViewSize(tester, size);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    wrapInApp(
      buildRunPrompts(
        dependencies: buildGalleryDependencies(),
        approvalRepository: approvalRepository,
      ),
      platform: platformMeantByWidth(size.width),
    ),
  );
  await pumpFrames(tester);
}

int countOpenDialogs() {
  return find.byType(AppDialog).evaluate().length;
}

Future<void> dismissDialog(WidgetTester tester) async {
  await tester.tapAt(barrierPoint);
  await pumpFrames(tester);
}
