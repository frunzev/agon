import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_inputs.dart';
import '../support/random_repository_addresses.dart';
import '../support/sample_folder_paths.dart';

const String _hexDigits = '0123456789abcdef';
const String _ellipsis = '…';
const int _keptEndLength = 4;
const int _longestUnshortenedLength = 9;
const int _largestIdentifierLength = 48;
const List<String> _wideCharacters = <String>[
  '\u{1F600}',
  '\u{1F469}\u{200D}\u{1F4BB}',
  '\u{10400}',
  'é',
];

String _randomHexIdentifier(Random random, int length) {
  return randomCharacters(random, _hexDigits, length);
}

String _randomWideIdentifier(Random random) {
  final int count = random.nextInt(16);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < count; i += 1) {
    if (random.nextBool()) {
      buffer.write(pickOne(random, _wideCharacters));
    } else {
      buffer.write(randomHostileText(random));
    }
  }
  return buffer.toString();
}

bool _hasLoneSurrogate(String text) {
  for (final int rune in text.runes) {
    final bool isSurrogate = rune >= 0xD800 && rune <= 0xDFFF;
    if (isSurrogate) {
      return true;
    }
  }
  return false;
}

void main() {
  test('test_shorten_identifier_property_short_ones_stay_whole', () {
    final Random random = seededRandom(930201);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int length = random.nextInt(_longestUnshortenedLength + 1);
      final String identifier = _randomHexIdentifier(random, length);

      expect(shortenIdentifier(identifier), identifier);
    }
  });

  test('test_shorten_identifier_property_long_ones_keep_four_each_end', () {
    final Random random = seededRandom(930202);
    for (int i = 0; i < propertyIterations; i += 1) {
      final int length =
          _longestUnshortenedLength +
          1 +
          random.nextInt(_largestIdentifierLength);
      final String identifier = _randomHexIdentifier(random, length);

      final String shortened = shortenIdentifier(identifier);

      final String start = identifier.substring(0, _keptEndLength);
      final String end = identifier.substring(length - _keptEndLength);
      expect(shortened, '$start$_ellipsis$end');
      expect(shortened.length, _longestUnshortenedLength);
    }
  });

  test('test_shorten_identifier_property_is_idempotent', () {
    final Random random = seededRandom(930203);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String identifier = random.nextBool()
          ? _randomWideIdentifier(random)
          : _randomHexIdentifier(random, random.nextInt(40));

      final String shortened = shortenIdentifier(identifier);

      expect(shortenIdentifier(shortened), shortened);
    }
  });

  test('test_shorten_identifier_property_never_splits_a_character', () {
    final Random random = seededRandom(930204);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String identifier = _randomWideIdentifier(random);

      final String shortened = shortenIdentifier(identifier);

      expect(_hasLoneSurrogate(shortened), isFalse, reason: identifier);
      expect(shortened.runes.length <= identifier.runes.length, isTrue);
    }
  });

  test('test_describe_repository_path_property_any_host_is_dropped', () {
    final Random random = seededRandom(930205);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String host = randomRepositoryHost(random);
      final String owner = randomRepositoryName(random);
      final String name = randomRepositoryName(random);

      final String path = describeRepositoryPath('$host/$owner/$name');

      expect(path, '$owner/$name');
    }
  });

  test('test_describe_repository_path_property_folders_hide_the_device', () {
    final Random random = seededRandom(930206);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String deviceText = _randomHexIdentifier(random, 32);
      final String folderName = randomRepositoryName(random);
      final String address = renderLocalFolderAddress(
        deviceId: DeviceId(deviceText),
        path: buildTemporaryFolderPath('projects/$folderName'),
      );

      final String path = describeRepositoryPath(address);

      expect(path, folderName);
      expect(path, isNot(contains(localAddressPrefix)));
    }
  });

  test('test_describe_repository_path_property_short_texts_are_unchanged', () {
    final Random random = seededRandom(930207);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String first = randomHostileText(random).replaceAll('/', '');
      final String second = randomHostileText(random).replaceAll('/', '');
      final String address = random.nextBool() ? first : '$first/$second';
      if (address.startsWith(localAddressPrefix)) {
        continue;
      }

      expect(describeRepositoryPath(address), address);
    }
  });
}
