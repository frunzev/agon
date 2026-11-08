import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/local_folder_address.dart';

import '../../support/random_inputs.dart';
import 'support/random_local_folders.dart';

const List<String> _relativeStarts = <String>[
  '',
  '~/',
  '~',
  './',
  '../',
  '\\\\server\\',
  'C:',
  'C:relative',
  '1:/',
  'projects/',
];
const List<String> _surroundingWhiteSpace = <String>[
  '',
  ' ',
  '\t',
  ' ',
  '　',
  ' ',
];

void main() {
  test('test_is_absolute_folder_path_property_every_normal_path_is_'
      'absolute', () {
    final Random random = seededRandom(70511);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = random.nextBool()
          ? randomNormalFolderPath(random)
          : '${pickOne(random, _relativeStarts)}${randomText(random)}';

      if (normalizeFolderPath(path) != null) {
        expect(isAbsoluteFolderPath(path), isTrue, reason: path);
      }
    }
  });

  test('test_is_absolute_folder_path_property_relative_paths_are_not', () {
    final Random random = seededRandom(70512);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> parts = randomFolderParts(random);
      final String path =
          '${pickOne(random, _relativeStarts)}'
          '${joinFolderParts(random, parts)}';

      expect(isAbsoluteFolderPath(path), isFalse, reason: path);
      expect(normalizeFolderPath(path), isNull, reason: path);
    }
  });

  test('test_is_absolute_folder_path_property_ignores_surrounding_'
      'white_space', () {
    final Random random = seededRandom(70513);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = random.nextBool()
          ? randomNormalFolderPath(random)
          : '${pickOne(random, _relativeStarts)}${randomText(random)}';
      final String padded =
          '${pickOne(random, _surroundingWhiteSpace)}$path'
          '${pickOne(random, _surroundingWhiteSpace)}';

      expect(isAbsoluteFolderPath(padded), isAbsoluteFolderPath(path));
    }
  });
}
