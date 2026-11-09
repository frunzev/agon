import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';
import 'package:agent_orchestration/screens/settings/app_server_section.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';

import '../../bridge/support/node_json_primitives.dart';
import '../../support/random_inputs.dart';
import '../../support/runner_pages.dart';
import '../../support/server_group_repositories.dart';
import 'runner_settings_screen_checks.dart';

const DeviceId thisServerDeviceId = thisRunnerDeviceId;
const List<DeviceId> _otherServerDeviceIds = <DeviceId>[
  GalleryDeviceIds.mainMac,
  GalleryDeviceIds.oldMacbook,
  GalleryDeviceIds.macStudio,
  GalleryDeviceIds.officeServer,
];
const List<String> _serverAddresses = <String>[
  'https://relay.acme.dev',
  'https://user:hunter2@relay.acme.dev:8443/path',
  'http://192.168.1.20:7070',
  'peer://4f7a2c19e8b3d6a05c1f9e27b4d8a3c6f0e5b9d2a7c4e1f8b3d6a09c5e2f7b14',
  'relay.acme.dev',
];

AppServerMember _randomMember(Random random, DeviceId deviceId) {
  return AppServerMember(
    deviceId: deviceId,
    standing: pickOne(random, ServerStanding.values),
    copy: null,
  );
}

AppServerGroup randomAppServerGroup(Random random) {
  final List<AppServerMember> members = <AppServerMember>[
    for (final DeviceId deviceId in _otherServerDeviceIds)
      if (random.nextBool()) _randomMember(random, deviceId),
    if (random.nextInt(4) == 0)
      _randomMember(random, DeviceId(randomDeviceIdText(random))),
  ];
  final ThisDeviceStanding standing = members.isEmpty
      ? ThisDeviceStanding.none
      : pickOne(random, ThisDeviceStanding.values);
  if (standing == ThisDeviceStanding.active) {
    members.add(_buildThisMember(ServerStanding.active));
  }
  if (standing == ThisDeviceStanding.backup) {
    members.add(_buildThisMember(ServerStanding.backup));
  }

  return AppServerGroup(
    members: members,
    thisDeviceStanding: standing,
    canKeepBackup: members.isNotEmpty && random.nextBool(),
  );
}

AppServerMember _buildThisMember(ServerStanding standing) {
  return AppServerMember(
    deviceId: thisServerDeviceId,
    standing: standing,
    copy: null,
  );
}

AppServerStatus randomAppServerStatus(Random random) {
  return AppServerStatus(
    address: pickOne(random, _serverAddresses),
    state: pickOne(random, AppServerState.values),
    lastConnectedAt: random.nextBool() ? galleryNow : null,
    retryInterval: Duration(seconds: 1 + random.nextInt(60)),
  );
}

FakeWorkspaceRepository buildServerWorkspaces({
  required AppServerGroup group,
  required AppServerStatus status,
}) {
  return FakeWorkspaceRepository(
    workspaces: galleryWorkspaces,
    currentWorkspaceId: GalleryWorkspaceIds.acme,
    appServerStatus: status,
    appServerGroup: group,
    currentDeviceId: thisServerDeviceId,
    clock: FixedClock(galleryNow),
  );
}

AppServerSection buildAppServerSection(WorkspaceRepository workspaces) {
  return AppServerSection(
    workspaceRepository: workspaces,
    deviceRepository: buildRunnerDevices(peerAddressProblem: null),
  );
}

Future<double> pumpAppServerSection(
  WidgetTester tester,
  Random random,
  WorkspaceRepository workspaces,
) {
  return pumpAtRandomWidth(tester, random, buildAppServerSection(workspaces));
}

Future<FakeWorkspaceRepository> pumpRandomAppServerSection(
  WidgetTester tester,
  Random random,
) async {
  final FakeWorkspaceRepository workspaces = buildServerWorkspaces(
    group: randomAppServerGroup(random),
    status: randomAppServerStatus(random),
  );
  await pumpAppServerSection(tester, random, workspaces);
  return workspaces;
}

List<String> readAppServerTexts(WidgetTester tester) {
  return readShownTexts(tester, find.byType(AppServerSection));
}

Widget wrapInKeyedSection(Key key, WorkspaceRepository workspaces) {
  return KeyedSubtree(key: key, child: buildAppServerSection(workspaces));
}

SwitchToggle readServerBackupToggle(WidgetTester tester) {
  return tester.widget<SwitchToggle>(findServerBackupToggle());
}

Future<void> tapServerBackupToggle(WidgetTester tester, Finder toggle) async {
  await tester.tap(toggle);
  await tester.pump();
  await tester.pump();
}
