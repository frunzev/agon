import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../presentation/support/plain_shown_text.dart';
import '../../support/random_inputs.dart';
import 'task_form_scene.dart';

const String _anyFreeRunnerLabel = 'Any free runner';
const String _offlineSuffix = ', offline';
const String _pausedSuffix = ', paused';
const String _designPage = 'task-new';

final DeviceNames _galleryDeviceNames = DeviceNames(galleryDevices);

void main() {
  test('test_describe_target_label_property_any_free_runner_comes_first', () {
    final Random random = seededRandom(1132107);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SelectOption<RunnerTarget>> options = buildRunnerOptions(
        runners: randomRunnersOnDistinctDevices(random),
        deviceNames: _galleryDeviceNames,
        chosenTarget: const AnyFreeRunner(),
      );

      expect(options.first.value, const AnyFreeRunner());
      expect(options.first.label, _anyFreeRunnerLabel);
      expect(
        readDesignPageText(_designPage),
        contains(' $_anyFreeRunnerLabel '),
      );
    }
  });

  test(
    'test_describe_target_label_property_online_runners_by_device_name',
    () {
      final Random random = seededRandom(1132108);
      for (int i = 0; i < propertyIterations; i += 1) {
        final List<Device> devices = <Device>[
          for (final Device device in galleryDevices)
            if (random.nextBool()) device,
        ];
        final DeviceNames deviceNames = DeviceNames(devices);
        final List<Runner> runners = randomRunnersOnDistinctDevices(random);

        final List<SelectOption<RunnerTarget>> options = buildRunnerOptions(
          runners: runners,
          deviceNames: deviceNames,
          chosenTarget: const AnyFreeRunner(),
        );

        for (final Runner runner in runners) {
          if (!runner.online) {
            continue;
          }
          final SelectOption<RunnerTarget> option = options.singleWhere(
            (SelectOption<RunnerTarget> o) =>
                o.value == SpecificRunner(runner.deviceId),
          );
          final String deviceName = deviceNames.describeDevice(
            runner.deviceId,
          );
          final String expected = runner.acceptingNewRuns
              ? deviceName
              : '$deviceName$_pausedSuffix';
          expect(option.label, expected);
          expect(option.label, isNot(endsWith(_offlineSuffix)));
        }
      }
    },
  );

  test('test_describe_target_label_property_labels_name_the_labels', () {
    final Random random = seededRandom(1132109);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int labelCount = 1 + random.nextInt(3);
      final List<String> labels = <String>[
        for (int index = 0; index < labelCount; index += 1)
          'label-${random.nextInt(9)}',
      ];
      final RunnerTarget target = RunnerWithLabels(labels);

      final List<SelectOption<RunnerTarget>> options = buildRunnerOptions(
        runners: randomRunnersOnDistinctDevices(random),
        deviceNames: _galleryDeviceNames,
        chosenTarget: target,
      );

      final String label = options.last.label;
      expect(options.last.value, target);
      for (final String runnerLabel in labels) {
        expect(label, contains(runnerLabel));
      }
      expect(label, isNot(endsWith(_offlineSuffix)));
    }
  });
}
