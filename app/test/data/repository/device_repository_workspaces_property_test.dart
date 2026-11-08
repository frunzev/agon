import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';

import '../../support/random_inputs.dart';
import 'support/contract_step_failures.dart';
import 'support/device_contract_rigs.dart';
import 'support/device_membership_checks.dart';

const String _typePrefix = 'test_device_repository';
const int _worldIterations = 40;
const int _longestSequence = 8;
void main() {
  test('${_typePrefix}_add_device_to_workspace_property_every_'
      'implementation_agrees_on_random_additions', () async {
    final Random random = seededRandom(84804);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildMembershipWorld(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        await expectMembershipChangeAgrees(
          random,
          world,
          MembershipChange.add,
        );
        await expectMembershipChangeAgrees(
          random,
          world,
          pickOne(random, MembershipChange.values),
        );
      }
    }
  });

  test('${_typePrefix}_add_device_to_workspace_property_adds_the_'
      'workspace_exactly_once', () async {
    final Random random = seededRandom(84805);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildMembershipWorld(random);
      final DeviceRepository first = world.implementations.first.repository;
      final DeviceId deviceId = pickDeviceId(random, first);
      final WorkspaceId workspaceId = pickWorkspaceId(random, first);

      for (int attempt = 0; attempt < 2; attempt += 1) {
        await changeMembershipOnEvery(
          world.implementations,
          change: MembershipChange.add,
          deviceId: deviceId,
          workspaceId: workspaceId,
        );
      }

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        for (final Device device in implementation.repository.listDevices()) {
          final List<WorkspaceId> joined = device.workspaces
              .where((WorkspaceId candidate) => candidate == workspaceId)
              .toList();
          expect(joined.length, lessThanOrEqualTo(1));
        }
      }
    }
  });

  test('${_typePrefix}_add_device_to_workspace_property_add_then_remove_'
      'restores_the_workspaces', () async {
    final Random random = seededRandom(84806);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildMembershipWorld(random);
      final DeviceRepository first = world.implementations.first.repository;
      final Device target = pickOtherDevice(random, first);
      final WorkspaceId workspaceId = pickWorkspaceId(random, first);

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        final DeviceRepository repository = implementation.repository;
        final DeviceProjection before = projectDevice(
          repository.findDevice(target.id),
        );
        final StepOutcome<Device> adding = await runContractStep(
          () => repository.addDeviceToWorkspace(target.id, workspaceId),
        );
        if (adding.value == null) {
          expect(isContractRefusal(adding.failure), isTrue);
          continue;
        }

        await repository.removeDeviceFromWorkspace(target.id, workspaceId);

        expect(
          projectDevice(repository.findDevice(target.id)),
          before,
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_remove_device_from_workspace_property_every_'
      'implementation_agrees_on_random_removals', () async {
    final Random random = seededRandom(84807);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildMembershipWorld(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        await expectMembershipChangeAgrees(
          random,
          world,
          MembershipChange.remove,
        );
      }
    }
  });

  test('${_typePrefix}_remove_device_from_workspace_property_removes_'
      'every_trace_of_the_workspace', () async {
    final Random random = seededRandom(84808);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildMembershipWorld(random);
      final DeviceRepository first = world.implementations.first.repository;
      final DeviceId deviceId = pickDeviceId(random, first);
      final WorkspaceId workspaceId = pickWorkspaceId(random, first);

      final List<MembershipOutcome> outcomes = await changeMembershipOnEvery(
        world.implementations,
        change: MembershipChange.remove,
        deviceId: deviceId,
        workspaceId: workspaceId,
      );

      for (int index = 0; index < outcomes.length; index += 1) {
        final Device? changed = outcomes[index].changed;
        if (changed == null) {
          continue;
        }
        final DeviceRepository repository =
            world.implementations[index].repository;
        expect(changed.workspaces, isNot(contains(workspaceId)));
        expect(
          repository.findDevice(deviceId).workspaces,
          isNot(contains(workspaceId)),
          reason: outcomes[index].name,
        );
      }
    }
  });

  test('${_typePrefix}_remove_device_from_workspace_property_a_non_member_'
      'is_refused_as_not_found', () async {
    final Random random = seededRandom(84809);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildMembershipWorld(random);
      final DeviceRepository first = world.implementations.first.repository;
      final Device target = pickOne(random, first.listDevices());
      final WorkspaceId absent = WorkspaceId(
        'never-joined-${random.nextInt(1 << 30)}',
      );

      final List<MembershipOutcome> outcomes = await changeMembershipOnEvery(
        world.implementations,
        change: MembershipChange.remove,
        deviceId: target.id,
        workspaceId: absent,
      );

      for (final MembershipOutcome outcome in outcomes) {
        expect(
          classifyMembershipOutcome(outcome),
          'app server $notFoundStatus',
          reason: outcome.name,
        );
      }
    }
  });
}
