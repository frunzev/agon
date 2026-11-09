import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_runners.dart';

const String _offlineSuffix = ', offline';
const int _unknownDeviceSpan = 4;

final DeviceNames _galleryDeviceNames = DeviceNames(galleryDevices);

List<Runner> _randomUniqueRunners(Random random) {
  final Map<DeviceId, Runner> runnersByDevice = <DeviceId, Runner>{};
  for (final Runner runner in randomRunners(random)) {
    runnersByDevice[runner.deviceId] = runner;
  }
  return runnersByDevice.values.toList();
}

RunnerTarget _randomTarget(Random random) {
  final List<RunnerTarget> choices = <RunnerTarget>[
    const AnyFreeRunner(),
    SpecificRunner(pickOne(random, galleryDevices).id),
    SpecificRunner(DeviceId('unknown-${random.nextInt(_unknownDeviceSpan)}')),
    RunnerWithLabels(<String>['label-${random.nextInt(3)}']),
  ];
  return pickOne(random, choices);
}

Set<RunnerTarget> _listOnlineTargets(List<Runner> runners) {
  return <RunnerTarget>{
    const AnyFreeRunner(),
    for (final Runner runner in runners)
      if (runner.online) SpecificRunner(runner.deviceId),
  };
}

List<RunnerTarget> _listValues(List<SelectOption<RunnerTarget>> options) {
  return <RunnerTarget>[
    for (final SelectOption<RunnerTarget> option in options) option.value,
  ];
}

TaskFormOptions _buildRandomOptions(Random random, List<Runner> runners) {
  final AppDependencies dependencies = buildGalleryDependencies();
  return buildTaskFormOptions(
    projects: dependencies.projectRepository.listProjects(
      dependencies.workspaceRepository.currentWorkspace().id,
    ),
    workflows: dependencies.workflowRepository.listWorkflows(),
    findPendingChange: dependencies.workflowRepository.findPendingChange,
    runners: runners,
    deviceNames: _galleryDeviceNames,
    skills: dependencies.skillRepository.listSkills(),
    chosenTarget: _randomTarget(random),
  );
}

void main() {
  test('test_list_runner_choices_property_holds_the_shown_target_once', () {
    final Random random = seededRandom(53001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = _buildRandomOptions(
        random,
        _randomUniqueRunners(random),
      );
      final RunnerTarget shownTarget = _randomTarget(random);

      final List<RunnerTarget> values = _listValues(
        options.listRunnerChoices(shownTarget),
      );

      final List<RunnerTarget> shownValues = <RunnerTarget>[
        for (final RunnerTarget value in values)
          if (value == shownTarget) value,
      ];
      expect(shownValues, <RunnerTarget>[shownTarget]);
      expect(values.toSet().length, values.length, reason: '$values');
    }
  });

  test('test_list_runner_choices_property_keeps_listed_choices_in_order', () {
    final Random random = seededRandom(53002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = _buildRandomOptions(
        random,
        _randomUniqueRunners(random),
      );
      final RunnerTarget shownTarget = _randomTarget(random);

      final List<SelectOption<RunnerTarget>> choices = options
          .listRunnerChoices(shownTarget);

      final bool isListed = _listValues(options.runners).contains(shownTarget);
      final int extraCount = isListed ? 0 : 1;
      expect(choices.length, options.runners.length + extraCount);
      for (int index = 0; index < options.runners.length; index += 1) {
        expect(choices[index].value, options.runners[index].value);
        expect(choices[index].label, options.runners[index].label);
      }
    }
  });

  test('test_list_runner_choices_property_a_missing_runner_reads_offline', () {
    final Random random = seededRandom(53003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = _randomUniqueRunners(random);
      final TaskFormOptions options = _buildRandomOptions(random, runners);
      final Device device = pickOne(random, galleryDevices);
      final RunnerTarget shownTarget = SpecificRunner(device.id);

      final SelectOption<RunnerTarget> shown = options
          .listRunnerChoices(shownTarget)
          .singleWhere(
            (SelectOption<RunnerTarget> option) => option.value == shownTarget,
          );

      final bool isListed = _listValues(options.runners).contains(shownTarget);
      final String expectedLabel = isListed
          ? options.runners
                .singleWhere(
                  (SelectOption<RunnerTarget> option) =>
                      option.value == shownTarget,
                )
                .label
          : '${device.name}$_offlineSuffix';
      expect(shown.label, expectedLabel);
    }
  });

  test('test_build_runner_options_property_offline_choice_says_offline', () {
    final Random random = seededRandom(53004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = _randomUniqueRunners(random);
      final Device device = pickOne(random, galleryDevices);
      final RunnerTarget chosenTarget = SpecificRunner(device.id);

      final List<SelectOption<RunnerTarget>> options = buildRunnerOptions(
        runners: runners,
        deviceNames: _galleryDeviceNames,
        chosenTarget: chosenTarget,
      );

      final bool isOnline = _listOnlineTargets(runners).contains(chosenTarget);
      final String chosenLabel = options
          .singleWhere(
            (SelectOption<RunnerTarget> option) =>
                option.value == chosenTarget,
          )
          .label;
      expect(chosenLabel.endsWith(_offlineSuffix), !isOnline);
      expect(chosenLabel, startsWith(device.name));
    }
  });

  test('test_build_runner_options_property_online_choices_never_say_off', () {
    final Random random = seededRandom(53005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = _randomUniqueRunners(random);
      final RunnerTarget chosenTarget = _randomTarget(random);

      final List<SelectOption<RunnerTarget>> options = buildRunnerOptions(
        runners: runners,
        deviceNames: _galleryDeviceNames,
        chosenTarget: chosenTarget,
      );

      final Set<RunnerTarget> onlineTargets = _listOnlineTargets(runners);
      for (final SelectOption<RunnerTarget> option in options) {
        if (onlineTargets.contains(option.value)) {
          expect(option.label.endsWith(_offlineSuffix), isFalse);
        }
      }
    }
  });

  test('test_build_runner_options_property_online_then_chosen_unique', () {
    final Random random = seededRandom(53006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = _randomUniqueRunners(random);
      final RunnerTarget chosenTarget = _randomTarget(random);

      final List<RunnerTarget> values = _listValues(
        buildRunnerOptions(
          runners: runners,
          deviceNames: _galleryDeviceNames,
          chosenTarget: chosenTarget,
        ),
      );

      final Set<RunnerTarget> expected = <RunnerTarget>{
        ..._listOnlineTargets(runners),
        chosenTarget,
      };
      expect(values.toSet(), expected);
      expect(values.length, expected.length);
      expect(values.first, const AnyFreeRunner());
    }
  });
}
