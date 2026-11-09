import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_runners.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/rules/device_runners.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_runners.dart';

const DeviceId _deviceWithoutRunner = DeviceId('device-without-runner');

DeviceId _randomAskedDevice(Random random) {
  final List<DeviceId> choices = <DeviceId>[
    for (final Runner runner in galleryRunners) runner.deviceId,
    _deviceWithoutRunner,
  ];
  return pickOne(random, choices);
}

Runner? _findFirstRunnerByModel(List<Runner> runners, DeviceId deviceId) {
  for (final Runner runner in runners) {
    if (runner.deviceId == deviceId) {
      return runner;
    }
  }
  return null;
}

void main() {
  test('test_find_device_runner_property_matches_the_first_match_model', () {
    final Random random = seededRandom(100301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);
      final DeviceId asked = _randomAskedDevice(random);

      final Runner? found = findDeviceRunner(
        runners: runners,
        deviceId: asked,
      );

      final Runner? expected = _findFirstRunnerByModel(runners, asked);
      expect(identical(found, expected), isTrue);
    }
  });

  test('test_find_device_runner_property_found_runner_is_on_the_device', () {
    final Random random = seededRandom(100302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);
      final DeviceId asked = _randomAskedDevice(random);

      final Runner? found = findDeviceRunner(
        runners: runners,
        deviceId: asked,
      );

      if (found == null) {
        final Iterable<DeviceId> devices = runners.map(
          (Runner runner) => runner.deviceId,
        );
        expect(devices, isNot(contains(asked)));
        continue;
      }
      expect(found.deviceId, asked);
      expect(runners.any((Runner runner) => identical(runner, found)), isTrue);
    }
  });

  test('test_find_device_runner_property_appended_runners_change_no_'
      'match', () {
    final Random random = seededRandom(100303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);
      final List<Runner> appended = randomRunners(random);
      final DeviceId asked = _randomAskedDevice(random);

      final Runner? before = findDeviceRunner(
        runners: runners,
        deviceId: asked,
      );
      final Runner? after = findDeviceRunner(
        runners: <Runner>[...runners, ...appended],
        deviceId: asked,
      );

      if (before != null) {
        expect(identical(after, before), isTrue);
      }
      expect(
        findDeviceRunner(runners: const <Runner>[], deviceId: asked),
        isNull,
      );
    }
  });
}
