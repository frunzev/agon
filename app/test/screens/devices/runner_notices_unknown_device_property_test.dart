import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/runner_repository.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/presentation/runner_text.dart';
import 'package:agent_orchestration/screens/devices/runner_notices.dart';

import '../../support/random_inputs.dart';
import '../../support/unknown_device_names.dart';
import '../support/random_page_windows.dart';
import 'support/random_devices_page.dart';

const String _serverDownTitle = "Can't reach the app server";
const String _serverAddress = 'relay.example';
const Duration _retryInterval = Duration(seconds: 5);

final class _ListedRunnerRepository extends ChangeNotifier
    implements RunnerRepository {
  _ListedRunnerRepository(this.runners);

  final List<Runner> runners;

  @override
  List<Runner> listRunners() => runners;

  @override
  Runner findRunner(DeviceId deviceId) {
    return runners.firstWhere((Runner runner) => runner.deviceId == deviceId);
  }

  @override
  Future<Runner> pauseRunner(DeviceId deviceId) {
    throw UnsupportedError('Runner notices never pause runners');
  }

  @override
  Future<Runner> resumeRunner(DeviceId deviceId) {
    throw UnsupportedError('Runner notices never resume runners');
  }

  @override
  List<PlaceOffer>? findThisDeviceOffers() => null;

  @override
  String? findThisRunnerProblem() => null;

  @override
  Future<void> chooseAgentOffers(List<AgentPlace> offers) {
    throw UnsupportedError('Runner notices never choose offers');
  }
}

Runner _waitingRunnerOn(Random random, DeviceId deviceId) {
  final Runner template = randomRunnerOn(random, deviceId);
  return Runner(
    deviceId: deviceId,
    labels: template.labels,
    slotsTotal: template.slotsTotal,
    slotsBusy: template.slotsBusy,
    link: RunnerLink.relay,
    online: true,
    acceptingNewRuns: template.acceptingNewRuns,
    offers: template.offers,
    allowedHosts: template.allowedHosts,
  );
}

RunnerNotices _buildNotices({
  required List<Device> devices,
  required List<Runner> runners,
}) {
  final DeviceId thisDeviceId = devices.first.id;
  return RunnerNotices(
    runnerRepository: _ListedRunnerRepository(runners),
    deviceRepository: FakeDeviceRepository(
      devices: devices,
      currentDeviceId: thisDeviceId,
      peerAddressProblem: null,
      gitlessFolderPaths: const <String>{},
    ),
    workspaceRepository: FakeWorkspaceRepository(
      workspaces: galleryWorkspaces,
      currentWorkspaceId: devicesPageWorkspaceId,
      appServerStatus: const AppServerStatus(
        address: _serverAddress,
        state: AppServerState.unreachable,
        lastConnectedAt: null,
        retryInterval: _retryInterval,
      ),
      appServerGroup: AppServerGroup(
        members: const <AppServerMember>[],
        thisDeviceStanding: ThisDeviceStanding.none,
        canKeepBackup: false,
      ),
      currentDeviceId: thisDeviceId,
      clock: FixedClock(galleryNow),
    ),
  );
}

Future<void> _pumpNotices(
  WidgetTester tester,
  Random random,
  RunnerNotices notices,
) async {
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: Builder(
      builder: (BuildContext context) =>
          Column(children: notices.buildNotices(context)),
    ),
  );
}

void main() {
  testWidgets('test_build_server_down_banner_property_an_unknown_runner_'
      'device_never_crashes', (WidgetTester tester) async {
    final Random random = seededRandom(5311901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final RunnerNotices notices = _buildNotices(
        devices: randomPageDevices(random),
        runners: <Runner>[_waitingRunnerOn(random, unknown.deviceId)],
      );

      await _pumpNotices(tester, random, notices);

      expect(tester.takeException(), isNull);
      expect(find.text(_serverDownTitle), findsOneWidget);
    }
  });

  testWidgets('test_build_server_down_banner_property_an_unknown_runner_'
      'reads_as_its_short_identifier', (WidgetTester tester) async {
    final Random random = seededRandom(5311902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final RunnerNotices notices = _buildNotices(
        devices: randomPageDevices(random),
        runners: <Runner>[_waitingRunnerOn(random, unknown.deviceId)],
      );

      await _pumpNotices(tester, random, notices);

      final String notice = describeServerDownNotice(<String>[
        shortenIdentifier(unknown.deviceId.value),
      ]);
      expect(findBannerText(_serverDownTitle, notice), findsOneWidget);
    }
  });

  testWidgets('test_build_server_down_banner_property_known_and_unknown_'
      'runners_are_all_listed', (WidgetTester tester) async {
    final Random random = seededRandom(5311903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Device> devices = randomPageDevices(random);
      final Device known = devices.first;
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final RunnerNotices notices = _buildNotices(
        devices: devices,
        runners: <Runner>[
          _waitingRunnerOn(random, known.id),
          _waitingRunnerOn(random, unknown.deviceId),
        ],
      );

      await _pumpNotices(tester, random, notices);

      final String notice = describeServerDownNotice(<String>[
        known.name,
        unknown.shortName,
      ]);
      expect(tester.takeException(), isNull);
      expect(findBannerText(_serverDownTitle, notice), findsOneWidget);
    }
  });
}
