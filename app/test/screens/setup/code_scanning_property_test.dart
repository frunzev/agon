import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';
import 'package:agent_orchestration/screens/setup/code_scanning.dart';
import 'package:agent_orchestration/screens/setup/server_hosting.dart';

import '../../support/random_inputs.dart';

void main() {
  test('test_can_scan_qr_codes_property_scanners_never_host_a_server', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      if (!canScanQrCodes(platform)) {
        continue;
      }
      for (final DeviceRole role in DeviceRole.values) {
        expect(
          canHostAppServer(platform: platform, role: role),
          isFalse,
          reason: '$platform $role',
        );
      }
    }
  });

  test('test_can_scan_qr_codes_property_scanners_set_up_as_clients_only', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final List<DeviceRole> roles = listSetupRoles(platform);
      final bool offersRunners = roles.any(roleRunsTasks);

      if (canScanQrCodes(platform)) {
        expect(offersRunners, isFalse, reason: '$platform');
      }
      if (offersRunners) {
        expect(canScanQrCodes(platform), isFalse, reason: '$platform');
      }
    }
  });

  test('test_can_scan_qr_codes_property_same_answer_in_any_order', () {
    final Random random = seededRandom(110601);
    final Map<TargetPlatform, bool> firstAnswers = <TargetPlatform, bool>{
      for (final TargetPlatform platform in TargetPlatform.values)
        platform: canScanQrCodes(platform),
    };

    for (int i = 0; i < propertyIterations; i += 1) {
      final TargetPlatform platform = pickOne(random, TargetPlatform.values);

      expect(canScanQrCodes(platform), firstAnswers[platform]);
    }
  });
}
