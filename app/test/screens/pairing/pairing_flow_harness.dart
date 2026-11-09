import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../data/node_backed/support/pairing_repository_harness.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'scripted_pairing_repository.dart';

const SectionRoute devicesRoute = SectionRoute(AppSection.devices);
const int _mostWorkspaces = 6;
const int _fingerprintWordCount = 4;
const List<String> _workspaceWords = <String>['acme', 'lab', 'home', 'ops'];
const List<String> _deviceWords = <String>['mac-mini', 'pixel', 'box'];
const List<String> _fingerprintWords = <String>[
  'maple',
  'orbit',
  'amber',
  'fountain',
  'blossom',
];

bool isButtonEnabled(WidgetTester tester, String label) {
  final AppButton button = tester.widget<AppButton>(
    find.widgetWithText(AppButton, label),
  );
  return button.onPressed != null;
}

typedef PairingPage = ({
  AppNavigation navigation,
  ScriptedPairingRepository pairing,
  AppDependencies dependencies,
});

PairingSession buildLiveSession({required String? problem}) {
  return PairingSession(
    code: galleryPairingSession.code,
    createdAt: galleryNow,
    expiresAt: galleryNow.add(pairingLifetime),
    rendezvousProblem: problem,
  );
}

Size randomPairingWindow(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  return Size(width, pickOne(random, <double>[phoneHeight, desktopHeight]));
}

AppDependencies _shareClock(AppDependencies base, Clock clock) {
  return AppDependencies(
    clock: clock,
    taskRepository: base.taskRepository,
    jobRepository: base.jobRepository,
    chatRepository: base.chatRepository,
    approvalRepository: base.approvalRepository,
    personStepRepository: base.personStepRepository,
    projectRepository: base.projectRepository,
    workspaceRepository: base.workspaceRepository,
    workflowRepository: base.workflowRepository,
    skillRepository: base.skillRepository,
    ruleRepository: base.ruleRepository,
    runnerRepository: base.runnerRepository,
    agentLoginRepository: base.agentLoginRepository,
    deviceRepository: base.deviceRepository,
    pairingRepository: base.pairingRepository,
    auditRepository: base.auditRepository,
    fileRepository: base.fileRepository,
    itemDraftRepository: base.itemDraftRepository,
    qrCodeScanner: base.qrCodeScanner,
    folderPicker: base.folderPicker,
    runnerPresence: base.runnerPresence,
  );
}

Workspace _buildWorkspace(int index, String word) {
  return Workspace(
    id: WorkspaceId('workspace-$index'),
    name: '$word-$index',
    appServerAddress: galleryWorkspaces.first.appServerAddress,
    protectedFiles: const <String>[],
    approvalPolicy: ApprovalPolicy.neverAsk,
  );
}

List<Workspace> randomWorkspaces(Random random) {
  final int count = 1 + random.nextInt(_mostWorkspaces);
  return <Workspace>[
    for (int index = 0; index < count; index += 1)
      _buildWorkspace(index, pickOne(random, _workspaceWords)),
  ];
}

PairingRequest randomPairingRequest(Random random) {
  return PairingRequest(
    deviceName: '${pickOne(random, _deviceWords)}-${random.nextInt(100)}',
    role: pickOne(random, DeviceRole.values),
    keyKind: pickOne(random, HardwareKeyKind.values),
    codeUsed: galleryPairingSession.code,
    fingerprintWords: <String>[
      for (int index = 0; index < _fingerprintWordCount; index += 1)
        pickOne(random, _fingerprintWords),
    ],
    link: pickOne(random, <RunnerLink?>[...RunnerLink.values, null]),
  );
}

Future<PairingPage> openPairingPage(
  WidgetTester tester, {
  required Size size,
  required AppRoute route,
  required PairingSession? session,
  required PairingRequest? request,
}) {
  return _openPage(
    tester,
    size: size,
    route: route,
    session: session,
    request: request,
    workspaces: galleryWorkspaces,
  );
}

Future<PairingPage> openApprovalPage(
  WidgetTester tester, {
  required Size size,
  required PairingRequest? request,
  required List<Workspace> workspaces,
}) {
  return _openPage(
    tester,
    size: size,
    route: const PairingApprovalRoute(),
    session: buildLiveSession(problem: null),
    request: request,
    workspaces: workspaces,
  );
}

Future<PairingPage> _openPage(
  WidgetTester tester, {
  required Size size,
  required AppRoute route,
  required PairingSession? session,
  required PairingRequest? request,
  required List<Workspace> workspaces,
}) async {
  final AppDependencies gallery = buildGalleryDependencies();
  final MovableClock clock = MovableClock(galleryNow);
  final ScriptedPairingRepository pairing = ScriptedPairingRepository(
    clock: clock,
    session: session,
    request: request,
    approvedDevice: gallery.deviceRepository.currentDevice(),
  );
  final FakeWorkspaceRepository workspaceRepository = FakeWorkspaceRepository(
    workspaces: workspaces,
    currentWorkspaceId: workspaces.first.id,
    appServerStatus: galleryAppServerStatus,
    appServerGroup: galleryAppServerGroup,
    currentDeviceId: GalleryDeviceIds.airLaptop,
    clock: clock,
  );
  final AppDependencies dependencies = _shareClock(
    replaceRepositories(
      gallery,
      pairingRepository: pairing,
      workspaceRepository: workspaceRepository,
    ),
    clock,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: size,
    route: devicesRoute,
    dependencies: dependencies,
  );
  navigation.openRoute(route);
  await pumpFrames(tester);
  return (
    navigation: navigation,
    pairing: pairing,
    dependencies: dependencies,
  );
}
