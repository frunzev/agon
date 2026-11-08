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
  test('${_typePrefix}_revoke_device_property_every_implementation_agrees_'
      'on_random_revocations', () async {
    final Random random = seededRandom(84801);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildMembershipWorld(random);
      final int stepCount = 1 + random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        await expectMembershipChangeAgrees(
          random,
          world,
          MembershipChange.revoke,
        );
      }
    }
  });

  test('${_typePrefix}_revoke_device_property_a_revoked_device_stays_'
      'revoked_and_cannot_be_revoked_again', () async {
    final Random random = seededRandom(84802);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildMembershipWorld(random);
      final DeviceRepository first = world.implementations.first.repository;
      final Device target = pickOtherDevice(random, first);
      if (target.id == first.currentDevice().id) {
        continue;
      }

      await changeMembershipOnEvery(
        world.implementations,
        change: MembershipChange.revoke,
        deviceId: target.id,
        workspaceId: const WorkspaceId('unused'),
      );
      final List<MembershipOutcome> again = await changeMembershipOnEvery(
        world.implementations,
        change: MembershipChange.revoke,
        deviceId: target.id,
        workspaceId: const WorkspaceId('unused'),
      );

      for (int index = 0; index < again.length; index += 1) {
        expect(
          classifyMembershipOutcome(again[index]),
          'app server $conflictStatus',
          reason: again[index].name,
        );
        final DeviceRepository repository =
            world.implementations[index].repository;
        expect(repository.findDevice(target.id).revoked, isTrue);
      }
    }
  });

  test('${_typePrefix}_revoke_device_property_keeps_the_workspaces_of_the_'
      'revoked_device', () async {
    final Random random = seededRandom(84803);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildMembershipWorld(random);
      final DeviceRepository first = world.implementations.first.repository;
      final Device target = pickOtherDevice(random, first);

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        final DeviceProjection before = projectDevice(
          implementation.repository.findDevice(target.id),
        );
        final StepOutcome<Device> revoking = await runContractStep(
          () => implementation.repository.revokeDevice(target.id),
        );
        final Device? revoked = revoking.value;
        if (revoked == null) {
          expect(isContractRefusal(revoking.failure), isTrue);
          expect(
            projectDevice(implementation.repository.findDevice(target.id)),
            before,
          );
          continue;
        }
        expect(projectDevice(revoked), (
          id: before.id,
          revoked: true,
          workspaces: before.workspaces,
        ), reason: implementation.name);
      }
    }
  });
}
