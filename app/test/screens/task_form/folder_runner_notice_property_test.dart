import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/screens/task_form/folder_runner_notice.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/sample_runners.dart';
import 'task_form_scene.dart';

MissingFolderRunner _randomMissing(Random random) {
  return MissingFolderRunner(
    deviceName: randomHostileText(random),
    folderName: randomHostileText(random),
    projectName: randomHostileText(random),
  );
}

DeviceNames _randomDeviceNames(Random random) {
  return DeviceNames(<Device>[
    for (final Device device in galleryDevices)
      if (random.nextBool()) device,
  ]);
}

void main() {
  test('test_missing_folder_runner_constructor_property_keeps_fields', () {
    final Random random = seededRandom(1132201);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String deviceName = randomHostileText(random);
      final String folderName = randomHostileText(random);
      final String projectName = randomHostileText(random);

      final MissingFolderRunner missing = MissingFolderRunner(
        deviceName: deviceName,
        folderName: folderName,
        projectName: projectName,
      );

      expect(missing.deviceName, deviceName);
      expect(missing.folderName, folderName);
      expect(missing.projectName, projectName);
    }
  });

  test('test_missing_folder_runner_constructor_property_fields_never_mix', () {
    final Random random = seededRandom(1132202);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String shared = randomHostileText(random);

      final MissingFolderRunner missing = MissingFolderRunner(
        deviceName: 'device $shared',
        folderName: 'folder $shared',
        projectName: 'project $shared',
      );

      expect(missing.deviceName, startsWith('device '));
      expect(missing.folderName, startsWith('folder '));
      expect(missing.projectName, startsWith('project '));
    }
  });

  test('test_missing_folder_runner_constructor_property_is_constant', () {
    const MissingFolderRunner first = MissingFolderRunner(
      deviceName: 'air-laptop',
      folderName: 'billing-ui',
      projectName: 'billing',
    );
    const MissingFolderRunner second = MissingFolderRunner(
      deviceName: 'air-laptop',
      folderName: 'billing-ui',
      projectName: 'billing',
    );

    expect(identical(first, second), isTrue);
  });

  test('test_find_missing_folder_runner_property_matches_the_model', () {
    final Random random = seededRandom(1132204);
    for (int i = 0; i < propertyIterations; i += 1) {
      final FolderProject built = buildRandomFolderProject(
        random,
        pickOne(random, galleryProjects),
      );
      final DeviceNames deviceNames = _randomDeviceNames(random);
      final List<Runner> runners = randomRunnersOnDistinctDevices(random);
      final bool hasFolderRunner = runners.any(
        (Runner runner) => runner.deviceId == built.folderDeviceId,
      );

      final MissingFolderRunner? missing = findMissingFolderRunner(
        project: built.project,
        runners: runners,
        deviceNames: deviceNames,
      );

      expect(missing == null, hasFolderRunner);
      if (missing != null) {
        final String deviceName = deviceNames.describeDevice(
          built.folderDeviceId,
        );
        expect(missing.deviceName, deviceName);
        expect(missing.folderName, built.folderName);
        expect(missing.projectName, built.project.name);
      }
    }
  });

  test('test_find_missing_folder_runner_property_no_folder_needs_nothing', () {
    final Random random = seededRandom(1132205);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Project project = pickOne(random, galleryProjects);

      final MissingFolderRunner? missing = findMissingFolderRunner(
        project: project,
        runners: randomRunnersOnDistinctDevices(random),
        deviceNames: _randomDeviceNames(random),
      );

      expect(missing, isNull);
    }
  });

  test(
    'test_find_missing_folder_runner_property_only_the_folder_device_counts',
    () {
      final Random random = seededRandom(1132206);
      for (int i = 0; i < propertyIterations; i += 1) {
        final FolderProject built = buildRandomFolderProject(
          random,
          pickOne(random, galleryProjects),
        );
        final DeviceNames deviceNames = DeviceNames(galleryDevices);
        final List<Runner> otherRunners = <Runner>[
          for (final Runner runner in randomRunnersOnDistinctDevices(random))
            if (runner.deviceId != built.folderDeviceId) runner,
        ];
        final Runner folderRunner = buildOnlineRunnerOn(built.folderDeviceId);
        final List<Runner> withFolderRunner = <Runner>[
          ...otherRunners,
          if (random.nextBool()) folderRunner.asPaused() else folderRunner,
        ]..shuffle(random);

        final MissingFolderRunner? withoutRunner = findMissingFolderRunner(
          project: built.project,
          runners: otherRunners.reversed.toList(),
          deviceNames: deviceNames,
        );
        final MissingFolderRunner? withRunner = findMissingFolderRunner(
          project: built.project,
          runners: withFolderRunner,
          deviceNames: deviceNames,
        );

        expect(withoutRunner, isNotNull);
        expect(withRunner, isNull);
      }
    },
  );

  test('test_folder_runner_notice_constructor_property_keeps_the_record', () {
    final Random random = seededRandom(1132207);
    for (int i = 0; i < propertyIterations; i += 1) {
      final MissingFolderRunner missing = _randomMissing(random);

      final FolderRunnerNotice notice = FolderRunnerNotice(missing: missing);

      expect(notice.missing, same(missing));
    }
  });

  test(
    'test_folder_runner_notice_constructor_property_no_key_unless_given',
    () {
      final Random random = seededRandom(1132208);
      for (int i = 0; i < propertyIterations; i += 1) {
        final MissingFolderRunner missing = _randomMissing(random);

        expect(FolderRunnerNotice(missing: missing).key, isNull);
      }
    },
  );

  test('test_folder_runner_notice_constructor_property_keeps_the_key', () {
    final Random random = seededRandom(1132209);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(1000));

      final FolderRunnerNotice notice = FolderRunnerNotice(
        missing: _randomMissing(random),
        key: key,
      );

      expect(notice.key, key);
    }
  });
}
