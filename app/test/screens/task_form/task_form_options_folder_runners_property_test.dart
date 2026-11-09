import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/gallery/gallery_workflows.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/folder_runner_notice.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_runners.dart';
import '../../support/workflow_repositories.dart';
import 'task_form_scene.dart';

typedef _FolderScene = ({
  List<Project> projects,
  Map<ProjectId, DeviceId> folderDevices,
});

final DeviceNames _galleryDeviceNames = DeviceNames(galleryDevices);

_FolderScene _randomFolderScene(Random random) {
  final List<Project> projects = <Project>[];
  final Map<ProjectId, DeviceId> folderDevices = <ProjectId, DeviceId>{};
  for (final Project template in galleryProjects) {
    if (random.nextBool()) {
      projects.add(template);
      continue;
    }
    final FolderProject built = buildRandomFolderProject(random, template);
    projects.add(built.project);
    folderDevices[template.id] = built.folderDeviceId;
  }
  return (projects: projects, folderDevices: folderDevices);
}

Map<ProjectId, MissingFolderRunner> _findMissing(
  List<Project> projects,
  List<Runner> runners,
) {
  return buildTaskFormOptions(
    projects: projects,
    workflows: galleryWorkflows,
    findPendingChange: buildGalleryWorkflowRepository().findPendingChange,
    runners: runners,
    deviceNames: _galleryDeviceNames,
    skills: gallerySkills,
    chosenTarget: const AnyFreeRunner(),
  ).missingFolderRunners;
}

void main() {
  test('test_find_missing_folder_runners_property_one_per_project', () {
    final Random random = seededRandom(1132401);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _FolderScene scene = _randomFolderScene(random);
      final List<Runner> runners = randomRunnersOnDistinctDevices(random);

      final Map<ProjectId, MissingFolderRunner> missing = _findMissing(
        scene.projects,
        runners,
      );

      for (final Project project in scene.projects) {
        final MissingFolderRunner? expected = findMissingFolderRunner(
          project: project,
          runners: runners,
          deviceNames: _galleryDeviceNames,
        );
        final MissingFolderRunner? found = missing[project.id];
        expect(found == null, expected == null);
        expect(found?.deviceName, expected?.deviceName);
        expect(found?.folderName, expected?.folderName);
        expect(found?.projectName, expected?.projectName);
      }
      expect(
        missing.keys.toSet().difference(scene.folderDevices.keys.toSet()),
        isEmpty,
      );
    }
  });

  test('test_find_missing_folder_runners_property_a_new_runner_clears', () {
    final Random random = seededRandom(1132402);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _FolderScene scene = _randomFolderScene(random);
      final List<Runner> runners = randomRunnersOnDistinctDevices(random);
      final Map<ProjectId, MissingFolderRunner> before = _findMissing(
        scene.projects,
        runners,
      );
      if (before.isEmpty) {
        continue;
      }
      final DeviceId newRunnerDevice =
          scene.folderDevices[pickOne(random, before.keys.toList())]!;

      final Map<ProjectId, MissingFolderRunner> after = _findMissing(
        scene.projects,
        <Runner>[...runners, buildOnlineRunnerOn(newRunnerDevice)],
      );

      final Set<ProjectId> expected = <ProjectId>{
        for (final ProjectId projectId in before.keys)
          if (scene.folderDevices[projectId] != newRunnerDevice) projectId,
      };
      expect(after.keys.toSet(), expected);
    }
  });

  test('test_find_missing_folder_runners_property_is_read_only', () {
    final Random random = seededRandom(1132403);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _FolderScene scene = _randomFolderScene(random);

      final Map<ProjectId, MissingFolderRunner> missing = _findMissing(
        scene.projects,
        const <Runner>[],
      );

      expect(missing.keys.toSet(), scene.folderDevices.keys.toSet());
      expect(
        () => missing[pickOne(random, galleryProjects).id] =
            const MissingFolderRunner(
              deviceName: 'device',
              folderName: 'folder',
              projectName: 'project',
            ),
        throwsUnsupportedError,
      );
    }
  });
}
