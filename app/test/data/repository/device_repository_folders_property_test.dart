import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';

import '../../support/random_inputs.dart';
import 'support/contract_step_failures.dart';
import 'support/device_contract_rigs.dart';
import 'support/folder_path_inputs.dart';
import 'support/rust_local_folder_model.dart';

const String _typePrefix = 'test_device_repository';
const int _worldIterations = 30;
typedef _FolderOutcome = ({
  String name,
  Object? failure,
  CheckedFolder? folder,
});

typedef _FolderProjection = ({
  String address,
  String defaultBranch,
  bool hasStartedGit,
});

_FolderProjection? _projectFolder(CheckedFolder? folder) {
  if (folder == null) {
    return null;
  }
  return (
    address: folder.repository.address,
    defaultBranch: folder.repository.defaultBranch,
    hasStartedGit: folder.hasStartedGit,
  );
}

Future<List<_FolderOutcome>> _onEvery(
  DeviceContractWorld world,
  Future<CheckedFolder> Function(NamedDeviceRepository implementation) step,
) async {
  final List<_FolderOutcome> outcomes = <_FolderOutcome>[];
  for (final NamedDeviceRepository implementation in world.implementations) {
    CheckedFolder? folder;
    final Object? failure = await findStepFailure(() async {
      folder = await step(implementation);
    });
    outcomes.add((
      name: implementation.name,
      failure: failure,
      folder: folder,
    ));
  }
  return outcomes;
}

void _expectOutcomesAgree(List<_FolderOutcome> outcomes, String input) {
  final _FolderOutcome first = outcomes.first;
  for (final _FolderOutcome outcome in outcomes) {
    expect(
      outcome.failure == null,
      first.failure == null,
      reason: '${outcome.name} ${outcome.failure} for "$input"',
    );
    if (outcome.failure != null) {
      expect(isContractRefusal(outcome.failure), isTrue);
    }
    expect(
      _projectFolder(outcome.folder),
      _projectFolder(first.folder),
      reason: '${outcome.name} for "$input"',
    );
  }
}

void main() {
  test('${_typePrefix}_check_local_folder_property_every_implementation_'
      'judges_a_path_alike', () async {
    final Random random = seededRandom(84901);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildEveryDeviceRepository(
        random,
        gitlessFolderPaths: randomGitlessFolderPaths(random),
      );

      for (int index = 0; index < folderPathsPerWorld; index += 1) {
        final String path = randomFolderPathInput(random);
        final List<_FolderOutcome> outcomes = await _onEvery(
          world,
          (NamedDeviceRepository implementation) =>
              implementation.repository.checkLocalFolder(path),
        );
        _expectOutcomesAgree(outcomes, path);
      }
    }
  });

  test('${_typePrefix}_check_local_folder_property_git_is_started_only_by_'
      'the_first_check', () async {
    final Random random = seededRandom(84902);
    for (int i = 0; i < _worldIterations; i += 1) {
      final Set<String> gitless = randomGitlessFolderPaths(random);
      final DeviceContractWorld world = await buildEveryDeviceRepository(
        random,
        gitlessFolderPaths: gitless,
      );

      for (final String folderPath in gitless) {
        for (final NamedDeviceRepository implementation
            in world.implementations) {
          final CheckedFolder first = await implementation.repository
              .checkLocalFolder(folderPath);
          final CheckedFolder second = await implementation.repository
              .checkLocalFolder(folderPath);

          expect(first.hasStartedGit, isTrue, reason: implementation.name);
          expect(second.hasStartedGit, isFalse, reason: implementation.name);
        }
      }
    }
  });

  test('${_typePrefix}_check_local_folder_property_checking_the_checked_'
      'path_again_keeps_the_address', () async {
    final Random random = seededRandom(84903);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildEveryDeviceRepository(
        random,
        gitlessFolderPaths: const <String>{},
      );
      final String path = randomFolderPathInput(random);

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        final StepOutcome<CheckedFolder> checking = await runContractStep(
          () => implementation.repository.checkLocalFolder(path),
        );
        final CheckedFolder? first = checking.value;
        if (first == null) {
          expect(isContractRefusal(checking.failure), isTrue);
          continue;
        }
        final String checkedPath = parseLocalFolderAddress(
          first.repository.address,
        )!.path;

        final CheckedFolder again = await implementation.repository
            .checkLocalFolder(checkedPath);

        expect(again.repository.address, first.repository.address);
      }
    }
  });

  test('${_typePrefix}_create_local_folder_property_every_implementation_'
      'judges_a_new_folder_alike', () async {
    final Random random = seededRandom(84904);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildEveryDeviceRepository(
        random,
        gitlessFolderPaths: const <String>{},
      );

      for (int index = 0; index < folderPathsPerWorld; index += 1) {
        final String parent = randomFolderPathInput(random);
        final String name = pickOne(random, folderNameInputs);
        final List<_FolderOutcome> outcomes = await _onEvery(
          world,
          (NamedDeviceRepository implementation) => implementation.repository
              .createLocalFolder(parent: parent, name: name),
        );
        _expectOutcomesAgree(outcomes, '$parent + $name');
      }
    }
  });

  test('${_typePrefix}_create_local_folder_property_the_same_folder_is_'
      'created_once', () async {
    final Random random = seededRandom(84905);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildEveryDeviceRepository(
        random,
        gitlessFolderPaths: const <String>{},
      );
      final String parent = '/home/${randomWordPhrase(random)}x';
      final String name = 'made-${random.nextInt(1 << 30)}';

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        await implementation.repository.createLocalFolder(
          parent: parent,
          name: name,
        );

        final Object? failure = await findStepFailure(
          () => implementation.repository.createLocalFolder(
            parent: parent,
            name: name,
          ),
        );

        expect(failure, isA<StateError>(), reason: implementation.name);
      }
    }
  });

  test('${_typePrefix}_create_local_folder_property_the_new_folder_sits_'
      'in_its_parent_with_git_started_once', () async {
    final Random random = seededRandom(84906);
    for (int i = 0; i < _worldIterations; i += 1) {
      final DeviceContractWorld world = await buildEveryDeviceRepository(
        random,
        gitlessFolderPaths: const <String>{},
      );
      final String parent = randomFolderPathInput(random);
      final String name = 'made ${random.nextInt(1 << 30)}';

      for (final NamedDeviceRepository implementation
          in world.implementations) {
        final StepOutcome<CheckedFolder> creating = await runContractStep(
          () => implementation.repository.createLocalFolder(
            parent: parent,
            name: name,
          ),
        );
        final CheckedFolder? created = creating.value;
        if (created == null) {
          expect(isContractRefusal(creating.failure), isTrue);
          continue;
        }
        final String createdPath = parseLocalFolderAddress(
          created.repository.address,
        )!.path;
        final CheckedFolder checked = await implementation.repository
            .checkLocalFolder(createdPath);

        expect(createdPath, '${normalizeRustFolderPath(parent)}/$name');
        expect(created.hasStartedGit, isTrue, reason: implementation.name);
        expect(checked.hasStartedGit, isFalse, reason: implementation.name);
      }
    }
  });
}
