import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';

import '../../support/random_inputs.dart';
import '../../support/random_repository_addresses.dart';

const List<String> _schemes = <String>['https://', 'HTTPS://', 'Https://', ''];
const List<String> _userParts = <String>[
  'user:ghp_secret',
  'x-access-token:abc123',
  'ghp_token',
  'git',
  'deploy',
  'a@b',
];

String _randomCanonical(Random random) {
  final String host = randomRepositoryHost(random);
  final String owner = randomPathPartWithoutGitSuffix(random);
  final String name = randomPathPartWithoutGitSuffix(random);
  return '$host/$owner/$name';
}

void main() {
  test('test_holds_repository_credentials_property_user_before_host', () {
    final Random random = seededRandom(1061301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String scheme = pickOne(random, _schemes);
      final String user = pickOne(random, _userParts);
      final bool isSecureShellSpelling = scheme.isEmpty && user == 'git';
      if (isSecureShellSpelling) {
        continue;
      }
      final String address = ' $scheme$user@${_randomCanonical(random)} ';

      expect(holdsRepositoryCredentials(address), isTrue, reason: address);
      expect(parseRepositoryAddress(address), isNull, reason: address);
    }
  });

  test('test_holds_repository_credentials_property_valid_addresses_hold_'
      'none', () {
    final Random random = seededRandom(1061302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String canonical = _randomCanonical(random);
      final List<String> parts = canonical.split('/');
      final String path = parts.skip(1).join('/');
      final String secureShell = 'git@${parts.first}:$path';
      final String hosted = '${pickOne(random, _schemes)}$canonical';

      expect(holdsRepositoryCredentials(hosted), isFalse, reason: hosted);
      expect(holdsRepositoryCredentials(secureShell), isFalse);
      expect(parseRepositoryAddress(secureShell), isNotNull);
    }
  });

  test('test_holds_repository_credentials_property_only_the_host_counts', () {
    final Random random = seededRandom(1061303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String host = randomRepositoryHost(random);
      final String inPath = 'https://$host/ow@ner/app';
      final String folder = renderLocalFolderAddress(
        deviceId: DeviceId('device-${random.nextInt(99)}'),
        path: '/work/a@b${random.nextInt(9)}',
      );
      final String unsupported = 'http://user:token@$host/owner/app';

      expect(holdsRepositoryCredentials(inPath), isFalse, reason: inPath);
      expect(holdsRepositoryCredentials(folder), isFalse, reason: folder);
      expect(holdsRepositoryCredentials(unsupported), isFalse);
      final String withoutParts = randomText(random).replaceAll('/', '');
      expect(holdsRepositoryCredentials(withoutParts), isFalse);
    }
  });

  test('test_split_hosted_address_property_needs_exactly_three_parts', () {
    final Random random = seededRandom(1061304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String canonical = _randomCanonical(random);
      final String extra = pickOne(random, <String>['/more', '/a/b', '']);
      final String short = canonical.substring(0, canonical.lastIndexOf('/'));
      final String address = extra.isEmpty
          ? 'u@$short'
          : 'u@$canonical$extra';

      expect(parseRepositoryAddress(address), isNull, reason: address);
      expect(holdsRepositoryCredentials(address), isFalse, reason: address);
    }
  });

  test('test_split_hosted_address_property_ignores_trailing_slashes_and_'
      'suffixes', () {
    final Random random = seededRandom(1061305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String canonical = _randomCanonical(random);
      final String slashes = '/' * random.nextInt(3);
      final String suffixes = '.git' * random.nextInt(3);
      final String padded = '$canonical$suffixes$slashes';

      expect(parseRepositoryAddress(padded), parseRepositoryAddress(canonical));
      expect(holdsRepositoryCredentials('t@$padded'), isTrue, reason: padded);
    }
  });

  test('test_split_hosted_address_property_secure_shell_matches_https', () {
    final Random random = seededRandom(1061306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String canonical = _randomCanonical(random);
      final List<String> parts = canonical.split('/');
      final String path = parts.skip(1).join('/');

      final String? secureShell = parseRepositoryAddress(
        'git@${parts.first}:$path',
      );

      expect(secureShell, parseRepositoryAddress('https://$canonical'));
      expect(secureShell, canonical);
    }
  });
}
