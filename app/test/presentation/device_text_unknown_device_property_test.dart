import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/device_text.dart';

import '../support/random_device_records.dart';
import '../support/random_inputs.dart';
import '../support/unknown_device_names.dart';

Device _approvedBy(Random random, DeviceId approver) {
  return randomDeviceRecord(random, approvedBy: approver);
}

void main() {
  test('test_describe_device_pairing_property_an_unknown_approver_never_'
      'throws', () {
    final Random random = seededRandom(5311401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final Device device = _approvedBy(random, unknown.deviceId);

      expect(
        () => describeDevicePairing(device, unknown.withoutDevice),
        returnsNormally,
      );
    }
  });

  test('test_describe_device_pairing_property_an_unknown_approver_reads_as_'
      'its_short_identifier', () {
    final Random random = seededRandom(5311402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final UnknownDeviceNames unknown = randomUnknownDeviceNames(random);
      final Device device = _approvedBy(random, unknown.deviceId);

      final String withoutDevice = describeDevicePairing(
        device,
        unknown.withoutDevice,
      );

      expect(
        withoutDevice,
        describeDevicePairing(device, unknown.namingShortly),
      );
      expect(withoutDevice, endsWith('approved by ${unknown.shortName}'));
    }
  });

  test('test_describe_device_pairing_property_a_known_approver_is_named', () {
    final Random random = seededRandom(5311403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final KnownDeviceNames known = randomKnownDeviceNames(random);
      final Device device = _approvedBy(random, known.device.id);
      final DeviceNames deviceNames = known.deviceNames;

      final String text = describeDevicePairing(device, deviceNames);

      expect(text, endsWith('approved by ${known.device.name}'));
    }
  });
}
