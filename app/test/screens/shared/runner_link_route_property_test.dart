import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/shared/runner_link_route.dart';
import 'package:agent_orchestration/widgets/route_line.dart';
import 'package:agent_orchestration/widgets/route_line_painter.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

const String _encryptedEnd = ' · encrypted';
const List<String> _linkWords = <String>['Direct', 'network', 'Relay'];

RunnerLink? _randomOptionalLink(Random random) {
  if (random.nextInt(5) == 0) {
    return null;
  }
  return pickOne(random, RunnerLink.values);
}

void _expectSameRoute(RouteLine actual, RouteLine expected) {
  expect(actual.startName, expected.startName);
  expect(actual.endName, expected.endName);
  expect(actual.path, expected.path);
  expect(actual.badgeLabel, expected.badgeLabel);
  expect(actual.badgeIcon, expected.badgeIcon);
}

void main() {
  test('test_build_runner_link_route_property_keeps_both_names', () {
    final Random random = seededRandom(111901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String startName = randomHostileText(random);
      final String endName = randomHostileText(random);

      final RouteLine route = buildRunnerLinkRoute(
        startName: startName,
        endName: endName,
        link: pickOne(random, RunnerLink.values),
      );

      expect(route.startName, startName);
      expect(route.endName, endName);
    }
  });

  test('test_build_runner_link_route_property_live_links_are_encrypted', () {
    final Random random = seededRandom(111902);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunnerLink link = pickOne(random, RunnerLink.values);

      final RouteLine route = buildRunnerLinkRoute(
        startName: randomHostileText(random),
        endName: randomHostileText(random),
        link: link,
      );

      if (link == RunnerLink.unreachable) {
        expect(route.badgeLabel, 'Reconnecting');
        expect(route.badgeIcon, AppIconKind.spinner);
      } else {
        expect(route.badgeLabel, endsWith(_encryptedEnd));
        expect(route.badgeIcon, AppIconKind.lock);
      }
    }
  });

  test('test_build_runner_link_route_property_each_link_reads_its_own', () {
    final Map<RunnerLink, RoutePath> expectedPaths = <RunnerLink, RoutePath>{
      RunnerLink.direct: RoutePath.direct,
      RunnerLink.localNetwork: RoutePath.direct,
      RunnerLink.relay: RoutePath.relay,
      RunnerLink.unreachable: RoutePath.broken,
    };

    final Set<String> labels = <String>{};
    for (final RunnerLink link in RunnerLink.values) {
      final RouteLine route = buildRunnerLinkRoute(
        startName: 'air-laptop',
        endName: 'mac-studio',
        link: link,
      );
      labels.add(route.badgeLabel);
      expect(route.path, expectedPaths[link]);
    }

    expect(labels, hasLength(RunnerLink.values.length));
    expect(labels, contains('Direct · encrypted'));
    expect(labels, contains('Same network · encrypted'));
  });

  test('test_build_pairing_link_route_property_known_link_like_runner', () {
    final Random random = seededRandom(111904);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String startName = randomHostileText(random);
      final String endName = randomHostileText(random);
      final RunnerLink link = pickOne(random, RunnerLink.values);

      final RouteLine route = buildPairingLinkRoute(
        startName: startName,
        endName: endName,
        link: link,
      );

      _expectSameRoute(
        route,
        buildRunnerLinkRoute(
          startName: startName,
          endName: endName,
          link: link,
        ),
      );
    }
  });

  test('test_build_pairing_link_route_property_no_link_names_no_path', () {
    final Random random = seededRandom(111905);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RouteLine route = buildPairingLinkRoute(
        startName: randomHostileText(random),
        endName: randomHostileText(random),
        link: null,
      );

      expect(route.badgeLabel, unknownLinkBadgeLabel);
      expect(route.badgeIcon, AppIconKind.lock);
      expect(route.path, isNot(RoutePath.broken));
      for (final String word in _linkWords) {
        expect(route.badgeLabel, isNot(contains(word)));
      }
    }
  });

  test('test_build_pairing_link_route_property_keeps_both_names', () {
    final Random random = seededRandom(111906);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String startName = randomHostileText(random);
      final String endName = randomHostileText(random);

      final RouteLine route = buildPairingLinkRoute(
        startName: startName,
        endName: endName,
        link: _randomOptionalLink(random),
      );

      expect(route.startName, startName);
      expect(route.endName, endName);
    }
  });
}
