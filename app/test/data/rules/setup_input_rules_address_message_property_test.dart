import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/setup_input_rules.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

const String _unknownSchemeProblem =
    'Start the address with https://, http:// or peer://';
const String _missingWebHostProblemStart = 'Add the server name after ';
const String _missingPeerKeyProblem = 'Add the server key after peer://';
const String _brokenAddressProblemStart = 'Check the address after ';
const String _peerScheme = 'peer';
const List<String> _webSchemes = <String>['https', 'http'];
const List<String> _knownSchemes = <String>['https', 'http', 'peer'];
const List<String> _acceptedPrefixes = <String>[
  'https://',
  'http://',
  'peer://',
];
const List<String> _hostlessEndings = <String>[
  '://',
  '://?relay=x',
  '://#part',
  ':///path',
  ':',
  ':name-without-slashes',
];
const List<String> _brokenAfterScheme = <String>[
  '://[not-an-ip',
  '://relay.acme.dev:port',
  '://[::1',
];
const List<String> _otherSchemes = <String>[
  'ftp',
  'ws',
  'wss',
  'file',
  'mailto',
  'httpx',
  'peers',
  'localhost',
];
const List<String> _lookalikeSchemes = <String>[
  'httpss',
  'xhttps',
  'peer2',
  'htt',
  'pee',
  'http s',
  'https\u200b',
];
const List<String> _whiteSpacePads = <String>['', ' ', '\t', '\n', '\u3000'];
const List<String> _schemelessAddresses = <String>[
  'relay.acme.dev',
  '10.0.0.7:8080',
  '//relay.acme.dev',
  '/relay',
  'https//relay.acme.dev',
  '://relay.acme.dev',
];

String _randomlyShouted(Random random, String scheme) {
  final StringBuffer buffer = StringBuffer();
  for (final String letter in scheme.split('')) {
    buffer.write(random.nextBool() ? letter.toUpperCase() : letter);
  }
  return buffer.toString();
}

String _randomUnknownSchemeAddress(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _schemelessAddresses);
  }
  final String scheme = _randomlyShouted(
    random,
    pickOne(random, _otherSchemes),
  );
  return '$scheme://${randomHostileText(random)}';
}

String _expectedMissingHostProblem(String scheme) {
  if (scheme == _peerScheme) {
    return _missingPeerKeyProblem;
  }
  return '$_missingWebHostProblemStart$scheme://';
}

void main() {
  test('test_describe_server_address_problem_property_hostless_address_asks_'
      'for_what_follows_its_own_scheme', () {
    final Random random = seededRandom(90301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String scheme = pickOne(random, _knownSchemes);
      final String typedScheme = _randomlyShouted(random, scheme);
      final String address =
          '$typedScheme${pickOne(random, _hostlessEndings)}';

      final String? problem = describeServerAddressProblem(address);

      expect(problem, _expectedMissingHostProblem(scheme), reason: address);
    }
    for (final String scheme in _webSchemes) {
      for (final String ending in _brokenAfterScheme) {
        expect(
          describeServerAddressProblem('$scheme$ending'),
          '$_brokenAddressProblemStart$scheme://',
          reason: '$scheme$ending',
        );
      }
    }
  });

  test('test_describe_server_address_problem_property_unknown_scheme_lists_'
      'every_accepted_scheme', () {
    final Random random = seededRandom(90302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = _randomUnknownSchemeAddress(random);

      final String? problem = describeServerAddressProblem(address);

      expect(problem, _unknownSchemeProblem, reason: address);
      for (final String prefix in _acceptedPrefixes) {
        expect(problem, contains(prefix));
      }
    }
  });

  test('test_describe_server_address_problem_property_known_scheme_is_never_'
      'told_to_start_with_a_scheme', () {
    final Random random = seededRandom(90303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String scheme = pickOne(random, _knownSchemes);
      final String typedScheme = _randomlyShouted(random, scheme);
      final String address = '$typedScheme://${randomHostileText(random)}';

      final String? problem = describeServerAddressProblem(address);

      if (problem == null) {
        continue;
      }
      expect(problem, isNot(_unknownSchemeProblem), reason: address);
      expect(problem, endsWith('$scheme://'), reason: address);
    }
  });

  test('test_read_known_scheme_property_case_and_padding_do_not_matter', () {
    final Random random = seededRandom(90304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String scheme = pickOne(random, _knownSchemes);
      final String ending = pickOne(random, _hostlessEndings);
      final String padded =
          '${pickOne(random, _whiteSpacePads)}'
          '${_randomlyShouted(random, scheme)}$ending'
          '${pickOne(random, _whiteSpacePads)}';

      expect(
        describeServerAddressProblem(padded),
        describeServerAddressProblem('$scheme$ending'),
        reason: padded,
      );
    }
  });

  test('test_read_known_scheme_property_only_text_before_the_first_colon_'
      'counts', () {
    final Random random = seededRandom(90305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String known = pickOne(random, _knownSchemes);
      final String other = pickOne(random, _otherSchemes);

      expect(
        describeServerAddressProblem('$other://$known:'),
        _unknownSchemeProblem,
      );
      expect(
        describeServerAddressProblem('$known:$other://'),
        _expectedMissingHostProblem(known),
      );
    }
  });

  test('test_read_known_scheme_property_lookalike_schemes_are_unknown', () {
    final Random random = seededRandom(90306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String lookalike = pickOne(random, _lookalikeSchemes);
      final String address = '$lookalike://${randomHostileText(random)}';

      expect(describeServerAddressProblem(address), _unknownSchemeProblem);
    }
  });

  test('test_name_server_part_property_peer_asks_for_a_key', () {
    final Random random = seededRandom(90307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address =
          '${_randomlyShouted(random, _peerScheme)}'
          '${pickOne(random, _hostlessEndings)}';

      final String? problem = describeServerAddressProblem(address);

      expect(problem, contains('server key'), reason: address);
      expect(problem, isNot(contains('server name')), reason: address);
    }
  });

  test('test_name_server_part_property_web_schemes_ask_for_a_name', () {
    final Random random = seededRandom(90308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address =
          '${_randomlyShouted(random, pickOne(random, _webSchemes))}'
          '${pickOne(random, _hostlessEndings)}';

      final String? problem = describeServerAddressProblem(address);

      expect(problem, contains('server name'), reason: address);
      expect(problem, isNot(contains('server key')), reason: address);
    }
  });

  test('test_name_server_part_property_broken_addresses_name_no_part', () {
    for (final String scheme in _knownSchemes) {
      for (final String ending in _brokenAfterScheme) {
        final String? problem = describeServerAddressProblem('$scheme$ending');

        expect(problem, startsWith(_brokenAddressProblemStart));
        expect(problem, isNot(contains('server')), reason: '$scheme$ending');
      }
    }
  });
}
