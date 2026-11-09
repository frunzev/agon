import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_records.dart';
import 'task_form_scene.dart';

const String _pausedSuffix = ', paused';
const String _offlineSuffix = ', offline';

final DeviceNames _galleryDeviceNames = DeviceNames(galleryDevices);

SelectOption<RunnerTarget> _findChoice(
  List<SelectOption<RunnerTarget>> choices,
  RunnerTarget target,
) {
  return choices.singleWhere(
    (SelectOption<RunnerTarget> choice) => choice.value == target,
  );
}

List<Runner> _acceptingCopies(List<Runner> runners) {
  return <Runner>[
    for (final Runner runner in runners) runner.asAcceptingNewRuns(),
  ];
}

void main() {
  test('test_build_runner_options_property_paused_runners_say_paused', () {
    final Random random = seededRandom(1161301);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunnersOnDistinctDevices(random);

      final List<SelectOption<RunnerTarget>> choices = buildRunnerOptions(
        runners: runners,
        deviceNames: _galleryDeviceNames,
        chosenTarget: const AnyFreeRunner(),
      );

      for (final Runner runner in runners) {
        if (!runner.online) {
          continue;
        }
        final String deviceName = _galleryDeviceNames.describeDevice(
          runner.deviceId,
        );
        final String expected = runner.acceptingNewRuns
            ? deviceName
            : '$deviceName$_pausedSuffix';
        final SelectOption<RunnerTarget> choice = _findChoice(
          choices,
          SpecificRunner(runner.deviceId),
        );
        expect(choice.label, expected);
      }
    }
  });

  test('test_build_runner_options_property_pausing_changes_only_labels', () {
    final Random random = seededRandom(1161302);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunnersOnDistinctDevices(random);
      final RunnerTarget chosen = randomRunnerTarget(random);

      final List<SelectOption<RunnerTarget>> mixed = buildRunnerOptions(
        runners: runners,
        deviceNames: _galleryDeviceNames,
        chosenTarget: chosen,
      );
      final List<SelectOption<RunnerTarget>> accepting = buildRunnerOptions(
        runners: _acceptingCopies(runners),
        deviceNames: _galleryDeviceNames,
        chosenTarget: chosen,
      );

      expect(listOptionValues(mixed), listOptionValues(accepting));
      for (final SelectOption<RunnerTarget> choice in accepting) {
        expect(choice.label, isNot(endsWith(_pausedSuffix)));
      }
    }
  });

  test('test_build_runner_options_property_offline_runner_never_paused', () {
    final Random random = seededRandom(1161303);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunnersOnDistinctDevices(random);
      final List<Runner> offline = <Runner>[
        for (final Runner runner in runners)
          if (!runner.online) runner,
      ];
      if (offline.isEmpty) {
        continue;
      }
      final RunnerTarget chosen = SpecificRunner(
        pickOne(random, offline).deviceId,
      );

      final List<SelectOption<RunnerTarget>> choices = buildRunnerOptions(
        runners: runners,
        deviceNames: _galleryDeviceNames,
        chosenTarget: chosen,
      );

      final String label = _findChoice(choices, chosen).label;
      expect(label, endsWith(_offlineSuffix));
      expect(label, isNot(contains(_pausedSuffix)));
    }
  });
}
