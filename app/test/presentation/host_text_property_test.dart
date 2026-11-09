import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/host_text.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_inputs.dart';
import '../support/random_repository_addresses.dart';

const List<String> _repositoryHosts = <String>[
  'github.com',
  'gitlab.com',
  'bitbucket.org',
];
const List<String> _hostEndings = <String>['', '.', ',', ')', '!'];
const String _nothingElse = '. Nothing else.';
final RegExp _bareHostPattern = RegExp(r'^[a-z0-9-]+(\.[a-z0-9-]+)+$');

String _joinTexts(List<TextSegment> segments) {
  final StringBuffer buffer = StringBuffer();
  for (final TextSegment segment in segments) {
    buffer.write(segment.text);
  }
  return buffer.toString();
}

List<String> _monospaceTexts(List<TextSegment> segments) {
  return <String>[
    for (final TextSegment segment in segments)
      if (segment.face == TextFace.monospace) segment.text,
  ];
}

String _randomAllowedHost(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _repositoryHosts);
  }
  return randomRepositoryHost(random);
}

List<String> _randomAllowedHosts(Random random) {
  final int count = random.nextInt(5);
  return <String>[
    for (int i = 0; i < count; i += 1) _randomAllowedHost(random),
  ];
}

String _describeAccess(String host) {
  if (_repositoryHosts.contains(host)) {
    return '$host read-only';
  }
  return '$host through the hub';
}

void main() {
  test('test_segment_host_names_property_hostile_text_rejoins_unbroken', () {
    final Random random = seededRandom(930101);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String text =
          '${randomHostileText(random)} ${randomRepositoryHost(random)}'
          '${randomHostileText(random)}';

      final List<TextSegment> segments = segmentHostNames(text);

      expect(_joinTexts(segments), text);
      for (final TextSegment segment in segments) {
        expect(segment.text, isNotEmpty);
      }
    }
  });

  test('test_segment_host_names_property_monospace_parts_are_bare_hosts', () {
    final Random random = seededRandom(930102);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String host = randomRepositoryHost(random);
      final String text =
          'https://user:${randomText(random)}@$host/acme '
          '${randomHostileText(random)}';

      final List<TextSegment> segments = segmentHostNames(text);

      for (final String monospaced in _monospaceTexts(segments)) {
        expect(_bareHostPattern.hasMatch(monospaced), isTrue, reason: text);
      }
      expect(_monospaceTexts(segments), contains(host));
    }
  });

  test('test_segment_host_names_property_names_every_host_in_order', () {
    final Random random = seededRandom(930103);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> hosts = <String>[
        for (int index = 0; index < 1 + random.nextInt(4); index += 1)
          randomRepositoryHost(random),
      ];
      final StringBuffer text = StringBuffer('Lets the agent reach');
      for (final String host in hosts) {
        text.write(' $host${pickOne(random, _hostEndings)}');
      }

      final List<TextSegment> segments = segmentHostNames(text.toString());

      expect(_monospaceTexts(segments), hosts);
    }
  });

  test('test_describe_reachable_hosts_property_hosts_keep_their_order', () {
    final Random random = seededRandom(930104);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> hosts = <String>[
        for (final String host in randomHostileTexts(random)) '$host.dev',
      ];

      final List<TextSegment> segments = describeReachableHosts(hosts);

      expect(_monospaceTexts(segments), hosts);
    }
  });

  test('test_describe_reachable_hosts_property_matches_the_access_model', () {
    final Random random = seededRandom(930105);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> hosts = _randomAllowedHosts(random);
      final List<String> described = <String>[
        for (final String host in hosts) _describeAccess(host),
      ];

      final String text = _joinTexts(describeReachableHosts(hosts));

      expect(text, described.join(', '));
    }
  });

  test(
    'test_describe_container_network_property_never_starts_with_a_mark',
    () {
      final Random random = seededRandom(930106);
      for (int i = 0; i < propertyIterations; i += 1) {
        final List<String> hosts = random.nextBool()
            ? const <String>[]
            : _randomAllowedHosts(random);

        final String text = _joinTexts(describeContainerNetwork(hosts));

        expect(text, isNotEmpty);
        expect(text, isNot(startsWith('.')));
        expect(text, isNot(startsWith(',')));
        expect(text, isNot(startsWith(' ')));
        expect(text, endsWith('.'));
      }
    },
  );

  test('test_describe_container_network_property_lists_hosts_then_stops', () {
    final Random random = seededRandom(930107);
    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> hosts = <String>[
        _randomAllowedHost(random),
        ..._randomAllowedHosts(random),
      ];
      final String reachable = _joinTexts(describeReachableHosts(hosts));

      final List<TextSegment> segments = describeContainerNetwork(hosts);

      expect(_joinTexts(segments), '$reachable$_nothingElse');
      expect(_monospaceTexts(segments), hosts);
      expect(segments.last.face, TextFace.body);
    }
  });
}
