import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';

import '../../support/random_inputs.dart';
import 'support/contract_step_failures.dart';
import 'support/device_contract_rigs.dart';

const String _typePrefix = 'test_device_repository';
const int _worldIterations = 40;
const int _longestSequence = 8;

List<String> _listIdentifiers(DeviceRepository repository) {
  return <String>[
    for (final Device device in repository.listDevices()) device.id.value,
  ];
}

void main() {
  test('${_typePrefix}_list_devices_property_every_implementation_lists_'
      'the_same_devices', () async {
    final Random random = seededRandom(84701);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world =
          await buildDeviceWorldAfterRandomChanges(random);
      final List<DeviceProjection> expected = projectDevices(
        world.implementations.first.repository.listDevices(),
      );

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        expect(
          projectDevices(implementation.repository.listDevices()),
          orderedEquals(expected),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_list_devices_property_changes_never_add_or_remove_'
      'devices', () async {
    final Random random = seededRandom(84702);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildEveryDeviceRepository(
        random,
        gitlessFolderPaths: const <String>{},
      );
      final List<String> seeded = _listIdentifiers(
        world.implementations.first.repository,
      );

      final int stepCount = 1 + random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        await changeRandomlyOnEvery(random, world.implementations);
      }

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        expect(
          _listIdentifiers(implementation.repository),
          orderedEquals(seeded),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_list_devices_property_callers_cannot_change_the_'
      'stored_list', () async {
    final Random random = seededRandom(84703);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world =
          await buildDeviceWorldAfterRandomChanges(random);

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        final List<Device> listed = implementation.repository.listDevices();
        final List<String> before = _listIdentifiers(
          implementation.repository,
        );

        final Object? failure = await findStepFailure(() async {
          listed.clear();
        });

        expect(failure, isA<UnsupportedError>(), reason: implementation.name);
        expect(_listIdentifiers(implementation.repository), before);
      }
    }
  });

  test('${_typePrefix}_find_device_property_finds_every_listed_device_as_'
      'listed', () async {
    final Random random = seededRandom(84704);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world =
          await buildDeviceWorldAfterRandomChanges(random);

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        final DeviceRepository repository = implementation.repository;
        for (final Device listed in repository.listDevices()) {
          expect(
            projectDevice(repository.findDevice(listed.id)),
            projectDevice(listed),
            reason: implementation.name,
          );
        }
      }
    }
  });

  test('${_typePrefix}_find_device_property_unknown_devices_are_not_'
      'found', () async {
    final Random random = seededRandom(84705);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world =
          await buildDeviceWorldAfterRandomChanges(random);
      final DeviceId missing = DeviceId('absent ${randomText(random)}');

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        final Object? failure = await findStepFailure(
          () async => implementation.repository.findDevice(missing),
        );

        expect(failure, isA<RecordNotFound>(), reason: implementation.name);
        expect((failure! as RecordNotFound).identifier, missing.value);
      }
    }
  });

  test('${_typePrefix}_find_device_property_reflects_the_returned_'
      'change', () async {
    final Random random = seededRandom(84706);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildEveryDeviceRepository(
        random,
        gitlessFolderPaths: const <String>{},
      );

      final int stepCount = 1 + random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        final List<MembershipOutcome> outcomes = await changeRandomlyOnEvery(
          random,
          world.implementations,
        );
        for (int index = 0; index < outcomes.length; index += 1) {
          final Device? changed = outcomes[index].changed;
          if (changed == null) {
            continue;
          }
          final DeviceRepository repository =
              world.implementations[index].repository;
          expect(
            projectDevice(repository.findDevice(changed.id)),
            projectDevice(changed),
            reason: outcomes[index].name,
          );
        }
      }
    }
  });
}
