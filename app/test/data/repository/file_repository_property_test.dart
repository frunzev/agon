import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';

import '../../support/random_inputs.dart';
import 'support/contract_step_failures.dart';
import 'support/file_contract_rigs.dart';
import 'support/rust_repository_files_model.dart';

const String _typePrefix = 'test_file_repository';
const int _worldIterations = 60;
void main() {
  test('${_typePrefix}_open_repository_property_every_implementation_'
      'opens_a_repository_alike', () async {
    final Random random = seededRandom(85001);
    for (int i = 0; i < _worldIterations; i += 1) {
      final FileContractWorld world = buildEveryFileRepository(random);
      final String address = pickOne(random, <String>[
        ...fileContractAddresses,
        'unknown ${randomText(random)}',
      ]);
      final List<String> described = <String>[];

      for (final NamedFileRepository implementation in world.implementations) {
        final RepositoryFileSource source = await implementation.repository
            .openRepository(
              projectId: ProjectId(randomText(random)),
              repositoryAddress: address,
              preferredRunnerId: random.nextBool()
                  ? null
                  : DeviceId(randomText(random)),
            );
        described.add(describeSource(source));
      }

      expect(described.toSet(), hasLength(1), reason: address);
    }
  });

  test('${_typePrefix}_open_repository_property_an_unknown_repository_has_'
      'no_runner_and_no_holders', () async {
    final Random random = seededRandom(85002);
    for (int i = 0; i < _worldIterations; i += 1) {
      final FileContractWorld world = buildEveryFileRepository(random);

      for (final NamedFileRepository implementation in world.implementations) {
        final RepositoryFileSource source = await implementation.repository
            .openRepository(
              projectId: const ProjectId('contract-project'),
              repositoryAddress: 'never-configured-${random.nextInt(99)}',
              preferredRunnerId: null,
            );

        expect(source, isA<FilesWithoutRunner>(), reason: implementation.name);
        expect((source as FilesWithoutRunner).holders, isEmpty);
      }
    }
  });

  test('${_typePrefix}_open_repository_property_opening_twice_agrees_and_'
      'callers_cannot_change_the_branches', () async {
    final Random random = seededRandom(85003);
    for (int i = 0; i < _worldIterations; i += 1) {
      final FileContractWorld world = buildEveryFileRepository(random);
      final String address = pickOne(random, fileContractAddresses);

      for (final NamedFileRepository implementation in world.implementations) {
        Future<RepositoryFileSource> open() {
          return implementation.repository.openRepository(
            projectId: const ProjectId('contract-project'),
            repositoryAddress: address,
            preferredRunnerId: null,
          );
        }

        final RepositoryFileSource first = await open();
        if (first is FilesFromRunner) {
          final Object? failure = await findStepFailure(() async {
            first.branches.clear();
          });
          expect(failure, isA<UnsupportedError>());
        }
        final RepositoryFileSource second = await open();

        expect(describeSource(second), describeSource(first));
      }
    }
  });

  test('${_typePrefix}_list_folder_property_every_implementation_lists_a_'
      'folder_alike', () async {
    final Random random = seededRandom(85004);
    for (int i = 0; i < _worldIterations; i += 1) {
      final FileContractWorld world = buildEveryFileRepository(random);
      final String address = pickOne(random, fileContractAddresses);
      final String folder = randomFolderSpelling(random, world);

      final List<List<EntryProjection>?> listed = <List<EntryProjection>?>[
        for (final NamedFileRepository implementation in world.implementations)
          await listFolderOn(
            implementation.repository,
            address: address,
            folder: folder,
          ),
      ];

      for (final List<EntryProjection>? entries in listed) {
        expect(entries, listed.first, reason: 'folder "$folder"');
      }
    }
  });

  test('${_typePrefix}_list_folder_property_every_listed_entry_can_be_'
      'opened', () async {
    final Random random = seededRandom(85005);
    for (int i = 0; i < _worldIterations; i += 1) {
      final FileContractWorld world = buildEveryFileRepository(random);
      final String address = pickOne(random, fileContractAddresses);
      final String folder = randomFolderSpelling(random, world);

      for (final NamedFileRepository implementation in world.implementations) {
        final List<EntryProjection>? entries = await listFolderOn(
          implementation.repository,
          address: address,
          folder: folder,
        );
        if (entries == null) {
          continue;
        }
        final String base = normalizeRepositoryFolderPath(folder);
        for (final EntryProjection entry in entries) {
          final String path = base.isEmpty
              ? entry.name
              : '$base/${entry.name}';
          if (entry.kind == RepositoryEntryKind.folder) {
            final List<EntryProjection>? inside = await listFolderOn(
              implementation.repository,
              address: address,
              folder: path,
            );
            expect(inside, isNotNull, reason: '${implementation.name} $path');
            continue;
          }
          final ReadOutcome read = await readFileOn(
            implementation,
            address: address,
            path: path,
          );
          expect(read.failure, isNull, reason: '${implementation.name} $path');
        }
      }
    }
  });

  test('${_typePrefix}_list_folder_property_folders_come_first_and_names_'
      'are_unique', () async {
    final Random random = seededRandom(85006);
    for (int i = 0; i < _worldIterations; i += 1) {
      final FileContractWorld world = buildEveryFileRepository(random);
      final String address = pickOne(random, fileContractAddresses);
      final String folder = randomFolderSpelling(random, world);

      for (final NamedFileRepository implementation in world.implementations) {
        final List<EntryProjection> entries =
            await listFolderOn(
              implementation.repository,
              address: address,
              folder: folder,
            ) ??
            <EntryProjection>[];
        final List<bool> isFolder = <bool>[
          for (final EntryProjection entry in entries)
            entry.kind == RepositoryEntryKind.folder,
        ];

        expect(
          isFolder,
          orderedEquals(List<bool>.of(isFolder)..sort(_trueFirst)),
        );
        expect(
          entries.map((EntryProjection entry) => entry.name).toSet(),
          hasLength(entries.length),
          reason: implementation.name,
        );
      }
    }
  });
}

int _trueFirst(bool first, bool second) {
  if (first == second) {
    return 0;
  }
  return first ? -1 : 1;
}
