import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/settings/peer_address_banner.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../support/runner_settings_screen_checks.dart';

const String _fallbackNote =
    'Live runs and chat go through the app server until this is fixed.';

void main() {
  test('test_peer_address_banner_constructor_property_keeps_the_problem', () {
    final Random random = seededRandom(108301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String problem = randomHostileText(random);
      final Key key = ValueKey<int>(i);

      final PeerAddressBanner banner = PeerAddressBanner(
        problem: problem,
        key: key,
      );

      expect(banner.problem.codeUnits, problem.codeUnits);
      expect(banner.key, key);
    }
  });

  test('test_peer_address_banner_constructor_property_key_is_optional', () {
    final Random random = seededRandom(108302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PeerAddressBanner banner = PeerAddressBanner(
        problem: randomHostileText(random),
      );

      expect(banner.key, isNull);
    }
  });

  test('test_peer_address_banner_constructor_property_banners_are_alike', () {
    final Random random = seededRandom(108303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String problem = randomHostileText(random);
      final PeerAddressBanner first = PeerAddressBanner(problem: problem);
      final PeerAddressBanner second = PeerAddressBanner(problem: problem);

      expect(first.problem, second.problem);
      expect(Widget.canUpdate(first, second), isTrue);
    }
  });

  testWidgets('test_peer_address_banner_build_property_names_the_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = '${randomHostileText(random)} $i';
      await pumpAtRandomWidth(
        tester,
        random,
        PeerAddressBanner(problem: problem),
      );

      expect(readShownTexts(tester, find.byType(PeerAddressBanner)), <String>[
        peerAddressProblemTitle,
        problem,
        _fallbackNote,
      ]);
    }
  });

  testWidgets('test_peer_address_banner_build_property_is_an_attention', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpAtRandomWidth(
        tester,
        random,
        PeerAddressBanner(problem: randomHostileText(random)),
      );

      final NoticeBanner notice = tester.widget(find.byType(NoticeBanner));
      expect(notice.tone, BannerTone.attention);
      expect(notice.title, peerAddressProblemTitle);
      expect(notice.actions, isEmpty);
    }
  });

  testWidgets('test_peer_address_banner_build_property_reads_top_down', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(108306);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String problem = 'Port $i is closed ${randomWordPhrase(random)}';
      await pumpAtRandomWidth(
        tester,
        random,
        PeerAddressBanner(problem: problem),
      );

      final Rect title = tester.getRect(find.text(peerAddressProblemTitle));
      final Rect shownProblem = tester.getRect(find.text(problem));
      final Rect note = tester.getRect(find.text(_fallbackNote));
      expect(title.bottom, lessThanOrEqualTo(shownProblem.top));
      expect(shownProblem.bottom, lessThanOrEqualTo(note.top));
      final Rect banner = tester.getRect(find.byType(PeerAddressBanner));
      expect(banner.contains(note.bottomRight - const Offset(1, 1)), isTrue);
    }
  });
}
