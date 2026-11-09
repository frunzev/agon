import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_pairing.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/devices/workspace_devices_section.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';
import 'package:agent_orchestration/widgets/page_section.dart';

import '../../../bridge/support/hostile_texts.dart';
import '../../../bridge/support/random_moments.dart';
import '../../../support/app_harness.dart';
import '../../../support/random_device_records.dart';
import '../../../support/random_inputs.dart';
import '../../../support/sample_runners.dart';
import '../../../support/widget_harness.dart';
import '../../support/refused_action_properties.dart';

const WorkspaceId devicesPageWorkspaceId = GalleryWorkspaceIds.acme;
const String workspaceSectionTitle = 'In acme';
const String allDevicesSectionTitle = 'All your devices';
const String _serverAddress = 'relay.acme.dev';
const int _longestRetrySeconds = 120;
const int _mostChangesBehind = 50;

Device buildLiveMember(Device record) {
  final Set<WorkspaceId> workspaces = <WorkspaceId>{
    devicesPageWorkspaceId,
    ...record.workspaces,
  };
  return Device(
    id: record.id,
    name: record.name,
    role: record.role,
    kind: record.kind,
    keyKind: record.keyKind,
    signingPublicKey: record.signingPublicKey,
    sealingPublicKey: record.sealingPublicKey,
    workspaces: workspaces.toList(),
    pairedAt: record.pairedAt,
    approvedBy: null,
    lastSeen: record.lastSeen,
    revoked: false,
  );
}

List<Device> randomPageDevices(Random random) {
  final Device thisDevice = buildLiveMember(
    randomDeviceRecord(random, approvedBy: null),
  );
  return <Device>[thisDevice, ...randomDeviceRecords(random)];
}

Runner randomRunnerOn(Random random, DeviceId deviceId) {
  final Runner template = randomRunner(random);
  return Runner(
    deviceId: deviceId,
    labels: template.labels,
    slotsTotal: template.slotsTotal,
    slotsBusy: template.slotsBusy,
    link: template.link,
    online: template.online,
    acceptingNewRuns: template.acceptingNewRuns,
    offers: template.offers,
    allowedHosts: template.allowedHosts,
  );
}

List<Runner> _randomPageRunners(Random random, List<Device> devices) {
  return <Runner>[
    for (final Device device in devices)
      if (!device.revoked && random.nextBool())
        randomRunnerOn(random, device.id),
  ];
}

AppServerStatus randomServerStatus(Random random) {
  return AppServerStatus(
    address: _serverAddress,
    state: pickOne(random, AppServerState.values),
    lastConnectedAt: random.nextBool() ? null : randomPreciseMoment(random),
    retryInterval: Duration(seconds: 1 + random.nextInt(_longestRetrySeconds)),
  );
}

BackupCopy? _randomBackupCopy(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return BackupCopy(
    changesBehind: random.nextInt(_mostChangesBehind),
    verifiedAt: randomPreciseMoment(random),
  );
}

AppServerGroup _randomServerGroup(Random random, List<Device> devices) {
  return AppServerGroup(
    members: <AppServerMember>[
      for (final Device device in devices)
        if (random.nextInt(3) == 0)
          AppServerMember(
            deviceId: device.id,
            standing: pickOne(random, ServerStanding.values),
            copy: _randomBackupCopy(random),
          ),
    ],
    thisDeviceStanding: ThisDeviceStanding.none,
    canKeepBackup: false,
  );
}

List<PlaceOffer>? _randomOffers(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return <PlaceOffer>[
    for (final AgentPlace place in AgentPlace.values)
      if (random.nextBool())
        PlaceOffer(place: place, problem: randomOptionalHostileText(random)),
  ];
}

String? _randomRunnerProblem(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return 'problem ${randomHostileText(random)}';
}

AppDependencies buildRandomDevicesDependencies(Random random) {
  final AppDependencies gallery = buildGalleryDependencies();
  final List<Device> devices = randomPageDevices(random);
  final DeviceId thisDeviceId = devices.first.id;
  final FakeDeviceRepository deviceRepository = FakeDeviceRepository(
    devices: devices,
    currentDeviceId: thisDeviceId,
    peerAddressProblem: null,
    gitlessFolderPaths: const <String>{},
  );
  final FakeWorkspaceRepository workspaceRepository = FakeWorkspaceRepository(
    workspaces: galleryWorkspaces,
    currentWorkspaceId: devicesPageWorkspaceId,
    appServerStatus: randomServerStatus(random),
    appServerGroup: _randomServerGroup(random, devices),
    currentDeviceId: thisDeviceId,
    clock: gallery.clock,
  );

  return replaceRepositories(
    gallery,
    deviceRepository: deviceRepository,
    workspaceRepository: workspaceRepository,
    runnerRepository: FakeRunnerRepository(
      runners: _randomPageRunners(random, devices),
      deviceRepository: deviceRepository,
      workspaceRepository: workspaceRepository,
      thisDeviceOffers: _randomOffers(random),
      thisRunnerProblem: _randomRunnerProblem(random),
    ),
    pairingRepository: FakePairingRepository(
      session: null,
      request: null,
      clock: gallery.clock,
      deviceRepository: deviceRepository,
      joinOutcome: galleryPairingOutcome,
      startedPairingRendezvousProblem: null,
    ),
  );
}

Future<AppNavigation> _pumpDevicesPageAt(
  WidgetTester tester, {
  required Size size,
  required AppDependencies dependencies,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  return pumpApp(
    tester,
    size: size,
    route: const SectionRoute(AppSection.devices),
    dependencies: dependencies,
  );
}

Future<AppNavigation> pumpDevicesPage(
  WidgetTester tester, {
  required Random random,
  required AppDependencies dependencies,
}) {
  return _pumpDevicesPageAt(
    tester,
    size: randomActionWindowSize(random),
    dependencies: dependencies,
  );
}

Future<AppNavigation> pumpCompactDevicesPage(
  WidgetTester tester, {
  required Random random,
  required AppDependencies dependencies,
}) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: LayoutSize.mediumMinimumWidth - 1,
  );
  return _pumpDevicesPageAt(
    tester,
    size: Size(width, desktopHeight),
    dependencies: dependencies,
  );
}

List<Device> listLiveMembers(AppDependencies dependencies) {
  final List<Device> devices = dependencies.deviceRepository.listDevices();
  return listWorkspaceMembers(
    devices: devices,
    workspaceId: devicesPageWorkspaceId,
  );
}

Finder findDevicesSection(String title) {
  return find.byWidgetPredicate(
    (Widget widget) => widget is PageSection && widget.title == title,
  );
}

Finder findSectionRow(String sectionTitle, DeviceId deviceId) {
  return find.descendant(
    of: findDevicesSection(sectionTitle),
    matching: find.byKey(ValueKey<DeviceId>(deviceId)),
  );
}

Finder findTextInRow(Finder row, String text) {
  return find.descendant(of: row, matching: find.text(text));
}

Future<AppDependencies> pumpRandomDevicesPage(
  WidgetTester tester,
  Random random,
) async {
  final AppDependencies dependencies = buildRandomDevicesDependencies(random);
  await pumpDevicesPage(tester, random: random, dependencies: dependencies);
  expect(tester.takeException(), isNull);
  return dependencies;
}

bool isAppServerDown(AppDependencies dependencies) {
  final AppServerStatus status = dependencies.workspaceRepository
      .findAppServerStatus();
  return status.state == AppServerState.unreachable;
}

Finder findBannerText(String bannerTitle, String text) {
  return find.descendant(
    of: find.widgetWithText(NoticeBanner, bannerTitle),
    matching: find.text(text),
  );
}
