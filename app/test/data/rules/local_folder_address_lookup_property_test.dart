import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';

import '../../support/random_inputs.dart';
import '../../support/random_repository_addresses.dart';
import 'support/random_local_folders.dart';

const List<String> _malformedLocalAddresses = <String>[
  'local:abc:relative/x',
  'local:ABC:/x',
  'local::/x',
  'local:abc:/a/../b',
  'local:abc:/',
  'local:abc',
];
final RegExp _folderSeparator = RegExp(r'[\\/]');

Repository _repositoryAt(String address) {
  return Repository(
    address: address,
    defaultBranch: 'main',
    agentAccess: AgentAccess.pushAfterApproval,
  );
}

String _randomRemoteAddress(Random random) {
  final String host = randomRepositoryHost(random);
  final String owner = randomPathPartWithoutGitSuffix(random);
  return '$host/$owner/${randomRepositoryName(random)}';
}

String _randomLocalAddress(Random random) {
  return renderLocalFolderAddress(
    deviceId: DeviceId(randomDeviceIdText(random)),
    path: randomNormalFolderPath(random),
  );
}

void main() {
  test('test_describe_folder_name_property_has_no_separator', () {
    final Random random = seededRandom(87201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> parts = randomFolderParts(random);
      final String path =
          '${randomFolderRoot(random)}${joinFolderParts(random, parts)}';

      final String folderName = describeFolderName(path);

      expect(folderName, parts.last);
      expect(folderName.contains(_folderSeparator), isFalse);
    }
  });

  test('test_describe_folder_name_property_ignores_trailing_separators', () {
    final Random random = seededRandom(87202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = randomNormalFolderPath(random);
      final String separators = pickOne(random, <String>['/', '\\', '//\\']);

      final String folderName = describeFolderName('$path$separators');

      expect(folderName, describeFolderName(path));
    }
  });

  test('test_looks_like_folder_path_property_renderable_paths_qualify', () {
    final Random random = seededRandom(87203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String path = randomNormalFolderPath(random);
      final String noise = pickOne(random, trailingFolderNoise);

      final bool looksLikeFolder = looksLikeFolderPath(' \u3000$path$noise');

      expect(looksLikeFolder, isTrue, reason: path);
    }
  });

  test('test_looks_like_folder_path_property_addresses_never_qualify', () {
    final Random random = seededRandom(87204);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String remoteAddress = _randomRemoteAddress(random);
      final String address = pickOne(random, <String>[
        remoteAddress,
        'https://$remoteAddress.git',
        _randomLocalAddress(random),
      ]);

      expect(looksLikeFolderPath(address), isFalse, reason: address);
    }
  });

  test('test_find_local_folder_property_none_without_local_folders', () {
    final Random random = seededRandom(87205);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int count = random.nextInt(4);
      final List<Repository> repositories = <Repository>[
        for (int j = 0; j < count; j += 1)
          _repositoryAt(_randomRemoteAddress(random)),
      ];

      expect(findLocalFolder(repositories), isNull);
    }
  });

  test('test_find_local_folder_property_skips_malformed_local_folders', () {
    final Random random = seededRandom(87206);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String malformed = pickOne(random, _malformedLocalAddresses);
      final String local = _randomLocalAddress(random);
      final List<Repository> repositories = <Repository>[
        _repositoryAt(malformed),
        _repositoryAt(_randomRemoteAddress(random)),
        _repositoryAt(local),
      ];

      final LocalFolderAddress? folder = findLocalFolder(repositories);

      final LocalFolderAddress expected = parseLocalFolderAddress(local)!;
      expect(folder?.deviceId, expected.deviceId);
      expect(folder?.path, expected.path);
    }
  });
}
