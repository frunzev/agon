import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/files/repository_file_paths.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../data/repository/support/rust_repository_files_model.dart';
import '../../support/random_inputs.dart';

const String _separator = '/';
const List<String> _rawPathPieces = <String>[
  'src',
  'auth',
  '.github',
  'README.md',
  'a b',
  'Ünïcødé',
  '\u{1F600}',
  'e\u0301',
  '.',
  '..',
  '',
  '\\',
  '\u0000',
  '\u0085',
  ' ',
];
const int _largestRawPieceCount = 7;

String _randomRawPath(Random random) {
  final int pieceCount = random.nextInt(_largestRawPieceCount);
  final List<String> pieces = <String>[];
  for (int index = 0; index < pieceCount; index += 1) {
    if (random.nextInt(3) == 0) {
      pieces.add(randomHostileText(random));
    } else {
      pieces.add(pickOne(random, _rawPathPieces));
    }
  }
  final String path = pieces.join(_separator);
  return random.nextInt(6) == 0 ? '$_separator$path' : path;
}

String? _normalizeLikeTheNode(String rawPath) {
  try {
    return normalizeRepositoryFolderPath(rawPath);
  } on RustFileRefusal {
    return null;
  }
}

String _randomNormalizedFolder(Random random) {
  while (true) {
    final String? folder = _normalizeLikeTheNode(_randomRawPath(random));
    if (folder != null) {
      return folder;
    }
  }
}

String _randomNormalizedFilePath(Random random) {
  while (true) {
    final String folder = _randomNormalizedFolder(random);
    if (folder.isNotEmpty) {
      return folder;
    }
  }
}

String _randomAddressableName(Random random) {
  final String path = _randomNormalizedFilePath(random);
  final List<String> parts = path.split(_separator);
  return pickOne(random, parts);
}

(String, String) _splitLikeTheNode(String normalizedPath) {
  final int separatorIndex = normalizedPath.lastIndexOf(_separator);
  if (separatorIndex < 0) {
    return ('', normalizedPath);
  }
  return (
    normalizedPath.substring(0, separatorIndex),
    normalizedPath.substring(separatorIndex + 1),
  );
}

void main() {
  test('test_file_name_of_property_is_a_suffix_without_separators', () {
    final Random random = seededRandom(731001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String rawPath = _randomRawPath(random);
      final String name = fileNameOf(rawPath);

      expect(name.contains(_separator), isFalse, reason: rawPath);
      expect(rawPath.endsWith(name), isTrue, reason: rawPath);
    }
  });

  test('test_file_name_of_property_matches_the_node_split', () {
    final Random random = seededRandom(731002);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = _randomNormalizedFilePath(random);
      final (String _, String nodeName) = _splitLikeTheNode(path);
      final String name = fileNameOf(path);

      expect(name, nodeName, reason: path);
      expect(name, isNotEmpty, reason: path);
      expect(<String>['.', '..'].contains(name), isFalse, reason: path);
    }
  });

  test('test_file_name_of_property_is_idempotent', () {
    final Random random = seededRandom(731003);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String rawPath = _randomRawPath(random);
      final String name = fileNameOf(rawPath);

      expect(fileNameOf(name), name, reason: rawPath);
    }
  });

  test('test_parent_folder_of_property_is_a_proper_prefix_or_root', () {
    final Random random = seededRandom(731004);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = _randomNormalizedFilePath(random);
      final String parent = parentFolderOf(path);

      expect(parent.length, lessThan(path.length), reason: path);
      final bool isRootOrPrefix =
          parent.isEmpty || path.startsWith('$parent$_separator');
      expect(isRootOrPrefix, isTrue, reason: path);
    }
  });

  test('test_parent_folder_of_property_matches_the_node_split', () {
    final Random random = seededRandom(731005);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = _randomNormalizedFilePath(random);
      final (String nodeFolder, String _) = _splitLikeTheNode(path);

      expect(parentFolderOf(path), nodeFolder, reason: path);
    }
  });

  test('test_parent_folder_of_property_reaches_root_once_per_folder', () {
    final Random random = seededRandom(731006);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = _randomNormalizedFilePath(random);
      final int folderCount = path.split(_separator).length - 1;
      String folder = parentFolderOf(path);

      for (int step = 0; step < folderCount; step += 1) {
        expect(folder, isNotEmpty, reason: path);
        expect(normalizeRepositoryFolderPath(folder), folder, reason: path);
        folder = parentFolderOf(folder);
      }
      expect(folder, isEmpty, reason: path);
    }
  });

  test('test_join_repository_path_property_round_trips_parent_and_name', () {
    final Random random = seededRandom(731007);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String folder = _randomNormalizedFolder(random);
      final String name = _randomAddressableName(random);
      final String path = joinRepositoryPath(folder, name);

      expect(fileNameOf(path), name, reason: path);
      expect(parentFolderOf(path), folder, reason: path);
    }
  });

  test('test_join_repository_path_property_names_what_the_node_reads', () {
    final Random random = seededRandom(731008);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String folder = _randomNormalizedFolder(random);
      final String name = _randomAddressableName(random);
      final String path = joinRepositoryPath(folder, name);

      expect(normalizeRepositoryFolderPath(path), path, reason: path);
    }
  });

  test('test_join_repository_path_property_folds_segments_in_order', () {
    final Random random = seededRandom(731009);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> segments = _randomNormalizedFilePath(random)
          .split(_separator);
      String path = '';
      for (final String segment in segments) {
        path = joinRepositoryPath(path, segment);
      }

      expect(path, segments.join(_separator));
      expect(joinRepositoryPath('', segments.first), segments.first);
    }
  });

  test('test_list_ancestor_folders_property_chains_parent_folders', () {
    final Random random = seededRandom(731010);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = _randomNormalizedFilePath(random);
      final List<String> ancestors = listAncestorFolders(path);

      expect(ancestors.last, parentFolderOf(path), reason: path);
      for (int index = 1; index < ancestors.length; index += 1) {
        expect(parentFolderOf(ancestors[index]), ancestors[index - 1]);
      }
    }
  });

  test('test_list_ancestor_folders_property_folders_hold_the_path', () {
    final Random random = seededRandom(731011);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = _randomNormalizedFilePath(random);

      for (final String ancestor in listAncestorFolders(path)) {
        expect(normalizeRepositoryFolderPath(ancestor), ancestor);
        final bool holdsPath =
            ancestor.isEmpty || path.startsWith('$ancestor$_separator');
        expect(holdsPath, isTrue, reason: '$path in $ancestor');
      }
    }
  });

  test('test_list_ancestor_folders_property_start_at_root_and_grow', () {
    final Random random = seededRandom(731012);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = _randomNormalizedFilePath(random);
      final List<String> ancestors = listAncestorFolders(path);

      expect(ancestors.first, isEmpty, reason: path);
      for (int index = 1; index < ancestors.length; index += 1) {
        final int previousLength = ancestors[index - 1].length;
        expect(ancestors[index].length, greaterThan(previousLength));
      }
    }
  });

  test('test_describe_breadcrumb_property_one_crumb_per_ancestor', () {
    final Random random = seededRandom(731013);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = _randomNormalizedFilePath(random);
      final List<String> ancestors = listAncestorFolders(path);
      final List<String> crumbs = describeBreadcrumb('acme/app', path);

      expect(crumbs.length, ancestors.length, reason: path);
      for (int index = 1; index < crumbs.length; index += 1) {
        expect(crumbs[index], fileNameOf(ancestors[index]), reason: path);
      }
    }
  });

  test('test_describe_breadcrumb_property_keeps_the_repository_first', () {
    final Random random = seededRandom(731014);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String repositoryPath = randomHostileText(random);
      final String path = _randomNormalizedFilePath(random);
      final List<String> crumbs = describeBreadcrumb(repositoryPath, path);

      expect(crumbs.first, repositoryPath, reason: path);
      for (final String crumb in crumbs.skip(1)) {
        expect(crumb, isNotEmpty, reason: path);
      }
    }
  });

  test('test_describe_breadcrumb_property_folders_join_to_the_parent', () {
    final Random random = seededRandom(731015);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = _randomNormalizedFilePath(random);
      final List<String> crumbs = describeBreadcrumb('acme/api', path);

      expect(crumbs.skip(1).join(_separator), parentFolderOf(path));
      expect(crumbs.length, path.split(_separator).length, reason: path);
    }
  });
}
