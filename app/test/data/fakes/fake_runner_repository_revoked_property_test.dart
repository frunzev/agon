import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';

import '../../support/random_inputs.dart';
import '../../support/runner_memberships.dart';
import '../../support/sample_runners.dart';

const String _typePrefix =
    'test_fake_runner_repository_find_current_workspace_member_ids';
const int _mostMembers = 6;
const String _memberIdPrefix = 'revoked-world-';

final class _RevokedWorld {
  const _RevokedWorld({required this.devices, required this.runners});

  final FakeDeviceRepository devices;
  final FakeRunnerRepository runners;
}

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

_RevokedWorld _randomWorld(Random random) {
  final List<Device> members = <Device>[];
  final int count = 1 + random.nextInt(_mostMembers);
  for (int i = 0; i < count; i += 1) {
    final Device member = buildMemberDevice(
      DeviceId('$_memberIdPrefix$i'),
      const <WorkspaceId>[membershipWorkspaceId],
    );
    members.add(random.nextBool() ? member.asRevoked() : member);
  }
  final FakeDeviceRepository devices = buildMembershipDevices(members);
  final FakeRunnerRepository runners = FakeRunnerRepository(
    runners: <Runner>[
      for (final Device member in members) _runnerOn(random, member.id),
    ],
    deviceRepository: devices,
    workspaceRepository: buildMembershipWorkspaces(membershipWorkspaceId),
    thisDeviceOffers: null,
    thisRunnerProblem: null,
  );
  return _RevokedWorld(devices: devices, runners: runners);
}

Set<DeviceId> _listRunnerDeviceIds(FakeRunnerRepository runners) {
  return <DeviceId>{
    for (final Runner runner in runners.listRunners()) runner.deviceId,
  };
}

void main() {
  test('${_typePrefix}_property_revoked_devices_run_nothing', () {
    final Random random = seededRandom(74301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RevokedWorld world = _randomWorld(random);

      final Set<DeviceId> listed = _listRunnerDeviceIds(world.runners);

      for (final DeviceId deviceId in listed) {
        expect(world.devices.findDevice(deviceId).revoked, isFalse);
      }
    }
  });

  test('${_typePrefix}_property_revoking_drops_only_that_runner', () async {
    final Random random = seededRandom(74302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RevokedWorld world = _randomWorld(random);
      final Set<DeviceId> before = _listRunnerDeviceIds(world.runners);
      if (before.isEmpty) {
        continue;
      }
      final DeviceId revokedId = pickOne(random, before.toList());

      await world.devices.revokeDevice(revokedId);

      expect(
        _listRunnerDeviceIds(world.runners),
        before.difference(<DeviceId>{revokedId}),
      );
    }
  });

  test('${_typePrefix}_property_live_members_keep_their_runners', () {
    final Random random = seededRandom(74303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RevokedWorld world = _randomWorld(random);

      final Set<DeviceId> listed = _listRunnerDeviceIds(world.runners);

      for (final Device device in world.devices.listDevices()) {
        final bool runsHere = device.id.value.startsWith(_memberIdPrefix);
        if (runsHere && !device.revoked) {
          expect(listed, contains(device.id));
        }
      }
    }
  });
}
