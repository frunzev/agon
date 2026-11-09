import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';

import '../bridge/support/hostile_texts.dart';
import '../bridge/support/node_json_primitives.dart';
import '../support/random_device_records.dart';
import '../support/random_inputs.dart';

const int _shortenedIdentifierLength = 9;

Map<DeviceId, String> _namesByIdentifier(List<Device> devices) {
  return <DeviceId, String>{
    for (final Device device in devices) device.id: device.name,
  };
}

DeviceId _randomProbe(Random random, List<Device> devices) {
  if (devices.isNotEmpty && random.nextBool()) {
    return pickOne(random, devices).id;
  }
  return DeviceId('unknown-${randomDeviceIdText(random)}');
}

Device _renamed(Device device, String name) {
  return Device(
    id: device.id,
    name: name,
    role: device.role,
    kind: device.kind,
    keyKind: device.keyKind,
    signingPublicKey: device.signingPublicKey,
    sealingPublicKey: device.sealingPublicKey,
    workspaces: device.workspaces,
    pairedAt: device.pairedAt,
    approvedBy: device.approvedBy,
    lastSeen: device.lastSeen,
    revoked: device.revoked,
  );
}

void main() {
  test('test_device_names_constructor_property_keeps_every_device_name', () {
    final Random random = seededRandom(97241);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Device> devices = randomDeviceRecords(random);

      final DeviceNames names = DeviceNames(devices);

      for (final Device device in devices) {
        expect(names.findName(device.id), device.name);
      }
    }
  });

  test('test_device_names_constructor_property_ignores_later_list_edits', () {
    final Random random = seededRandom(97242);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Device> devices = randomDeviceRecords(random);
      final Map<DeviceId, String> expected = _namesByIdentifier(devices);
      final DeviceNames names = DeviceNames(devices);

      final Device added = randomDeviceRecord(random, approvedBy: null);
      devices.add(added);
      devices.removeAt(0);

      for (final MapEntry<DeviceId, String> entry in expected.entries) {
        expect(names.findName(entry.key), entry.value);
      }
      expect(names.findName(added.id), isNull);
    }
  });

  test('test_device_names_constructor_property_empty_list_knows_nobody', () {
    final Random random = seededRandom(97243);
    final DeviceNames names = DeviceNames(const <Device>[]);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId probe = DeviceId(randomDeviceIdText(random));

      expect(names.findName(probe), isNull);
    }
  });

  test('test_find_name_property_matches_a_reference_map', () {
    final Random random = seededRandom(97244);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Device> devices = randomDeviceRecords(random);
      final Map<DeviceId, String> reference = _namesByIdentifier(devices);
      final DeviceNames names = DeviceNames(devices);
      final DeviceId probe = _randomProbe(random, devices);

      expect(names.findName(probe), reference[probe]);
    }
  });

  test('test_find_name_property_shared_names_resolve_by_identifier', () {
    final Random random = seededRandom(97245);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String sharedName = randomHostileText(random);
      final List<Device> devices = <Device>[
        for (final Device device in randomDeviceRecords(random))
          _renamed(device, sharedName),
      ];
      final DeviceNames names = DeviceNames(devices);

      for (final Device device in devices) {
        expect(names.findName(device.id), sharedName);
      }
    }
  });

  test('test_describe_device_property_unknown_devices_read_as_their_short_'
      'identifier', () {
    final Random random = seededRandom(97246);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceNames names = DeviceNames(randomDeviceRecords(random));
      final DeviceId unknown = DeviceId(
        'unknown-${randomHostileText(random)}',
      );

      expect(names.describeDevice(unknown), shortenIdentifier(unknown.value));
    }
  });

  test('test_describe_device_property_known_devices_keep_hostile_names', () {
    final Random random = seededRandom(97247);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Device> devices = randomDeviceRecords(random);
      final DeviceNames names = DeviceNames(devices);

      for (final Device device in devices) {
        expect(names.describeDevice(device.id), device.name);
      }
    }
  });

  test('test_describe_device_property_never_empty_for_real_inputs', () {
    final Random random = seededRandom(97248);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Device> devices = <Device>[
        for (final Device device in randomDeviceRecords(random))
          if (device.name.trim().isNotEmpty) device,
      ];
      final DeviceNames names = DeviceNames(devices);
      final DeviceId probe = _randomProbe(random, devices);

      expect(names.describeDevice(probe).trim(), isNotEmpty);
    }
  });

  test('test_describe_device_property_unknown_devices_stay_short', () {
    final Random random = seededRandom(97249);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceNames names = DeviceNames(randomDeviceRecords(random));
      final DeviceId unknown = DeviceId(randomDeviceIdText(random));

      final String text = names.describeDevice(unknown);

      expect(text.length, lessThanOrEqualTo(_shortenedIdentifierLength));
      expect(unknown.value.startsWith(text.substring(0, 4)), isTrue);
      expect(unknown.value.endsWith(text.substring(text.length - 4)), isTrue);
    }
  });

  test('test_describe_device_property_known_devices_agree_with_find_name', () {
    final Random random = seededRandom(97250);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Device> devices = randomDeviceRecords(random);
      final DeviceNames names = DeviceNames(devices);

      for (final Device device in devices) {
        expect(names.describeDevice(device.id), names.findName(device.id));
      }
    }
  });
}
