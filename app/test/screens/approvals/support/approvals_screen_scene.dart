import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_approvals.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../../support/app_harness.dart';
import '../../../support/person_step_dependencies.dart';
import 'random_approval_requests.dart';

typedef ApprovalsScene = ({
  AppNavigation navigation,
  AppDependencies dependencies,
});

const String reviewLabel = 'Review';
const AppRoute approvalsRoute = SectionRoute(AppSection.approvals);

final ApprovalRequest deployApproval = ApprovalRequest(
  id: const ApprovalId('approval-deploy-staging'),
  runId: null,
  action: const DeployAction(target: 'staging'),
  requestedBy: GalleryDeviceIds.officeServer,
  requestedAt: galleryToday(9, 30),
  decision: null,
);

final ApprovalRequest deleteApproval = ApprovalRequest(
  id: const ApprovalId('approval-delete-old-branch'),
  runId: GalleryRunIds.release41,
  action: const DeleteBranchOrFilesAction(
    repository: 'github.com/acme/app',
    what: 'old-branch',
  ),
  requestedBy: GalleryDeviceIds.macStudio,
  requestedAt: galleryYesterday(18, 5),
  decision: null,
);

final List<ApprovalRequest> approvalPool = <ApprovalRequest>[
  ...galleryApprovals,
  galleryRunCommandApproval,
  galleryImproveSkillApproval,
  galleryDeniedPushApproval,
  deployApproval,
  deleteApproval,
];

List<ApprovalRequest> pickApprovals(Random random) {
  final List<ApprovalRequest> picked = <ApprovalRequest>[];
  for (final ApprovalRequest request in approvalPool) {
    if (random.nextBool()) {
      picked.add(request);
    }
  }
  return picked;
}

List<ApprovalRequest> listPending(List<ApprovalRequest> approvals) {
  return <ApprovalRequest>[
    for (final ApprovalRequest request in approvals)
      if (request.isPending) request,
  ];
}

AppDependencies buildQuestionDependencies() {
  return buildDependenciesWithQuestion(notes: const <RunNote>[]);
}

AppDependencies replaceApprovals(
  AppDependencies base,
  List<ApprovalRequest> approvals,
) {
  return replaceRepositories(
    base,
    approvalRepository: FakeApprovalRepository(
      approvals: approvals,
      clock: base.clock,
      currentDeviceId: GalleryDeviceIds.airLaptop,
    ),
  );
}

Future<ApprovalsScene> pumpApprovalsScreen(
  WidgetTester tester, {
  required Random random,
  required AppDependencies dependencies,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: randomApprovalWindowSize(random),
    route: approvalsRoute,
    dependencies: dependencies,
  );
  return (navigation: navigation, dependencies: dependencies);
}

Future<void> tapRowTitled(WidgetTester tester, String title) async {
  final Finder row = find.text(title);
  await tester.ensureVisible(row);
  await tester.tap(row);
  await pumpFrames(tester);
}

void expectNoProblem(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

double findTopOf(WidgetTester tester, String text) {
  return tester.getTopLeft(find.text(text).first).dy;
}
