import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';
import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'pairing_flow_harness.dart';
import 'scripted_pairing_repository.dart';

const String _cancelLabel = 'Cancel';
const String _expiredText = 'This code expired.';
const String _showNewCodeLabel = 'Show a new code';
const String _devicesLabel = 'Devices';
const double _largestTextScale = 2;

Duration _randomTimeBeforeExpiry(Random random) {
  return Duration(seconds: random.nextInt(pairingLifetime.inSeconds));
}

Duration _randomTimeAfterExpiry(Random random) {
  return pairingLifetime + Duration(minutes: random.nextInt(600));
}

Future<PairingPage> _openCodePage(
  WidgetTester tester,
  Random random, {
  required Duration elapsed,
}) async {
  final PairingPage page = await openPairingPage(
    tester,
    size: randomPairingWindow(random),
    route: const PairingCodeRoute(),
    session: buildLiveSession(problem: null),
    request: null,
  );
  page.pairing.passTime(elapsed);
  await pumpFrames(tester);
  return page;
}

Future<void> _goBackWhileCancelling(WidgetTester tester, Random random) async {
  if (random.nextBool()) {
    await tapButtonLabelled(tester, _cancelLabel);
    return;
  }
  final Finder backLink = find.descendant(
    of: find.byType(BackLinkButton),
    matching: find.text(_devicesLabel),
  );
  await tester.tap(backLink);
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_build_code_card_property_live_code_shows_code_time_and_'
      'server', (WidgetTester tester) async {
    final Random random = seededRandom(104601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openCodePage(
        tester,
        random,
        elapsed: _randomTimeBeforeExpiry(random),
      );

      final String serverAddress = page.dependencies.workspaceRepository
          .currentWorkspace()
          .appServerAddress;
      final String timeLeft = describeTimeLeft(
        expiresAt: galleryNow.add(pairingLifetime),
        now: page.pairing.clock.now(),
      );
      expect(find.text(page.pairing.session!.code), findsOneWidget);
      expect(find.text(timeLeft), findsOneWidget);
      expect(
        find.textContaining(
          'App server ${describeServerHost(serverAddress)}',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.text(_expiredText), findsNothing);
    }
  });

  testWidgets('test_build_code_card_property_expired_code_offers_only_a_'
      'new_code', (WidgetTester tester) async {
    final Random random = seededRandom(104602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openCodePage(
        tester,
        random,
        elapsed: _randomTimeAfterExpiry(random),
      );
      expect(find.byType(PairingQrCode), findsNothing);
      expect(find.text(page.pairing.session!.code), findsNothing);

      await tapButtonLabelled(tester, _showNewCodeLabel);

      expect(find.text(scriptedFreshCode), findsOneWidget);
      expect(find.byType(PairingQrCode), findsOneWidget);
      expect(find.text(_showNewCodeLabel), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_build_code_card_property_fits_any_width_and_text_'
      'scale', (WidgetTester tester) async {
    final Random random = seededRandom(104603);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double textScale =
          1 + random.nextDouble() * (_largestTextScale - 1);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;

      final PairingPage page = await _openCodePage(
        tester,
        random,
        elapsed: random.nextBool()
            ? _randomTimeBeforeExpiry(random)
            : _randomTimeAfterExpiry(random),
      );

      expect(tester.takeException(), isNull, reason: 'scale $textScale');
      if (page.pairing.findActiveSession() != null) {
        final Rect code = tester.getRect(
          find.text(page.pairing.session!.code),
        );
        expect(code.left, greaterThanOrEqualTo(0));
        expect(code.right, lessThanOrEqualTo(tester.view.physicalSize.width));
      }
    }
  });

  testWidgets('test_cancel_shown_code_property_a_live_code_is_cancelled_'
      'and_the_page_closes', (WidgetTester tester) async {
    final Random random = seededRandom(104604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openCodePage(
        tester,
        random,
        elapsed: _randomTimeBeforeExpiry(random),
      );

      await tapButtonLabelled(tester, _cancelLabel);

      expect(page.pairing.calls, <String>['cancel']);
      expect(page.pairing.findActiveSession(), isNull);
      expect(page.navigation.routes, <AppRoute>[devicesRoute]);
      expect(find.byType(PairingCodeScreen), findsNothing);
    }
  });

  testWidgets('test_cancel_shown_code_property_an_expired_code_closes_'
      'without_asking_the_node', (WidgetTester tester) async {
    final Random random = seededRandom(104605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openCodePage(
        tester,
        random,
        elapsed: _randomTimeAfterExpiry(random),
      );

      await tapButtonLabelled(tester, _cancelLabel);

      expect(page.pairing.calls, isEmpty);
      expect(find.text(describeRefusalTitle(_cancelLabel)), findsNothing);
      expect(page.navigation.routes, <AppRoute>[devicesRoute]);
    }
  });

  testWidgets('test_cancel_shown_code_property_a_slow_cancel_closes_only_'
      'this_page', (WidgetTester tester) async {
    final Random random = seededRandom(104606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openCodePage(
        tester,
        random,
        elapsed: _randomTimeBeforeExpiry(random),
      );
      final Completer<void> slowNode = Completer<void>();
      page.pairing.heldAction = slowNode;

      await tapButtonLabelled(tester, _cancelLabel);
      await _goBackWhileCancelling(tester, random);
      page.pairing.heldAction = null;
      slowNode.complete();
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(page.navigation.routes, <AppRoute>[devicesRoute]);
      expect(find.text(describeRefusalTitle(_cancelLabel)), findsNothing);
    }
  });
}
