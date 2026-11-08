import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import '../../support/runner_memberships.dart';
import '../../support/sample_runners.dart';
import 'support/notification_counter.dart';

const String _typePrefix = 'test_fake_runner_repository';
const String _memberPrefix = 'member-device-';
const int _largestDeviceCount = 6;
const List<WorkspaceId> _workspaceIds = <WorkspaceId>[
  GalleryWorkspaceIds.acme,
  GalleryWorkspaceIds.personal,
];

typedef _RunnerWorld = ({
  FakeRunnerRepository runners,
  FakeDeviceRepository devices,
  FakeWorkspaceRepository workspaces,
  List<Runner> allRunners,
  List<Device> memberDevices,
});

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

List<WorkspaceId> _randomMemberships(Random random) {
  return <WorkspaceId>[
    for (final WorkspaceId workspaceId in _workspaceIds)
      if (random.nextBool()) workspaceId,
  ];
}

_RunnerWorld _buildWorld(Random random) {
  final int count = random.nextInt(_largestDeviceCount + 1);
  final List<Device> memberDevices = <Device>[
    for (int i = 0; i < count; i += 1)
      buildMemberDevice(
        DeviceId('$_memberPrefix$i'),
        _randomMemberships(random),
      ),
  ];
  final List<Runner> allRunners = <Runner>[
    for (final Device device in memberDevices) _runnerOn(random, device.id),
    _runnerOn(random, DeviceId('unknown-${random.nextInt(99)}')),
  ];
  allRunners.shuffle(random);
  final FakeDeviceRepository devices = buildMembershipDevices(memberDevices);
  final FakeWorkspaceRepository workspaces = buildMembershipWorkspaces(
    pickOne(random, _workspaceIds),
  );
  final FakeRunnerRepository runners = FakeRunnerRepository(
    runners: allRunners,
    deviceRepository: devices,
    workspaceRepository: workspaces,
    thisDeviceOffers: null,
    thisRunnerProblem: null,
  );
  return (
    runners: runners,
    devices: devices,
    workspaces: workspaces,
    allRunners: allRunners,
    memberDevices: memberDevices,
  );
}

List<Runner> _expectedListing(_RunnerWorld world) {
  final WorkspaceId workspaceId = world.workspaces.currentWorkspace().id;
  final Set<DeviceId> memberIds = <DeviceId>{
    for (final Device device in world.devices.listDevices())
      if (device.workspaces.contains(workspaceId)) device.id,
  };
  return <Runner>[
    for (final Runner runner in world.allRunners)
      if (memberIds.contains(runner.deviceId)) runner,
  ];
}

WorkspaceId _otherWorkspace(WorkspaceId workspaceId) {
  return _workspaceIds.firstWhere(
    (WorkspaceId candidate) => candidate != workspaceId,
  );
}

void main() {
  test('${_typePrefix}_list_runners_property_lists_only_members', () {
    final Random random = seededRandom(88401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RunnerWorld world = _buildWorld(random);

      expect(world.runners.listRunners(), _expectedListing(world));
    }
  });

  test('${_typePrefix}_list_runners_property_follows_a_switch', () async {
    final Random random = seededRandom(88402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RunnerWorld world = _buildWorld(random);
      final NotificationCounter notifications = NotificationCounter();
      world.runners.addListener(notifications.record);
      final WorkspaceId other = _otherWorkspace(
        world.workspaces.currentWorkspace().id,
      );

      await world.workspaces.switchWorkspace(other);

      expect(world.runners.listRunners(), _expectedListing(world));
      expect(notifications.count, greaterThan(0));
    }
  });

  test('${_typePrefix}_list_runners_property_follows_memberships', () async {
    final Random random = seededRandom(88403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RunnerWorld world = _buildWorld(random);
      if (world.memberDevices.isEmpty) {
        continue;
      }
      final Device device = pickOne(random, world.memberDevices);
      final WorkspaceId workspaceId = world.workspaces.currentWorkspace().id;
      final bool isMember = device.workspaces.contains(workspaceId);

      if (isMember) {
        await world.devices.removeDeviceFromWorkspace(device.id, workspaceId);
      } else {
        await world.devices.addDeviceToWorkspace(device.id, workspaceId);
      }

      final bool isListed = world.runners.listRunners().any(
        (Runner runner) => runner.deviceId == device.id,
      );
      expect(isListed, !isMember);
      expect(world.runners.listRunners(), _expectedListing(world));
    }
  });

  test('${_typePrefix}_find_runner_property_refuses_outsiders', () async {
    final Random random = seededRandom(88404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RunnerWorld world = _buildWorld(random);
      final List<Runner> listed = world.runners.listRunners();
      final List<Runner> outsiders = <Runner>[
        for (final Runner runner in world.allRunners)
          if (!listed.contains(runner)) runner,
      ];
      final Runner outsider = pickOne(random, outsiders);

      expect(
        () => world.runners.findRunner(outsider.deviceId),
        throwsA(isA<RecordNotFound>()),
      );
      await expectLater(
        world.runners.pauseRunner(outsider.deviceId),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });

  test('${_typePrefix}_find_runner_property_finds_every_listed_runner', () {
    final Random random = seededRandom(88405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RunnerWorld world = _buildWorld(random);

      for (final Runner runner in world.runners.listRunners()) {
        expect(world.runners.findRunner(runner.deviceId), runner);
      }
    }
  });

  test('${_typePrefix}_find_runner_property_follows_a_switch', () async {
    final Random random = seededRandom(88406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RunnerWorld world = _buildWorld(random);
      final WorkspaceId other = _otherWorkspace(
        world.workspaces.currentWorkspace().id,
      );

      await world.workspaces.switchWorkspace(other);

      for (final Runner runner in _expectedListing(world)) {
        expect(world.runners.findRunner(runner.deviceId), runner);
      }
    }
  });
}
