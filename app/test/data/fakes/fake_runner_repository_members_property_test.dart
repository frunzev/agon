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

const String _typePrefix =
    'test_fake_runner_repository_find_current_workspace_member_ids';
const DeviceId _deviceId = DeviceId('membership-device');
const List<WorkspaceId> _workspaceIds = <WorkspaceId>[
  GalleryWorkspaceIds.acme,
  GalleryWorkspaceIds.personal,
];

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
  required Runner runner,
  required List<Device> devices,
  required FakeWorkspaceRepository workspaces,
}) {
  return FakeRunnerRepository(
    runners: <Runner>[runner],
    deviceRepository: buildMembershipDevices(devices),
    workspaceRepository: workspaces,
    thisDeviceOffers: null,
    thisRunnerProblem: null,
  );
}

void main() {
  test('${_typePrefix}_property_skip_other_workspaces', () {
    final Random random = seededRandom(88701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkspaceId current = pickOne(random, _workspaceIds);
      final WorkspaceId other = _workspaceIds.firstWhere(
        (WorkspaceId workspaceId) => workspaceId != current,
      );
      final FakeRunnerRepository repository = _buildRunners(
        runner: _runnerOn(random, _deviceId),
        devices: <Device>[
          buildMemberDevice(_deviceId, <WorkspaceId>[other]),
        ],
        workspaces: buildMembershipWorkspaces(current),
      );

      expect(repository.listRunners(), isEmpty);
    }
  });

  test('${_typePrefix}_property_keep_devices_in_every_workspace', () async {
    final Random random = seededRandom(88702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Runner runner = _runnerOn(random, _deviceId);
      final FakeWorkspaceRepository workspaces = buildMembershipWorkspaces(
        pickOne(random, _workspaceIds),
      );
      final FakeRunnerRepository repository = _buildRunners(
        runner: runner,
        devices: <Device>[buildMemberDevice(_deviceId, _workspaceIds)],
        workspaces: workspaces,
      );

      final List<Runner> before = repository.listRunners();
      await workspaces.switchWorkspace(pickOne(random, _workspaceIds));

      expect(before, <Runner>[runner]);
      expect(repository.listRunners(), <Runner>[runner]);
    }
  });

  test('${_typePrefix}_property_never_list_unknown_devices', () async {
    final Random random = seededRandom(88703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkspaceRepository workspaces = buildMembershipWorkspaces(
        pickOne(random, _workspaceIds),
      );
      final FakeRunnerRepository repository = _buildRunners(
        runner: _runnerOn(random, DeviceId('unknown-${randomText(random)}')),
        devices: const <Device>[],
        workspaces: workspaces,
      );

      final List<Runner> before = repository.listRunners();
      await workspaces.switchWorkspace(pickOne(random, _workspaceIds));

      expect(before, isEmpty);
      expect(repository.listRunners(), isEmpty);
    }
  });
}
