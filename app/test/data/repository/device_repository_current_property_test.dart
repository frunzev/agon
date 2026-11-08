import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/device_repository_rig.dart';
import 'support/device_contract_rigs.dart';

const String _typePrefix = 'test_device_repository';
const int _worldIterations = 40;
const int _longestSequence = 8;

void main() {
  test('${_typePrefix}_current_device_property_is_this_device_in_every_'
      'implementation', () async {
    final Random random = seededRandom(84707);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world =
          await buildDeviceWorldAfterRandomChanges(random);

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        expect(
          implementation.repository.currentDevice().id.value,
          rigThisDeviceId,
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_current_device_property_matches_its_listed_'
      'record', () async {
    final Random random = seededRandom(84708);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world =
          await buildDeviceWorldAfterRandomChanges(random);

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        final DeviceRepository repository = implementation.repository;
        final Device current = repository.currentDevice();

        expect(
          projectDevice(current),
          projectDevice(repository.findDevice(current.id)),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_current_device_property_is_never_revoked_by_its_'
      'own_hand', () async {
    final Random random = seededRandom(84709);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildEveryDeviceRepository(
        random,
        gitlessFolderPaths: const <String>{},
      );
      final DeviceId thisDeviceId = world.implementations.first.repository
          .currentDevice()
          .id;

      final List<MembershipOutcome> outcomes = await changeMembershipOnEvery(
        world.implementations,
        change: MembershipChange.revoke,
        deviceId: thisDeviceId,
        workspaceId: const WorkspaceId('unused'),
      );

      for (int index = 0; index < outcomes.length; index += 1) {
        expect(outcomes[index].failure, isA<StateError>());
        expect(
          world.implementations[index].repository.currentDevice().revoked,
          isFalse,
          reason: outcomes[index].name,
        );
      }
    }
  });

  test('${_typePrefix}_find_peer_address_problem_property_every_'
      'implementation_reports_the_node_problem', () async {
    final Random random = seededRandom(84710);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world =
          await buildDeviceWorldAfterRandomChanges(random);

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        expect(
          implementation.repository.findPeerAddressProblem(),
          world.node.peerProblem,
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_find_peer_address_problem_property_membership_'
      'changes_keep_it', () async {
    final Random random = seededRandom(84711);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildEveryDeviceRepository(
        random,
        gitlessFolderPaths: const <String>{},
      );
      final List<String?> before = <String?>[
        for (final NamedDeviceRepository implementation
            in world.implementations)
          implementation.repository.findPeerAddressProblem(),
      ];

      final int stepCount = 1 + random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        await changeRandomlyOnEvery(random, world.implementations);
      }

      expect(<String?>[
        for (final NamedDeviceRepository implementation
            in world.implementations)
          implementation.repository.findPeerAddressProblem(),
      ], before);
    }
  });

  test('${_typePrefix}_find_peer_address_problem_property_problems_are_'
      'never_blank', () async {
    final Random random = seededRandom(84712);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world =
          await buildDeviceWorldAfterRandomChanges(random);

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        final String? problem = implementation.repository
            .findPeerAddressProblem();
        if (problem != null) {
          expect(problem.trim(), isNotEmpty, reason: implementation.name);
        }
      }
    }
  });
}
