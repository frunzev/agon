import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';

import '../../support/random_inputs.dart';
import '../../support/random_repository_addresses.dart';
import 'support/random_local_folders.dart';

const String _modelPathCharacters = 'abcXYZ019._-é /:@\u00A0\uFEFF';
final RegExp _pathPartCharacters = RegExp(r'^[A-Za-z0-9._-]+$');
const List<String> _reservedParts = <String>['.', '..'];
const List<String> _malformedLocalTails = <String>[
  'abc:relative',
  'ABC:/x',
  ':/x',
  'abc:/a/./b',
  'abc:/',
  'abc',
  'abc:/a\u0000b',
];

String _randomLocalAddress(Random random) {
  return renderLocalFolderAddress(
    deviceId: DeviceId(randomDeviceIdText(random)),
    path: randomNormalFolderPath(random),
  );
}

bool _isPathPartByModel(String part) {
  final bool isReserved = _reservedParts.contains(part);
  return !isReserved && _pathPartCharacters.hasMatch(part);
}

void main() {
  test('test_canonicalize_local_address_property_round_trips', () {
    final Random random = seededRandom(87301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = _randomLocalAddress(random);

      expect(parseRepositoryAddress(address), address);
    }
  });

  test('test_canonicalize_local_address_property_is_idempotent', () {
    final Random random = seededRandom(87302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String deviceText = randomDeviceIdText(random);
      final String path = randomNormalFolderPath(random);
      final String noise = pickOne(random, trailingFolderNoise);
      final String noisy = ' local:$deviceText: $path$noise\u3000';

      final String? canonical = parseRepositoryAddress(noisy);

      expect(canonical, 'local:$deviceText:$path', reason: noisy);
      expect(parseRepositoryAddress(canonical!), canonical);
    }
  });

  test('test_canonicalize_local_address_property_refuses_malformed', () {
    final Random random = seededRandom(87303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String tail = random.nextBool()
          ? pickOne(random, _malformedLocalTails)
          : 'abc:${randomText(random)}';
      final String address = 'local:$tail';

      final String? canonical = parseRepositoryAddress(address);
      final bool isFolder = parseLocalFolderAddress(address) != null;

      expect(canonical != null, isFolder, reason: address);
    }
  });

  test('test_is_path_part_property_matches_the_character_model', () {
    final Random random = seededRandom(87304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final int length = random.nextInt(6);
      final String owner = randomCharacters(
        random,
        _modelPathCharacters,
        length,
      );

      final String? canonical = parseRepositoryAddress(
        'github.com/$owner/app',
      );

      final String? expected = _isPathPartByModel(owner)
          ? 'github.com/$owner/app'
          : null;
      expect(canonical, expected, reason: owner.runes.toString());
    }
  });

  test('test_is_path_part_property_refuses_reserved_parts', () {
    final Random random = seededRandom(87305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String reserved = pickOne(random, _reservedParts);
      final String name = randomPathPartWithoutGitSuffix(random);
      final String host = randomRepositoryHost(random);
      final String address = random.nextBool()
          ? '$host/$reserved/$name'
          : 'https://$host/$name/$reserved';

      expect(parseRepositoryAddress(address), isNull, reason: address);
    }
  });

  test('test_is_path_part_property_keeps_letter_case', () {
    final Random random = seededRandom(87306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String owner = scrambleLetterCase(
        random,
        randomPathPartWithoutGitSuffix(random),
      );
      final String name = scrambleLetterCase(
        random,
        randomPathPartWithoutGitSuffix(random),
      );

      final String? canonical = parseRepositoryAddress(
        'git@github.com:$owner/$name',
      );

      expect(canonical, 'github.com/$owner/$name');
    }
  });

  test('test_parse_repository_address_property_refuses_byte_order_marks', () {
    final Random random = seededRandom(87307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String host = randomRepositoryHost(random);
      final String name = randomPathPartWithoutGitSuffix(random);
      final String address = '$host/acme/$name';
      final String marked = random.nextBool()
          ? '\uFEFF$address'
          : '$address\uFEFF';

      expect(parseRepositoryAddress(marked), isNull, reason: marked);
      expect(parseRepositoryAddress(' $address '), address);
    }
  });
}
