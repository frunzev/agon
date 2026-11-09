import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';

import '../../support/people_facing_refusal_matchers.dart';
import '../../support/random_inputs.dart';
import 'support/random_local_folders.dart';

const String _localPrefix = 'local:';
const List<String> _foreignDeviceCharacters = <String>[
  'A',
  '_',
  ':',
  ' ',
  'é',
  '/',
  '.',
];
const List<String> _reservedParts = <String>['.', '..', ''];
const List<String> _controlCharacters = <String>[
  '\u0000',
  '\u0007',
  '\n',
  '\t',
  '\u007F',
  '\u0085',
  '\u009F',
];
const List<String> _relativeStarts = <String>[
  'x/',
  '~/',
  '\\\\server\\',
  '1:\\',
  'C:',
  './',
  'local:',
];
const List<String> _bareRoots = <String>['/', 'C:\\', 'c:/', '/ //', 'Z:\\\\'];

DeviceId _randomDeviceId(Random random) {
  return DeviceId(randomDeviceIdText(random));
}

String _insertAt(Random random, String text, String insertion) {
  final int cut = random.nextInt(text.length + 1);
  return '${text.substring(0, cut)}$insertion${text.substring(cut)}';
}

String _render(DeviceId deviceId, String path) {
  return renderLocalFolderAddress(deviceId: deviceId, path: path);
}

void main() {
  test('test_local_folder_address_property_keeps_every_field', () {
    final Random random = seededRandom(87101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId deviceId = DeviceId(randomText(random));
      final String path = randomText(random);

      final LocalFolderAddress folder = LocalFolderAddress(
        deviceId: deviceId,
        path: path,
      );

      expect(folder.deviceId, deviceId);
      expect(folder.path, path);
    }
  });

  test('test_local_folder_address_property_parsed_parts_render_back', () {
    final Random random = seededRandom(87102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = _render(
        _randomDeviceId(random),
        randomNormalFolderPath(random),
      );

      final LocalFolderAddress folder = parseLocalFolderAddress(address)!;

      expect(_render(folder.deviceId, folder.path), address);
    }
  });

  test('test_local_folder_address_property_device_never_has_a_colon', () {
    final Random random = seededRandom(87103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address =
          '$_localPrefix${randomText(random)}:${randomText(random)}';

      final LocalFolderAddress? folder = parseLocalFolderAddress(address);

      expect(folder?.deviceId.value.contains(':') ?? false, isFalse);
    }
  });

  test('test_render_local_folder_address_property_refuses_bad_devices', () {
    final Random random = seededRandom(87104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String foreign = pickOne(random, _foreignDeviceCharacters);
      final String deviceText = random.nextInt(8) == 0
          ? ''
          : _insertAt(random, randomDeviceIdText(random), foreign);

      expect(
        () => _render(DeviceId(deviceText), randomNormalFolderPath(random)),
        throwsArgumentError,
        reason: deviceText,
      );
    }
  });

  test('test_normalize_folder_path_property_is_idempotent', () {
    final Random random = seededRandom(87105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId deviceId = _randomDeviceId(random);
      final String path = randomNormalFolderPath(random);
      final String noise = pickOne(random, trailingFolderNoise);
      final String noisyPath = ' \t$path$noise';

      final String once = parseLocalFolderAddress(
        _render(deviceId, noisyPath),
      )!.path;
      final String twice = parseLocalFolderAddress(_render(deviceId, once))!
          .path;

      expect(twice, once);
      expect(once, path);
    }
  });

  test('test_normalize_folder_path_property_drops_trailing_noise', () {
    final Random random = seededRandom(87106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId deviceId = _randomDeviceId(random);
      final String path = randomNormalFolderPath(random);
      final String noise = pickOne(random, trailingFolderNoise);

      final String address = _render(deviceId, '$path$noise');

      expect(address, '$_localPrefix${deviceId.value}:$path');
    }
  });

  test('test_normalize_folder_path_property_refuses_control_characters', () {
    final Random random = seededRandom(87107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String root = randomFolderRoot(random);
      final List<String> parts = randomFolderParts(random);
      final String control = pickOne(random, _controlCharacters);
      final String spoiled = 'a${control}b';
      final List<String> spoiledParts = <String>[...parts, spoiled, 'end'];
      final String path = '$root${joinFolderParts(random, spoiledParts)}';

      expect(
        () => _render(_randomDeviceId(random), path),
        throwsPeopleFacingRefusal,
        reason: path.runes.toString(),
      );
    }
  });

  test('test_find_folder_root_property_refuses_relative_paths', () {
    final Random random = seededRandom(87108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String start = pickOne(random, _relativeStarts);
      final String rest = joinFolderParts(random, randomFolderParts(random));
      final String path = '$start$rest';

      expect(
        () => _render(_randomDeviceId(random), path),
        throwsPeopleFacingRefusal,
        reason: path,
      );
      expect(parseLocalFolderAddress('${_localPrefix}abc:$path'), isNull);
    }
  });

  test('test_find_folder_root_property_keeps_the_root_spelling', () {
    final Random random = seededRandom(87109);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String root = randomFolderRoot(random);
      final String rest = joinFolderParts(random, randomFolderParts(random));

      final String address = _render(_randomDeviceId(random), '$root$rest');

      expect(parseLocalFolderAddress(address)!.path, startsWith(root));
    }
  });

  test('test_find_folder_root_property_refuses_a_bare_root', () {
    final Random random = seededRandom(87110);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String root = pickOne(random, _bareRoots);
      final String noise = pickOne(random, trailingFolderNoise);

      expect(
        () => _render(_randomDeviceId(random), '$root$noise'),
        throwsPeopleFacingRefusal,
        reason: '$root$noise',
      );
    }
  });

  test('test_is_unsafe_folder_part_property_refuses_reserved_parts', () {
    final Random random = seededRandom(87111);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> parts = randomFolderParts(random);
      final int position = random.nextInt(parts.length);
      final List<String> spoiledParts = <String>[
        ...parts.sublist(0, position),
        pickOne(random, _reservedParts),
        ...parts.sublist(position),
      ];
      final String root = randomFolderRoot(random);
      final String path = '$root${joinFolderParts(random, spoiledParts)}';
      final bool isOnlyTrailingEmpty =
          spoiledParts.last.isEmpty && position == parts.length;
      if (isOnlyTrailingEmpty) {
        continue;
      }

      expect(
        () => _render(_randomDeviceId(random), path),
        throwsPeopleFacingRefusal,
        reason: path,
      );
    }
  });

  test('test_is_unsafe_folder_part_property_accepts_dotted_names', () {
    final Random random = seededRandom(87112);
    final List<String> dottedNames = <String>[
      '...',
      '.a',
      'a.',
      'a..b',
      '. .',
    ];

    for (int i = 0; i < propertyIterations; i += 1) {
      final String root = randomFolderRoot(random);
      final List<String> parts = <String>[
        ...randomFolderParts(random),
        pickOne(random, dottedNames),
        'end',
      ];
      final String path = '$root${joinFolderParts(random, parts)}';

      final String address = _render(_randomDeviceId(random), path);

      expect(parseLocalFolderAddress(address)!.path, path);
    }
  });

  test('test_is_unsafe_folder_part_property_never_parses_reserved_parts', () {
    final Random random = seededRandom(87113);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String root = randomFolderRoot(random);
      final String address = '${_localPrefix}abc:$root${randomText(random)}';

      final LocalFolderAddress? folder = parseLocalFolderAddress(address);
      if (folder == null) {
        continue;
      }

      final List<String> parts = folder.path
          .substring(1)
          .split(RegExp(r'[\\/]'));
      expect(parts.contains('.'), isFalse, reason: address);
      expect(parts.contains('..'), isFalse, reason: address);
    }
  });
}
