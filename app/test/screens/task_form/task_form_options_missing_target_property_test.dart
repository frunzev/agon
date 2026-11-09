import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_runners.dart';

const String _offlineSuffix = ', offline';

final DeviceNames _deviceNames = DeviceNames(galleryDevices);

TaskFormOptions _buildOptions(Random random, RunnerTarget chosenTarget) {
  final AppDependencies dependencies = buildGalleryDependencies();
  final Map<DeviceId, Runner> runnersByDevice = <DeviceId, Runner>{
    for (final Runner runner in randomRunners(random)) runner.deviceId: runner,
  };
  return buildTaskFormOptions(
    projects: dependencies.projectRepository.listProjects(
      dependencies.workspaceRepository.currentWorkspace().id,
    ),
    workflows: dependencies.workflowRepository.listWorkflows(),
    findPendingChange: dependencies.workflowRepository.findPendingChange,
    runners: runnersByDevice.values.toList(),
    deviceNames: _deviceNames,
    skills: dependencies.skillRepository.listSkills(),
    chosenTarget: chosenTarget,
  );
}

RunnerTarget _randomUnknownRunner(Random random) {
  return SpecificRunner(DeviceId('nowhere-${randomHostileText(random)}'));
}

List<String> _randomLabels(Random random) {
  return <String>[
    for (int index = 0; index < 1 + random.nextInt(3); index += 1)
      'label-$index-${random.nextInt(9)}',
  ];
}

String _labelOf(List<SelectOption<RunnerTarget>> options, RunnerTarget t) {
  return options
      .singleWhere((SelectOption<RunnerTarget> option) => option.value == t)
      .label;
}

void main() {
  test(
    'test_include_runner_target_property_listed_target_changes_nothing',
    () {
      final Random random = seededRandom(54701);

      for (int i = 0; i < propertyIterations; i += 1) {
        final TaskFormOptions options = _buildOptions(
          random,
          const AnyFreeRunner(),
        );
        final SelectOption<RunnerTarget> listed = pickOne(
          random,
          options.runners,
        );

        final List<SelectOption<RunnerTarget>> choices = options
            .listRunnerChoices(listed.value);

        expect(identical(choices, options.runners), isTrue);
      }
    },
  );

  test('test_include_runner_target_property_missing_target_goes_last', () {
    final Random random = seededRandom(54702);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = _buildOptions(
        random,
        const AnyFreeRunner(),
      );
      final RunnerTarget missing = _randomUnknownRunner(random);

      final List<SelectOption<RunnerTarget>> choices = options
          .listRunnerChoices(missing);

      expect(choices.length, options.runners.length + 1);
      expect(choices.last.value, missing);
      expect(choices.sublist(0, options.runners.length), options.runners);
    }
  });

  test('test_include_runner_target_property_chosen_target_is_idempotent', () {
    final Random random = seededRandom(54703);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerTarget chosen = random.nextBool()
          ? _randomUnknownRunner(random)
          : RunnerWithLabels(_randomLabels(random));
      final TaskFormOptions options = _buildOptions(random, chosen);

      final List<SelectOption<RunnerTarget>> once = options.listRunnerChoices(
        chosen,
      );

      expect(identical(once, options.runners), isTrue);
      expect(_labelOf(once, chosen), _labelOf(options.runners, chosen));
    }
  });

  test('test_describe_missing_target_label_property_runner_reads_offline', () {
    final Random random = seededRandom(54704);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = _buildOptions(
        random,
        const AnyFreeRunner(),
      );
      final SpecificRunner missing =
          _randomUnknownRunner(random) as SpecificRunner;

      final String label = _labelOf(
        options.listRunnerChoices(missing),
        missing,
      );

      final String name = _deviceNames.describeDevice(missing.deviceId);
      expect(label, '$name$_offlineSuffix');
    }
  });

  test('test_describe_missing_target_label_property_labels_never_offline', () {
    final Random random = seededRandom(54705);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> labels = _randomLabels(random);
      final RunnerTarget missing = RunnerWithLabels(labels);

      final String label = _labelOf(
        buildRunnerOptions(
          runners: const <Runner>[],
          deviceNames: _deviceNames,
          chosenTarget: missing,
        ),
        missing,
      );

      expect(label.endsWith(_offlineSuffix), isFalse);
      expect(label, contains(labels.join(', ')));
    }
  });

  test('test_describe_missing_target_label_property_no_labels_any_runner', () {
    final Random random = seededRandom(54706);

    for (int i = 0; i < propertyIterations; i += 1) {
      final TaskFormOptions options = _buildOptions(
        random,
        const AnyFreeRunner(),
      );
      final RunnerTarget missing = RunnerWithLabels(const <String>[]);

      final String label = _labelOf(
        options.listRunnerChoices(missing),
        missing,
      );

      expect(label, 'Any runner');
    }
  });
}
