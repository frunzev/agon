import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/screens/approvals/approval_review.dart';

import '../../support/planned_refusal.dart';
import '../../support/refusing_work_repositories.dart';
import 'random_approval_requests.dart';

final class ReviewScene {
  ReviewScene({required this.request, required this.runLabel})
    : refusal = PlannedRefusal() {
    final AppDependencies gallery = buildGalleryDependencies();
    storedApprovals = FakeApprovalRepository(
      approvals: <ApprovalRequest>[request],
      clock: gallery.clock,
      currentDeviceId: GalleryDeviceIds.airLaptop,
    );
    review = ApprovalReview(
      approvalRepository: RefusingApprovalRepository(
        stored: storedApprovals,
        refusal: refusal,
      ),
      workflowRepository: gallery.workflowRepository,
      deviceRepository: gallery.deviceRepository,
      clock: gallery.clock,
    );
  }

  final ApprovalRequest request;
  final String? runLabel;
  final PlannedRefusal refusal;
  late final FakeApprovalRepository storedApprovals;
  late final ApprovalReview review;

  Future<void> open(BuildContext context) {
    return review.review(
      context: context,
      request: request,
      runLabel: runLabel,
    );
  }

  ApprovalRequest readStoredRequest() =>
      storedApprovals.listApprovals().single;
}

Future<ReviewScene> pumpReview(
  WidgetTester tester,
  Random random, {
  required Device requester,
  required DateTime requestedAt,
}) async {
  final ReviewScene scene = ReviewScene(
    request: buildPendingApproval(
      action: randomApprovalAction(random),
      requestedBy: requester.id,
      requestedAt: requestedAt,
    ),
    runLabel: randomRunLabel(random),
  );
  await pumpApprovalOpener(
    tester,
    size: randomApprovalWindowSize(random),
    open: scene.open,
  );
  return scene;
}

Future<ReviewScene> openReview(
  WidgetTester tester,
  Random random, {
  required Device requester,
  required DateTime requestedAt,
}) async {
  final ReviewScene scene = await pumpReview(
    tester,
    random,
    requester: requester,
    requestedAt: requestedAt,
  );
  await tapOpenApproval(tester);
  return scene;
}
