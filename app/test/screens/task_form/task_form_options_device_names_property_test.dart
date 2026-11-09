import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/folder_runner_notice.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/screens/task_form/workflow_to_sign.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_runners.dart';

typedef _RenamedDevices = ({DeviceNames names, Map<DeviceId, String> byId});

Device _renameDevice(Device device, String name) {
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

_RenamedDevices _renameDevices(Random random) {
  final Map<DeviceId, String> byId = <DeviceId, String>{};
  final List<Device> renamed = <Device>[];
  for (final Device device in galleryDevices) {
    final String name = 'Name ${randomHostileText(random)} ${device.id.value}';
    byId[device.id] = name;
    renamed.add(_renameDevice(device, name));
  }
  return (names: DeviceNames(renamed), byId: byId);
}

TaskFormOptions _buildOptions({
  required List<Runner> runners,
  required DeviceNames deviceNames,
  required RunnerTarget chosenTarget,
}) {
  final AppDependencies dependencies = buildGalleryDependencies();
  return buildTaskFormOptions(
    projects: dependencies.projectRepository.listProjects(
      dependencies.workspaceRepository.currentWorkspace().id,
    ),
    workflows: dependencies.workflowRepository.listWorkflows(),
    findPendingChange: dependencies.workflowRepository.findPendingChange,
    runners: runners,
    deviceNames: deviceNames,
    skills: dependencies.skillRepository.listSkills(),
    chosenTarget: chosenTarget,
  );
}

RunnerTarget _randomSpecificTarget(Random random) {
  return SpecificRunner(pickOne(random, galleryDevices).id);
}

String _findLabel(List<SelectOption<RunnerTarget>> options, RunnerTarget t) {
  return options
      .singleWhere((SelectOption<RunnerTarget> option) => option.value == t)
      .label;
}

void main() {
  test('test_build_task_form_options_property_runners_match_the_builder', () {
    final Random random = seededRandom(53301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);
      final DeviceNames deviceNames = _renameDevices(random).names;
      final RunnerTarget chosenTarget = _randomSpecificTarget(random);

      final TaskFormOptions options = _buildOptions(
        runners: runners,
        deviceNames: deviceNames,
        chosenTarget: chosenTarget,
      );
      final List<SelectOption<RunnerTarget>> expected = buildRunnerOptions(
        runners: runners,
        deviceNames: deviceNames,
        chosenTarget: chosenTarget,
      );

      expect(options.runners.length, expected.length);
      for (int index = 0; index < expected.length; index += 1) {
        expect(options.runners[index].value, expected[index].value);
        expect(options.runners[index].label, expected[index].label);
      }
    }
  });

  test('test_build_task_form_options_property_keeps_the_device_names', () {
    final Random random = seededRandom(53302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceNames deviceNames = _renameDevices(random).names;

      final TaskFormOptions options = _buildOptions(
        runners: randomRunners(random),
        deviceNames: deviceNames,
        chosenTarget: const AnyFreeRunner(),
      );

      expect(identical(options.deviceNames, deviceNames), isTrue);
    }
  });

  test('test_build_task_form_options_property_choices_use_given_names', () {
    final Random random = seededRandom(53303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _RenamedDevices renamed = _renameDevices(random);
      final TaskFormOptions options = _buildOptions(
        runners: const <Runner>[],
        deviceNames: renamed.names,
        chosenTarget: const AnyFreeRunner(),
      );
      final Device device = pickOne(random, galleryDevices);
      final RunnerTarget shownTarget = SpecificRunner(device.id);

      final String label = _findLabel(
        options.listRunnerChoices(shownTarget),
        shownTarget,
      );

      expect(label, startsWith(renamed.byId[device.id]!));
    }
  });

  test('test_task_form_options_new_property_keeps_the_device_names', () {
    final Random random = seededRandom(53304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceNames deviceNames = _renameDevices(random).names;

      final TaskFormOptions options = TaskFormOptions(
        projects: const <SelectOption<ProjectId>>[],
        doers: const <SelectEntry<TaskDoer>>[],
        runners: const <SelectOption<RunnerTarget>>[],
        skills: const <Skill>[],
        missingFolderRunners: const <ProjectId, MissingFolderRunner>{},
        workflowsToSign: const <WorkflowId, WorkflowToSign>{},
        deviceNames: deviceNames,
      );

      expect(identical(options.deviceNames, deviceNames), isTrue);
    }
  });

  test('test_task_form_options_new_property_lists_are_its_own_copies', () {
    final Random random = seededRandom(53305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SelectOption<RunnerTarget>> runners =
          <SelectOption<RunnerTarget>>[
            for (int index = 0; index < random.nextInt(4); index += 1)
              SelectOption<RunnerTarget>(
                value: _randomSpecificTarget(random),
                label: 'Runner $index',
              ),
          ];
      final int lengthBefore = runners.length;
      final TaskFormOptions options = TaskFormOptions(
        projects: const <SelectOption<ProjectId>>[],
        doers: const <SelectEntry<TaskDoer>>[],
        runners: runners,
        skills: const <Skill>[],
        missingFolderRunners: const <ProjectId, MissingFolderRunner>{},
        workflowsToSign: const <WorkflowId, WorkflowToSign>{},
        deviceNames: _renameDevices(random).names,
      );

      runners.add(
        const SelectOption<RunnerTarget>(
          value: AnyFreeRunner(),
          label: 'late',
        ),
      );

      expect(options.runners.length, lengthBefore);
      expect(
        () => options.runners.add(runners.last),
        throwsA(isA<UnsupportedError>()),
      );
    }
  });

  test('test_task_form_options_new_property_unknown_device_reads_off', () {
    final Random random = seededRandom(53306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId unknown = DeviceId('device-${randomHostileText(random)}');
      final TaskFormOptions options = TaskFormOptions(
        projects: const <SelectOption<ProjectId>>[],
        doers: const <SelectEntry<TaskDoer>>[],
        runners: const <SelectOption<RunnerTarget>>[],
        skills: const <Skill>[],
        missingFolderRunners: const <ProjectId, MissingFolderRunner>{},
        workflowsToSign: const <WorkflowId, WorkflowToSign>{},
        deviceNames: DeviceNames(galleryDevices),
      );
      final RunnerTarget shownTarget = SpecificRunner(unknown);

      final List<SelectOption<RunnerTarget>> choices = options
          .listRunnerChoices(shownTarget);

      expect(choices, hasLength(1));
      expect(choices.single.value, shownTarget);
      expect(choices.single.label, endsWith(', offline'));
    }
  });
}
