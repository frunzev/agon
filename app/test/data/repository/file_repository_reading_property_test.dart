import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../support/random_inputs.dart';
import 'support/file_contract_rigs.dart';
import 'support/rust_repository_files_model.dart';

const String _typePrefix = 'test_file_repository';
const int _worldIterations = 60;
void main() {
  test('${_typePrefix}_read_file_property_every_implementation_reads_a_'
      'path_alike', () async {
    final Random random = seededRandom(85007);
    for (int i = 0; i < _worldIterations; i += 1) {
      final FileContractWorld world = buildEveryFileRepository(random);
      final String address = pickOne(random, fileContractAddresses);
      final String path = randomFilePathSpelling(random, world);

      final List<ReadOutcome> outcomes = <ReadOutcome>[
        for (final NamedFileRepository implementation in world.implementations)
          await readFileOn(implementation, address: address, path: path),
      ];

      for (final ReadOutcome outcome in outcomes) {
        expect(outcome.described, outcomes.first.described, reason: path);
        expect(outcome.failure == null, outcomes.first.failure == null);
        if (outcome.failure != null) {
          expect(outcome.failure, isA<StateError>(), reason: outcome.name);
        }
      }
    }
  });

  test('${_typePrefix}_read_file_property_reads_every_seeded_file_at_its_'
      'normalized_path', () async {
    final Random random = seededRandom(85008);
    for (int i = 0; i < _worldIterations; i += 1) {
      final FileContractWorld world = buildEveryFileRepository(random);

      for (final ModelFile file in world.files) {
        final String spelling = pickOne(random, <String>[
          file.path,
          './${file.path}',
          file.path.replaceAll('/', '/./'),
        ]);
        for (final NamedFileRepository implementation
            in world.implementations) {
          final ReadOutcome read = await readFileOn(
            implementation,
            address: file.address,
            path: spelling,
          );
          if (read.failure != null) {
            expect(read.failure, isA<StateError>());
            continue;
          }
          expect(read.described, startsWith('${file.path} ${file.size} '));
        }
      }
    }
  });

  test('${_typePrefix}_read_file_property_folders_and_escaping_paths_are_'
      'refused', () async {
    final Random random = seededRandom(85009);
    for (int i = 0; i < _worldIterations; i += 1) {
      final FileContractWorld world = buildEveryFileRepository(random);
      final String path = pickOne(random, <String>[
        ...folderSpellings,
        '../${randomText(random)}',
        '/etc/passwd',
      ]);

      for (final NamedFileRepository implementation in world.implementations) {
        final ReadOutcome read = await readFileOn(
          implementation,
          address: pickOne(random, fileContractAddresses),
          path: path,
        );

        expect(read.failure, isA<StateError>(), reason: implementation.name);
      }
    }
  });
}
