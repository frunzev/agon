import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import '../../support/runner_memberships.dart';
import '../../support/sample_runners.dart';
import 'support/notification_counter.dart';
import 'support/runner_inputs.dart';

const String _typePrefix = 'test_fake_runner_repository';
const DeviceId _personalOnlyDeviceId = DeviceId('personal-only-device');

Runner _runnerOn(Random random, DeviceId deviceId) {
  final Runner shape = randomRunner(random);
  return Runner(
    deviceId: deviceId,
    labels: shape.labels,
    slotsTotal: shape.slotsTotal,
    slotsBusy: shape.slotsBusy,
    link: shape.link,
    online: shape.online,
    acceptingNewRuns: shape.acceptingNewRuns,
    offers: shape.offers,
    allowedHosts: shape.allowedHosts,
  );
}

FakeRunnerRepository _buildRunners({
  required List<Runner> runners,
  required FakeDeviceRepository devices,
  required FakeWorkspaceRepository workspaces,
}) {
  return FakeRunnerRepository(
    runners: runners,
    deviceRepository: devices,
    workspaceRepository: workspaces,
    thisDeviceOffers: null,
    thisRunnerProblem: null,
  );
}

FakeDeviceRepository _devicesWithPersonalOnlyRunner() {
  return buildMembershipDevices(<Device>[
    buildMemberDevice(_personalOnlyDeviceId, const <WorkspaceId>[
      GalleryWorkspaceIds.personal,
    ]),
  ]);
}

void main() {
  test('${_typePrefix}_constructor_property_keeps_hidden_runners', () async {
    final Random random = seededRandom(88501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner hidden = _runnerOn(random, _personalOnlyDeviceId);
      final FakeWorkspaceRepository workspaces = buildMembershipWorkspaces(
        GalleryWorkspaceIds.acme,
      );
      final FakeRunnerRepository repository = _buildRunners(
        runners: <Runner>[hidden],
        devices: _devicesWithPersonalOnlyRunner(),
        workspaces: workspaces,
      );

      final List<Runner> before = repository.listRunners();
      await workspaces.switchWorkspace(GalleryWorkspaceIds.personal);

      expect(before, isEmpty);
      expect(repository.listRunners(), <Runner>[hidden]);
    }
  });

  test('${_typePrefix}_constructor_property_ignores_caller_changes', () {
    final Random random = seededRandom(88502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomDistinctRunners(random);
      final FakeRunnerRepository repository = buildMemberRunnerRepository(
        runners: runners,
        offers: null,
        problem: null,
      );
      final List<Runner> listed = List<Runner>.of(repository.listRunners());

      runners.add(_runnerOn(random, const DeviceId('added-later')));

      expect(repository.listRunners(), listed);
    }
  });

  test('${_typePrefix}_constructor_property_keeps_offers_and_problem', () {
    final Random random = seededRandom(88503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<PlaceOffer> offers = randomPlaceOffers(random);
      final String? problem = randomOfferProblem(random);

      final FakeRunnerRepository repository = buildMemberRunnerRepository(
        runners: randomDistinctRunners(random),
        offers: offers,
        problem: problem,
      );

      expect(repository.findThisDeviceOffers(), offers);
      expect(repository.findThisRunnerProblem(), problem);
    }
  });

  test('${_typePrefix}_dispose_property_a_later_switch_is_harmless', () async {
    final Random random = seededRandom(88504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkspaceRepository workspaces = buildMembershipWorkspaces(
        GalleryWorkspaceIds.acme,
      );
      final FakeRunnerRepository repository = _buildRunners(
        runners: randomDistinctRunners(random),
        devices: _devicesWithPersonalOnlyRunner(),
        workspaces: workspaces,
      );

      repository.dispose();
      await workspaces.switchWorkspace(GalleryWorkspaceIds.personal);

      expect(workspaces.currentWorkspace().id, GalleryWorkspaceIds.personal);
    }
  });

  test('${_typePrefix}_dispose_property_a_later_member_is_harmless', () async {
    final Random random = seededRandom(88505);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeDeviceRepository devices = _devicesWithPersonalOnlyRunner();
      final FakeRunnerRepository repository = _buildRunners(
        runners: <Runner>[_runnerOn(random, _personalOnlyDeviceId)],
        devices: devices,
        workspaces: buildMembershipWorkspaces(GalleryWorkspaceIds.acme),
      );

      repository.dispose();
      final Device added = await devices.addDeviceToWorkspace(
        _personalOnlyDeviceId,
        GalleryWorkspaceIds.acme,
      );

      expect(added.workspaces, contains(GalleryWorkspaceIds.acme));
    }
  });

  test('${_typePrefix}_dispose_property_other_fakes_keep_listening', () async {
    final Random random = seededRandom(88506);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkspaceRepository workspaces = buildMembershipWorkspaces(
        GalleryWorkspaceIds.acme,
      );
      final FakeDeviceRepository devices = _devicesWithPersonalOnlyRunner();
      final List<Runner> runners = <Runner>[
        _runnerOn(random, _personalOnlyDeviceId),
      ];
      final FakeRunnerRepository disposed = _buildRunners(
        runners: runners,
        devices: devices,
        workspaces: workspaces,
      );
      final FakeRunnerRepository kept = _buildRunners(
        runners: runners,
        devices: devices,
        workspaces: workspaces,
      );
      final NotificationCounter notifications = NotificationCounter();
      kept.addListener(notifications.record);

      disposed.dispose();
      await workspaces.switchWorkspace(GalleryWorkspaceIds.personal);

      expect(notifications.count, greaterThan(0));
      expect(kept.listRunners(), runners);
    }
  });
}
