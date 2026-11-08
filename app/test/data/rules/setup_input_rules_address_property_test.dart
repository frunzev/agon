import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/setup_input_rules.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

const String _enterProblem = 'Enter the app server address';
const String _schemeProblem =
    'Start the address with https://, http:// or peer://';
const String _peerLinkLabel = 'peer link ';
const int _shownPeerKeyLength = 8;
const int _largestPort = 65535;
const int _longestPeerKey = 64;
const int _mostWhiteSpacePieces = 3;
const int _secretSpan = 1 << 30;
const List<String> _knownSchemes = <String>['https', 'http', 'peer'];
const List<String> _otherSchemes = <String>['ftp', 'ws', 'file', 'mailto'];
const List<String> _sampleHosts = <String>[
  'relay.acme.dev',
  'localhost',
  '10.0.0.7',
  '[::1]',
  'pair.example.org',
];
const List<String> _whiteSpace = <String>[
  '',
  ' ',
  '\t',
  '\n',
  '\u00a0',
  '\u2003',
  '\u3000',
];
const String _hexadecimalDigits = '0123456789abcdef';

String _randomHost(Random random) => pickOne(random, _sampleHosts);

String _randomWhiteSpace(Random random) {
  final int count = random.nextInt(_mostWhiteSpacePieces);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < count; i += 1) {
    buffer.write(pickOne(random, _whiteSpace));
  }
  return buffer.toString();
}

String _randomPeerKey(Random random) {
  final int length = 1 + random.nextInt(_longestPeerKey);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    final int digit = random.nextInt(_hexadecimalDigits.length);
    buffer.write(_hexadecimalDigits[digit]);
  }
  return buffer.toString();
}

String _randomSecret(Random random) {
  return 'secret${random.nextInt(_secretSpan)}';
}

void main() {
  test('test_parse_server_address_property_needs_a_known_scheme_and_a_'
      'host', () {
    final Random random = seededRandom(89101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool usesKnownScheme = random.nextBool();
      final String scheme = usesKnownScheme
          ? pickOne(random, _knownSchemes)
          : pickOne(random, _otherSchemes);
      final bool hasHost = random.nextBool();
      final String host = hasHost ? _randomHost(random) : '';

      final String? problem = describeServerAddressProblem('$scheme://$host');

      expect(problem == null, usesKnownScheme && hasHost, reason: scheme);
    }
  });

  test('test_parse_server_address_property_surrounding_white_space_is_'
      'ignored', () {
    final Random random = seededRandom(89102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address =
          '${pickOne(random, _knownSchemes)}://${_randomHost(random)}';
      final String padded =
          '${_randomWhiteSpace(random)}$address${_randomWhiteSpace(random)}';

      expect(describeServerAddressProblem(padded), isNull, reason: padded);
      expect(describeServerHost(padded), describeServerHost(address));
    }
  });

  test('test_parse_server_address_property_scheme_case_does_not_matter', () {
    final Random random = seededRandom(89103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String scheme = pickOne(random, _knownSchemes);
      final String shoutedScheme = scheme.toUpperCase();
      final String host = _randomHost(random);

      final String? problem = describeServerAddressProblem(
        '$shoutedScheme://$host',
      );

      expect(problem, isNull);
      expect(
        describeServerHost('$shoutedScheme://$host'),
        describeServerHost('$scheme://$host'),
      );
    }
  });

  test('test_describe_server_address_problem_property_blank_text_asks_for_'
      'an_address', () {
    final Random random = seededRandom(89104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String blank = _randomWhiteSpace(random);

      expect(describeServerAddressProblem(blank), _enterProblem);
    }
  });

  test('test_describe_server_address_problem_property_answers_with_a_known_'
      'message', () {
    final Random random = seededRandom(89105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = randomHostileText(random);

      final String? problem = describeServerAddressProblem(address);

      expect(problem, anyOf(isNull, _enterProblem, _schemeProblem));
      if (address.trim().isNotEmpty) {
        expect(problem, isNot(_enterProblem), reason: address);
      }
    }
  });

  test('test_describe_server_host_property_never_shows_credentials', () {
    final Random random = seededRandom(89106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String secret = _randomSecret(random);
      final String host = _randomHost(random);
      final String port = random.nextBool()
          ? ''
          : ':${1 + random.nextInt(_largestPort)}';
      final String scheme = pickOne(random, <String>['https', 'http']);

      final String shown = describeServerHost(
        '$scheme://person:$secret@$host$port',
      );

      expect(shown, isNot(contains(secret)));
      expect(shown, isNot(contains('@')));
      expect(shown, describeServerHost('$scheme://$host$port'));
    }
  });

  test('test_describe_server_host_property_peer_links_show_a_short_key_'
      'prefix', () {
    final Random random = seededRandom(89107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String key = _randomPeerKey(random);

      final String shown = describeServerHost('peer://$key');

      final int shownLength = min(key.length, _shownPeerKeyLength);
      expect(shown, '$_peerLinkLabel${key.substring(0, shownLength)}');
    }
  });
}
