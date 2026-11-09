import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/setup/pairing_code_entry_screen.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import 'pairing_code_entry_probe.dart';

PairingCodeEntryProbe _hostingProbe(Random random) {
  return PairingCodeEntryProbe(
    random,
    offersScanning: random.nextBool(),
    offersHosting: true,
  );
}

Future<PairingCodeEntryProbe> _pumpHosting(
  WidgetTester tester,
  Random random,
) async {
  final PairingCodeEntryProbe probe = _hostingProbe(random);
  await pumpPairingCodeEntry(tester, random, probe);
  return probe;
}

Future<void> _tapHost(WidgetTester tester) async {
  await tapVisible(tester, findPairingButton(makeThisComputerTheServerLabel));
  await tester.pump();
}

void main() {
  testWidgets('test_host_property_hosting_opens_its_outcome_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = await _pumpHosting(tester, random);

      await _tapHost(tester);

      expect(tester.takeException(), isNull);
      expect(probe.hostingRequests, 1);
      expect(probe.repository.joinedCodes, isEmpty);
      expect(probe.navigation.routes, <AppRoute>[
        PairingDoneRoute(probe.hostedOutcome),
      ]);
    }
  });

  testWidgets('test_host_property_a_double_tap_hosts_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = await _pumpHosting(tester, random);
      final Completer<void> pending = Completer<void>();
      probe.pendingHosting = pending;
      final Finder host = findPairingButton(makeThisComputerTheServerLabel);
      await tester.ensureVisible(host);
      await tester.pump();

      await tester.tap(host);
      await tester.tap(host);
      pending.complete();
      await tester.pump();

      expect(probe.hostingRequests, 1);
    }
  });

  testWidgets('test_host_property_a_refusal_shows_until_the_next_try', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(111003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = await _pumpHosting(tester, random);
      final ExplainedRefusal refusal = randomExplainedRefusal(random);
      probe.hostingRefusal.problem = refusal.problem;
      await _tapHost(tester);
      final int shownAfterRefusal = find
          .text(refusal.explanation)
          .evaluate()
          .length;
      final Completer<void> pending = Completer<void>();
      probe.pendingHosting = pending;
      probe.hostingRefusal.problem = null;

      await _tapHost(tester);
      final int shownWhileRetrying = find
          .text(refusal.explanation)
          .evaluate()
          .length;
      pending.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(shownAfterRefusal, 1);
      expect(shownWhileRetrying, 0);
      expect(probe.navigation.currentRoute, isA<PairingDoneRoute>());
    }
  });

  testWidgets('test_pairing_code_entry_screen_dispose_property_late_'
      'hosting_refusal_is_quiet', (WidgetTester tester) async {
    final Random random = seededRandom(111015);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = await _pumpHosting(tester, random);
      final Completer<void> pending = Completer<void>();
      probe.pendingHosting = pending;
      probe.hostingRefusal.problem = randomExplainedRefusal(random).problem;
      await _tapHost(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(probe.hostingRequests, 1);
    }
  });
}
